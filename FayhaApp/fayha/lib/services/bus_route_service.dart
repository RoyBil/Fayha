import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/bus_route_models.dart';

/// CRUD for bus routes + Google Directions integration.
/// Writes are gated by RLS (`admin` of the route's branch or `superAdmin`).
class BusRouteService {
  static final _c = Supabase.instance.client;

  /// Set once at app startup if you want to enable real-road polylines.
  /// When null, [fetchDirections] falls back to a straight line through
  /// the waypoints — useful for development and tests.
  static String? googleDirectionsApiKey;

  // ── Reads ────────────────────────────────────────────────
  static Future<List<BusRoute>> listForBranch(String branch) async {
    final rows = await _c
        .from('bus_routes_with_stops')
        .select()
        .eq('branch', branch)
        .eq('is_active', true)
        .order('name');
    return (rows as List)
        .map((r) => BusRoute.fromViewRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  static Future<BusRoute> getById(String routeId) async {
    final row = await _c
        .from('bus_routes_with_stops')
        .select()
        .eq('id', routeId)
        .single();
    return BusRoute.fromViewRow(Map<String, dynamic>.from(row));
  }

  // ── Writes (admin only — RLS enforces) ───────────────────
  /// Creates a route plus its ordered stops in one shot. Generates the
  /// Google Directions polyline using start → stops → end.
  static Future<String> create({
    required String branch,
    required String name,
    required String startName,
    required LatLng startPoint,
    required String endName,
    required LatLng endPoint,
    required List<
      ({
        String name,
        LatLng location,
        int? geofenceRadiusM,
        int? approachRadiusM,
      })
    >
    stops,
  }) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw 'Not signed in';

    final directions = await fetchDirections(
      startPoint,
      endPoint,
      stops.map((s) => s.location).toList(),
    );

    final routeId =
        await _c.rpc(
              'bus_routes_upsert_with_geometry',
              params: {
                'p_id': null,
                'p_branch': branch,
                'p_name': name,
                'p_start_name': startName,
                'p_start_lat': startPoint.latitude,
                'p_start_lng': startPoint.longitude,
                'p_end_name': endName,
                'p_end_lat': endPoint.latitude,
                'p_end_lng': endPoint.longitude,
                'p_polyline_coords': directions.polyline
                    .map((p) => [p.longitude, p.latitude])
                    .toList(),
                'p_total_distance_m': directions.totalDistanceM,
              },
            )
            as String;

    // Insert stops
    final stopRows = <Map<String, dynamic>>[];
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      stopRows.add({
        'route_id': routeId,
        'order_index': i,
        'name': s.name,
        'lat': s.location.latitude,
        'lng': s.location.longitude,
        if (s.geofenceRadiusM != null) 'geofence_radius_m': s.geofenceRadiusM,
        if (s.approachRadiusM != null) 'approach_radius_m': s.approachRadiusM,
      });
    }
    if (stopRows.isNotEmpty) {
      await _c.from('bus_route_stops').insert(stopRows);
    }
    return routeId;
  }

  /// Replaces the stop list and optionally renames the route.
  /// Regenerates the polyline.
  static Future<void> updateStopsAndPolyline({
    required String routeId,
    String? name,
    String? startName,
    String? endName,
    required LatLng startPoint,
    required LatLng endPoint,
    required List<
      ({
        String name,
        LatLng location,
        int? geofenceRadiusM,
        int? approachRadiusM,
      })
    >
    stops,
  }) async {
    final directions = await fetchDirections(
      startPoint,
      endPoint,
      stops.map((s) => s.location).toList(),
    );

    await _c.rpc(
      'bus_routes_upsert_with_geometry',
      params: {
        'p_id': routeId,
        'p_branch': null,
        'p_name': name,
        'p_start_name': startName,
        'p_start_lat': startPoint.latitude,
        'p_start_lng': startPoint.longitude,
        'p_end_name': endName,
        'p_end_lat': endPoint.latitude,
        'p_end_lng': endPoint.longitude,
        'p_polyline_coords': directions.polyline
            .map((p) => [p.longitude, p.latitude])
            .toList(),
        'p_total_distance_m': directions.totalDistanceM,
      },
    );

    await _c.from('bus_route_stops').delete().eq('route_id', routeId);
    final stopRows = <Map<String, dynamic>>[];
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      stopRows.add({
        'route_id': routeId,
        'order_index': i,
        'name': s.name,
        'lat': s.location.latitude,
        'lng': s.location.longitude,
        if (s.geofenceRadiusM != null) 'geofence_radius_m': s.geofenceRadiusM,
        if (s.approachRadiusM != null) 'approach_radius_m': s.approachRadiusM,
      });
    }
    if (stopRows.isNotEmpty) {
      await _c.from('bus_route_stops').insert(stopRows);
    }
  }

  static Future<void> deactivate(String routeId) async {
    await _c.from('bus_routes').update({'is_active': false}).eq('id', routeId);
  }

  static Future<void> deleteRoute(String routeId) async {
    await _c.from('bus_routes').delete().eq('id', routeId);
  }

  // ── Directions API ──────────────────────────────────────
  /// Returns the road-following polyline + total distance. Falls back
  /// to a straight line through the waypoints if no API key is set or
  /// the request fails (so the rest of the app stays usable in dev).
  static Future<({List<LatLng> polyline, double totalDistanceM})>
  fetchDirections(LatLng start, LatLng end, List<LatLng> waypoints) async {
    final key = googleDirectionsApiKey;
    if (key == null || key.isEmpty) {
      return _straightLineFallback(start, end, waypoints);
    }
    try {
      final wp = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
            'origin': '${start.latitude},${start.longitude}',
            'destination': '${end.latitude},${end.longitude}',
            if (wp.isNotEmpty) 'waypoints': wp,
            'mode': 'driving',
            'key': key,
          });
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        return _straightLineFallback(start, end, waypoints);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') {
        return _straightLineFallback(start, end, waypoints);
      }
      final route = (body['routes'] as List).first as Map<String, dynamic>;
      final encoded = (route['overview_polyline'] as Map)['points'] as String;
      final legs = (route['legs'] as List).cast<Map<String, dynamic>>();
      final totalM = legs.fold<double>(
        0,
        (s, l) => s + ((l['distance'] as Map)['value'] as num).toDouble(),
      );
      return (polyline: _decodeGooglePolyline(encoded), totalDistanceM: totalM);
    } catch (_) {
      return _straightLineFallback(start, end, waypoints);
    }
  }

  static ({List<LatLng> polyline, double totalDistanceM}) _straightLineFallback(
    LatLng start,
    LatLng end,
    List<LatLng> waypoints,
  ) {
    final pts = <LatLng>[start, ...waypoints, end];
    final d = const Distance();
    double total = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += d.as(LengthUnit.Meter, pts[i], pts[i + 1]);
    }
    return (polyline: pts, totalDistanceM: total);
  }

  /// Decodes Google's polyline algorithm (precision 5).
  static List<LatLng> _decodeGooglePolyline(String encoded) {
    final pts = <LatLng>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }
}
