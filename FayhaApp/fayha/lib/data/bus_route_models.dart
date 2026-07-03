import 'dart:convert';

import 'package:latlong2/latlong.dart';

enum TripStatus { scheduled, inProgress, completed, cancelled }

TripStatus _statusFromString(String? s) {
  switch (s) {
    case 'in_progress':
      return TripStatus.inProgress;
    case 'completed':
      return TripStatus.completed;
    case 'cancelled':
      return TripStatus.cancelled;
    default:
      return TripStatus.scheduled;
  }
}

String tripStatusToString(TripStatus s) {
  switch (s) {
    case TripStatus.scheduled:
      return 'scheduled';
    case TripStatus.inProgress:
      return 'in_progress';
    case TripStatus.completed:
      return 'completed';
    case TripStatus.cancelled:
      return 'cancelled';
  }
}

enum TripEventType {
  routeStarted,
  stopApproaching,
  stopArrived,
  stopLeft,
  routeCompleted,
  routeCancelled,
  unknown,
}

TripEventType tripEventTypeFromString(String s) {
  switch (s) {
    case 'ROUTE_STARTED':
      return TripEventType.routeStarted;
    case 'STOP_APPROACHING':
      return TripEventType.stopApproaching;
    case 'STOP_ARRIVED':
      return TripEventType.stopArrived;
    case 'STOP_LEFT':
      return TripEventType.stopLeft;
    case 'ROUTE_COMPLETED':
      return TripEventType.routeCompleted;
    case 'ROUTE_CANCELLED':
      return TripEventType.routeCancelled;
    default:
      return TripEventType.unknown;
  }
}

class BusStop {
  final String id;
  final int orderIndex;
  final String name;
  final LatLng location;
  final int geofenceRadiusM;
  final int approachRadiusM;

  const BusStop({
    required this.id,
    required this.orderIndex,
    required this.name,
    required this.location,
    this.geofenceRadiusM = 200,
    this.approachRadiusM = 800,
  });

  factory BusStop.fromMap(Map<String, dynamic> m) => BusStop(
    id: m['id'] as String,
    orderIndex: (m['order_index'] as num).toInt(),
    name: m['name'] as String,
    location: LatLng(
      (m['lat'] as num).toDouble(),
      (m['lng'] as num).toDouble(),
    ),
    geofenceRadiusM: (m['geofence_radius_m'] as num?)?.toInt() ?? 200,
    approachRadiusM: (m['approach_radius_m'] as num?)?.toInt() ?? 800,
  );
}

class BusRoute {
  final String id;
  final String branch;
  final String name;
  final String startName;
  final LatLng startPoint;
  final String endName;
  final LatLng endPoint;
  final List<LatLng> polyline;
  final double totalDistanceM;
  final List<BusStop> stops;
  final bool isActive;
  final DateTime? updatedAt;

  const BusRoute({
    required this.id,
    required this.branch,
    required this.name,
    required this.startName,
    required this.startPoint,
    required this.endName,
    required this.endPoint,
    required this.polyline,
    required this.totalDistanceM,
    required this.stops,
    this.isActive = true,
    this.updatedAt,
  });

  /// Reads a row from the `bus_routes_with_stops` view, which already
  /// flattens lat/lng for the endpoints and ships the polyline as
  /// GeoJSON.
  factory BusRoute.fromViewRow(Map<String, dynamic> m) {
    final stops = ((m['stops'] as List?) ?? const [])
        .map((e) => BusStop.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final polyline = <LatLng>[];
    final geo = m['polyline_geojson'];
    if (geo != null) {
      final decoded = geo is String
          ? Map<String, dynamic>.from(jsonDecode(geo) as Map)
          : Map<String, dynamic>.from(geo as Map);
      for (final c in (decoded['coordinates'] as List? ?? const [])) {
        // GeoJSON is [lng, lat]
        polyline.add(
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        );
      }
    }

    return BusRoute(
      id: m['id'] as String,
      branch: m['branch'] as String,
      name: m['name'] as String,
      startName: m['start_name'] as String,
      startPoint: LatLng(
        (m['start_lat'] as num).toDouble(),
        (m['start_lng'] as num).toDouble(),
      ),
      endName: m['end_name'] as String,
      endPoint: LatLng(
        (m['end_lat'] as num).toDouble(),
        (m['end_lng'] as num).toDouble(),
      ),
      polyline: polyline,
      totalDistanceM: (m['total_distance_m'] as num?)?.toDouble() ?? 0,
      stops: stops,
      isActive: (m['is_active'] as bool?) ?? true,
      updatedAt: m['updated_at'] == null
          ? null
          : DateTime.tryParse(m['updated_at'] as String),
    );
  }
}

class BusTrip {
  final String id;
  final String routeId;
  final String driverId;
  final TripStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? currentStopIndex;

