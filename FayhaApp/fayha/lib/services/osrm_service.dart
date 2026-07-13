import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRoute {
  final List<LatLng> polyline;
  final double distanceM;
  final double durationS;

  const OsrmRoute({
    required this.polyline,
    required this.distanceM,
    required this.durationS,
  });

  String get distanceLabel {
    if (distanceM < 1000) return '${distanceM.round()} m';
    return '${(distanceM / 1000).toStringAsFixed(1)} km';
  }

  String get etaLabel {
    final mins = (durationS / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '$h h $m min' : '$h h';
  }
}

/// Driving route via the public OSRM demo server.
/// Returns null on any network or routing failure (no roads between points,
/// server down, timeout). Results are NOT cached — callers should debounce.
class OsrmService {
  static Future<OsrmRoute?> route(
    LatLng start,
    LatLng end, {
    List<LatLng> waypoints = const [],
  }) async {
    final all = [start, ...waypoints, end];
    final coords = all.map((p) => '${p.longitude},${p.latitude}').join(';');
    try {
      final res = await http
          .get(
            Uri.https('router.project-osrm.org', '/route/v1/driving/$coords', {
              'overview': 'full',
              'geometries': 'geojson',
            }),
            headers: {'User-Agent': 'FayhaNationalChoirApp/1.0'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;

      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final r = routes.first as Map<String, dynamic>;
      final geo = r['geometry'] as Map<String, dynamic>;
      final rawCoords = (geo['coordinates'] as List).cast<List<dynamic>>();

      return OsrmRoute(
        polyline: rawCoords
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList(),
        distanceM: (r['distance'] as num).toDouble(),
        durationS: (r['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
