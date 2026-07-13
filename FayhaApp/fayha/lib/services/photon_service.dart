import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PhotonResult {
  final String name;
  final String subtitle;
  final LatLng location;
  const PhotonResult({
    required this.name,
    required this.subtitle,
    required this.location,
  });
}

/// Free, no-key POI + address search via Komoot Photon (OSM-backed).
/// Results are LRU-cached (≤ 60 entries) to reduce re-requests while typing.
class PhotonService {
  static final _cache = <String, List<PhotonResult>>{};
  static const _cacheMax = 60;

  static Future<List<PhotonResult>> search(
    String query, {
    LatLng? near,
    int limit = 8,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final key =
        '$q|${near?.latitude.toStringAsFixed(3)}|${near?.longitude.toStringAsFixed(3)}';
    if (_cache.containsKey(key)) return _cache[key]!;

    final params = <String, String>{'q': q, 'limit': '$limit', 'lang': 'en'};
    if (near != null) {
      params['lat'] = '${near.latitude}';
      params['lon'] = '${near.longitude}';
    }

    try {
      final res = await http
          .get(
            Uri.https('photon.komoot.io', '/api/', params),
            headers: {'User-Agent': 'FayhaNationalChoirApp/1.0'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final features =
          (body['features'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

      final results = <PhotonResult>[];
      for (final f in features) {
        final coords = (f['geometry']['coordinates'] as List).cast<num>();
        final p = f['properties'] as Map<String, dynamic>;
        final name =
            (p['name'] as String?) ??
            (p['street'] as String?) ??
            (p['city'] as String?) ??
            '';
        if (name.isEmpty) continue;

        final sub = <String>[];
        final street = p['street'] as String?;
        if (street != null && street != name) sub.add(street);
        final city = p['city'] as String?;
        if (city != null) sub.add(city);
        final state = p['state'] as String?;
        if (state != null) sub.add(state);
        final country = p['country'] as String?;
        if (country != null) sub.add(country);

        results.add(
          PhotonResult(
            name: name,
            subtitle: sub.join(', '),
            location: LatLng(coords[1].toDouble(), coords[0].toDouble()),
          ),
        );
      }

      if (_cache.length >= _cacheMax) _cache.remove(_cache.keys.first);
      return _cache[key] = results;
    } catch (_) {
      return const [];
    }
  }

  static void clearCache() => _cache.clear();
}
