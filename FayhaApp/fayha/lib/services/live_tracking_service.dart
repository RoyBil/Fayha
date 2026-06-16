import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/bus_route_models.dart';

/// Member-side: subscribe to live bus position + trip events for a
/// route and compute ETA from remaining road distance.
class LiveTrackingService {
  static final _c = Supabase.instance.client;

  /// Latest known position for a trip (one-shot fetch).
  static Future<TripPosition?> currentPosition(String tripId) async {
    final rows = await _c
        .from('bus_trip_positions')
        .select('trip_id,lat,lng,heading,speed_mps,recorded_at')
        .eq('trip_id', tripId)
        .maybeSingle();
    if (rows == null) return null;
    return TripPosition.fromMap(Map<String, dynamic>.from(rows));
  }

  /// Realtime stream of position updates for a trip.
  static Stream<TripPosition> positions(String tripId) {
    final controller = StreamController<TripPosition>.broadcast();
    final channel = _c.channel('trip_positions:$tripId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bus_trip_positions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row.isEmpty) return;
          controller.add(TripPosition.fromMap(Map<String, dynamic>.from(row)));
        },
      );
    channel.subscribe();
    controller.onCancel = () async {
      await _c.removeChannel(channel);
    };
    return controller.stream;
  }

  /// Realtime stream of trip events for a route.
  static Stream<TripEvent> events(String routeId) {
    final controller = StreamController<TripEvent>.broadcast();
    final channel = _c.channel('trip_events:$routeId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'bus_trip_events',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'route_id',
          value: routeId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row.isEmpty) return;
          controller.add(TripEvent.fromMap(Map<String, dynamic>.from(row)));
        },
      );
    channel.subscribe();
    controller.onCancel = () async {
      await _c.removeChannel(channel);
    };
    return controller.stream;
  }

  /// Snapshot of recent events for a route (newest first).
  static Future<List<TripEvent>> recentEvents(String routeId,
      {int limit = 30}) async {
    final rows = await _c
        .from('bus_trip_events')
        .select()
        .eq('route_id', routeId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => TripEvent.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Returns the latest GPS sample snapped onto the route polyline.
  /// Use this for the bus marker so it glues to the road (no jitter,
  /// no over-water artifacts on coastal routes).
  static Future<TripPosition?> snappedPosition(String tripId) async {
    final res = await _c
        .rpc('bus_snapped_position', params: {'p_trip': tripId});
    if (res == null) return null;
    final list = res as List;
    if (list.isEmpty) return null;
    final m = Map<String, dynamic>.from(list.first as Map);
    return TripPosition(
      tripId: tripId,
      location: LatLng(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
      ),
      recordedAt: DateTime.parse(m['recorded_at'] as String),
    );
  }

  /// Calls the `bus_route_progress` RPC to get true road-distance
  /// progress. Use the result with the current bus speed (or a
  /// configured average) to compute ETA — see [estimateEta].
  static Future<RouteProgress?> progress(String tripId) async {
    final res = await _c.rpc('bus_route_progress', params: {'p_trip': tripId});
    if (res == null) return null;
    final list = (res as List);
    if (list.isEmpty) return null;
    return RouteProgress.fromMap(Map<String, dynamic>.from(list.first as Map));
  }

  /// ETA in whole seconds. Falls back to [assumedSpeedMps] when the
  /// current sample's speed is zero (stopped at light, etc.).
  static Duration estimateEta({
    required RouteProgress progress,
    required TripPosition position,
    double assumedSpeedMps = 8.3, // ~30 km/h
  }) {
    final speed = (position.speedMps ?? 0) > 1.5
        ? position.speedMps!
        : assumedSpeedMps;
    final secs = (progress.remainingM / speed).round();
    return Duration(seconds: secs.clamp(0, 24 * 3600));
  }

  // ── Subscriptions (who gets push for which route) ─────────
  static Future<void> subscribeToRoute(String routeId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw 'Not signed in';
    await _c.from('bus_route_subscriptions').upsert({
      'user_id': me,
      'route_id': routeId,
    });
  }

  static Future<void> unsubscribeFromRoute(String routeId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return;
    await _c
        .from('bus_route_subscriptions')
        .delete()
        .eq('user_id', me)
        .eq('route_id', routeId);
  }
}
