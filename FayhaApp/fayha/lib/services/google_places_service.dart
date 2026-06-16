import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Google Places API integration for searching real-world locations
/// (universities, businesses, landmarks, etc.) when building or
/// editing bus routes.
///
/// Wire in by setting [apiKey] at app boot. When unset, all calls
/// return empty lists rather than throwing, so the editor stays
/// usable in dev without an API key.
class GooglePlacesService {
  static String? apiKey;

  /// Used to keep a single Places session across one user search
  /// (autocomplete + details) — Google bills per session, not per
  /// keystroke.
  static String _newSessionToken() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'fayha-$ts';
  }

  static String? _session;
  static String get session => _session ??= _newSessionToken();

  /// Call this when the user picks a result (closing the search
  /// sheet). Starts a fresh billing session for the next query.
  static void endSession() => _session = null;

  /// Autocomplete suggestions for [query]. Optionally biases results
  /// to a circular area around [near] within [radiusKm].
  static Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    LatLng? near,
    double radiusKm = 30,
  }) async {
    final key = apiKey;
    if (key == null || key.isEmpty || query.trim().length < 2) {
      return const [];
    }
    final params = <String, String>{
      'input': query.trim(),
      'key': key,
      'sessiontoken': session,
      'types': 'establishment|geocode',
    };
    if (near != null) {
      params['location'] = '${near.latitude},${near.longitude}';
      params['radius'] = (radiusKm * 1000).round().toString();
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK' && body['status'] != 'ZERO_RESULTS') {
        return const [];
      }
      final preds = (body['predictions'] as List).cast<Map<String, dynamic>>();
      return preds.map(PlaceSuggestion.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Resolve a Place ID to a lat/lng. Call this when the user taps a
  /// suggestion. Closes the billing session for you.
  static Future<PlaceDetail?> details(String placeId) async {
    final key = apiKey;
    if (key == null || key.isEmpty) return null;
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': key,
        'sessiontoken': session,
        'fields': 'name,geometry/location,formatted_address',
      },
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return null;
      final r = body['result'] as Map<String, dynamic>;
      final loc = (r['geometry'] as Map)['location'] as Map;
      return PlaceDetail(
        placeId: placeId,
        name: r['name'] as String? ?? '',
        address: r['formatted_address'] as String? ?? '',
        location: LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        ),
      );
    } catch (_) {
      return null;
    } finally {
      endSession();
    }
  }
}

class PlaceSuggestion {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromMap(Map<String, dynamic> m) {
    final structured = m['structured_formatting'] as Map?;
    return PlaceSuggestion(
      placeId: m['place_id'] as String,
      primaryText: (structured?['main_text'] as String?) ??
          (m['description'] as String? ?? ''),
      secondaryText: (structured?['secondary_text'] as String?) ?? '',
    );
  }
}

class PlaceDetail {
  final String placeId;
  final String name;
  final String address;
  final LatLng location;
  const PlaceDetail({
    required this.placeId,
    required this.name,
    required this.address,
    required this.location,
  });
}
