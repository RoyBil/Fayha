import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/bus_route_models.dart';

/// Members request a pickup for a route. The server validates that
/// the chosen point is within 500m of the route polyline; clients
/// cannot bypass this since validation happens in the RPC.
class BusPickupService {
  static final _c = Supabase.instance.client;

  /// Uses the current device GPS as the pickup point.
  static Future<PickupRequest> requestFromCurrentLocation(String routeId) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are off';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Location permission denied';
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return requestAt(routeId, LatLng(pos.latitude, pos.longitude));
  }

  /// Member-picked point on the map.
  static Future<PickupRequest> requestAt(String routeId, LatLng point) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw 'Not signed in';
    final row = await _c.rpc('request_bus_pickup', params: {
      'p_route': routeId,
      'p_lat': point.latitude,
      'p_lng': point.longitude,
    });
    return PickupRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }

  static Future<void> cancel(String requestId) async {
    await _c
        .from('bus_pickup_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId);
  }

  /// Member's own pending requests.
  static Future<List<PickupRequest>> myPending() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return const [];
    final rows = await _c
        .from('bus_pickup_requests')
        .select()
        .eq('user_id', me)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => PickupRequest.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Admin view: all pending pickups on a route (RLS allows branch
  /// admins / superAdmin).
  static Stream<List<PickupRequest>> watchForRoute(String routeId) {
    final controller = StreamController<List<PickupRequest>>.broadcast();

    Future<void> refresh() async {
      try {
        final rows = await _c
            .from('bus_pickup_requests')
            .select()
            .eq('route_id', routeId)
            .neq('status', 'cancelled')
            .order('created_at', ascending: false);
        controller.add((rows as List)
            .map((r) => PickupRequest.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList());
      } catch (_) {/* surface via stream's error path in future */}
    }

    final channel = _c.channel('bus_pickups:$routeId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bus_pickup_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'route_id',
          value: routeId,
        ),
        callback: (_) => refresh(),
      );
    channel.subscribe();
    refresh();
    controller.onCancel = () async {
      await _c.removeChannel(channel);
    };
    return controller.stream;
  }
}
