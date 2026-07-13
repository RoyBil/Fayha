import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ReverseGeoResult {
  final String displayName;
  final String shortName;
  const ReverseGeoResult({required this.displayName, required this.shortName});
}

/// Reverse geocoding via Nominatim (OSM). Snaps results to a ~5-decimal
/// degree grid so nearby taps share a cache entry (≤ 150 entries).
class NominatimService {
  static final _cache = <String, ReverseGeoResult?>{};
  static const _cacheMax = 150;

  static Future<ReverseGeoResult?> reverse(LatLng point) async {
    final key =
        '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final res = await http
          .get(
            Uri.https('nominatim.openstreetmap.org', '/reverse', {
              'format': 'json',
              'lat': '${point.latitude}',
              'lon': '${point.longitude}',
              'zoom': '18',
              'addressdetails': '1',
            }),
            headers: {
              'User-Agent': 'FayhaNationalChoirApp/1.0',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _cache[key] = null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final display = body['display_name'] as String? ?? '';
      final addr = body['address'] as Map<String, dynamic>?;

      String short = '';
      if (addr != null) {
        final parts = <String>[];
        final road =
            addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? addr['path'];
        final num = addr['house_number'];
        if (num != null && road != null) {
          parts.add('$num $road');
        } else if (road != null) {
          parts.add(road as String);
        }
        final city = addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['suburb'] ??
            addr['neighbourhood'];
        if (city != null) parts.add(city as String);
        short = parts.join(', ');
      }
      if (short.isEmpty) {
        short = display.split(',').take(2).join(',').trim();
      }

      final result = ReverseGeoResult(displayName: display, shortName: short);
      if (_cache.length >= _cacheMax) _cache.remove(_cache.keys.first);
      return _cache[key] = result;
    } catch (_) {
      return _cache[key] = null;
    }
  }
}