  const BusTrip({
    required this.id,
    required this.routeId,
    required this.driverId,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.currentStopIndex,
  });

  factory BusTrip.fromMap(Map<String, dynamic> m) => BusTrip(
    id: m['id'] as String,
    routeId: m['route_id'] as String,
    driverId: m['driver_id'] as String,
    status: _statusFromString(m['status'] as String?),
    startedAt: m['started_at'] == null
        ? null
        : DateTime.tryParse(m['started_at'] as String),
    endedAt: m['ended_at'] == null
        ? null
        : DateTime.tryParse(m['ended_at'] as String),
    currentStopIndex: (m['current_stop_index'] as num?)?.toInt(),
  );
}

class TripPosition {
  final String tripId;
  final LatLng location;
  final double? heading;
  final double? speedMps;
  final DateTime recordedAt;

  const TripPosition({
    required this.tripId,
    required this.location,
    this.heading,
    this.speedMps,
    required this.recordedAt,
  });

  /// Reads from the `bus_trip_positions_view` (defined in bus_routes.sql
  /// next to the table when needed) or any select that already exposes
  /// `lat`/`lng` via st_y/st_x.
  factory TripPosition.fromMap(Map<String, dynamic> m) => TripPosition(
    tripId: m['trip_id'] as String,
    location: LatLng(
      (m['lat'] as num).toDouble(),
      (m['lng'] as num).toDouble(),
    ),
    heading: (m['heading'] as num?)?.toDouble(),
    speedMps: (m['speed_mps'] as num?)?.toDouble(),
    recordedAt: DateTime.parse(m['recorded_at'] as String),
  );
}

class TripEvent {
  final String id;
  final String tripId;
  final String routeId;
  final String? stopId;
  final TripEventType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const TripEvent({
    required this.id,
    required this.tripId,
    required this.routeId,
    required this.type,
    this.stopId,
    this.payload = const {},
    required this.createdAt,
  });

  factory TripEvent.fromMap(Map<String, dynamic> m) => TripEvent(
    id: m['id'] as String,
    tripId: m['trip_id'] as String,
    routeId: m['route_id'] as String,
    stopId: m['stop_id'] as String?,
    type: tripEventTypeFromString(m['event_type'] as String),
    payload: m['payload'] == null
        ? const {}
        : Map<String, dynamic>.from(m['payload'] as Map),
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class PickupRequest {
  final String id;
  final String routeId;
  final String? tripId;
  final String userId;
  final LatLng pickupPoint;
  final double distanceToRouteM;
  final String status;
  final DateTime createdAt;

  const PickupRequest({
    required this.id,
    required this.routeId,
    required this.userId,
    required this.pickupPoint,
    required this.distanceToRouteM,
    required this.status,
    required this.createdAt,
    this.tripId,
  });

  factory PickupRequest.fromMap(Map<String, dynamic> m) => PickupRequest(
    id: m['id'] as String,
    routeId: m['route_id'] as String,
    tripId: m['trip_id'] as String?,
    userId: m['user_id'] as String,
    pickupPoint: LatLng(
      (m['lat'] as num).toDouble(),
      (m['lng'] as num).toDouble(),
    ),
    distanceToRouteM: (m['distance_to_route_m'] as num).toDouble(),
    status: m['status'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class RouteProgress {
  final double fractionDone;
  final double remainingM;
  final double totalM;
  const RouteProgress({
    required this.fractionDone,
    required this.remainingM,
    required this.totalM,
  });
  factory RouteProgress.fromMap(Map<String, dynamic> m) => RouteProgress(
    fractionDone: (m['fraction_done'] as num).toDouble(),
    remainingM: (m['remaining_m'] as num).toDouble(),
    totalM: (m['total_m'] as num).toDouble(),
  );
}
