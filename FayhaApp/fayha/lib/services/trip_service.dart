import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/bus_route_models.dart';

/// Manages BusTrip lifecycle. Status changes fire DB triggers that
/// emit ROUTE_STARTED / ROUTE_COMPLETED / ROUTE_CANCELLED events.
class TripService {
  static final _c = Supabase.instance.client;

  /// Starts a trip via the `start_bus_trip` RPC, which validates
  /// route exists, polyline exists, the route has at least one stop,
  /// the caller is authorized, and no other in-progress trip is
  /// already running. Throws a single-line, user-readable error on
  /// any failure.
  static Future<BusTrip> start(String routeId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw 'Not signed in';
    final row = await _c.rpc('start_bus_trip', params: {'p_route': routeId});
    return BusTrip.fromMap(Map<String, dynamic>.from(row as Map));
  }

  static Future<void> cancel(String tripId) async {
    await _c
        .from('bus_trips')
        .update({
          'status': 'cancelled',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tripId);
  }

  static Future<void> complete(String tripId) async {
    await _c
        .from('bus_trips')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tripId);
  }

  /// The active trip (if any) for a route.
  static Future<BusTrip?> activeForRoute(String routeId) async {
    final rows = await _c
        .from('bus_trips')
        .select()
        .eq('route_id', routeId)
        .eq('status', 'in_progress')
        .order('started_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return BusTrip.fromMap(Map<String, dynamic>.from(list.first as Map));
  }

  /// Postgres Changes stream for a single trip row.
  static Stream<BusTrip> watch(String tripId) {
    final controller = StreamController<BusTrip>.broadcast();
    final channel = _c.channel('trip:$tripId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'bus_trips',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: tripId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          controller.add(BusTrip.fromMap(Map<String, dynamic>.from(row)));
        },
      );
    channel.subscribe();
    controller.onCancel = () async {
      await _c.removeChannel(channel);
    };
    return controller.stream;
  }
}
