import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Activity type ─────────────────────────────────────────────────────────────

enum HistoryActivityType {
  concert,
  festival,
  competition,
  rehearsal,
  workshop,
  other;

  String get label => switch (this) {
    concert => 'Concert',
    festival => 'Festival',
    competition => 'Competition',
    rehearsal => 'Rehearsal',
    workshop => 'Workshop',
    other => 'Other',
  };

  String get dbValue => switch (this) {
    concert => 'concert',
    festival => 'festival',
    competition => 'competition',
    rehearsal => 'rehearsal',
    workshop => 'workshop',
    other => 'other',
  };

  static HistoryActivityType fromDb(String v) => switch (v) {
    'concert' => concert,
    'festival' => festival,
    'competition' => competition,
    'rehearsal' => rehearsal,
    'workshop' => workshop,
    _ => other,
  };
}

// ── Models ────────────────────────────────────────────────────────────────────

class ChoirHistoryActivity {
  final String id;
  final String tripId;
  final HistoryActivityType type;
  final String title;
  final String? description;
  final DateTime? activityDate;
  final DateTime createdAt;

  const ChoirHistoryActivity({
    required this.id,
    required this.tripId,
    required this.type,
    required this.title,
    this.description,
    this.activityDate,
    required this.createdAt,
  });

  factory ChoirHistoryActivity.fromMap(Map<String, dynamic> r) =>
      ChoirHistoryActivity(
        id: r['id'] as String,
        tripId: r['trip_id'] as String,
        type: HistoryActivityType.fromDb((r['type'] as String?) ?? 'other'),
        title: r['title'] as String,
        description: r['description'] as String?,
        activityDate: r['activity_date'] != null
            ? DateTime.parse(r['activity_date'] as String)
            : null,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class ChoirHistoryTrip {
  final String id;
  final String name;
  final String city;
  final String country;
  final DateTime startDate;
  final DateTime? endDate;
  final String? description;
  final List<String> photoUrls;
  final List<ChoirHistoryActivity> activities;
  final DateTime createdAt;
  final double? lat;
  final double? lng;

  const ChoirHistoryTrip({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.startDate,
    this.endDate,
    this.description,
    required this.photoUrls,
    required this.activities,
    required this.createdAt,
    this.lat,
    this.lng,
  });

  String get location => '$city, $country';
  bool get hasCoordinates => lat != null && lng != null;

  factory ChoirHistoryTrip.fromMap(Map<String, dynamic> r) {
    final actRows = (r['choir_history_activities'] as List?) ?? [];
    return ChoirHistoryTrip(
      id: r['id'] as String,
      name: r['name'] as String,
      city: r['city'] as String,
      country: r['country'] as String,
      startDate: DateTime.parse(r['start_date'] as String),
      endDate: r['end_date'] != null
          ? DateTime.parse(r['end_date'] as String)
          : null,
      description: r['description'] as String?,
      photoUrls: (r['photo_urls'] as List?)?.cast<String>() ?? [],
      activities: actRows
          .map((a) => ChoirHistoryActivity.fromMap(a as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(r['created_at'] as String),
      lat: (r['lat'] as num?)?.toDouble(),
      lng: (r['lng'] as num?)?.toDouble(),
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class ChoirHistoryService {
  static final _c = Supabase.instance.client;
  static const _bucket = 'choir_history';

  // ── Trips ──────────────────────────────────────────────────────────────────

  static Future<List<ChoirHistoryTrip>> fetchAll() async {
    final rows = await _c
        .from('choir_history_trips')
        .select('*, choir_history_activities(*)')
        .order('start_date', ascending: false);
    return (rows as List)
        .map((r) => ChoirHistoryTrip.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<String> create({
    required String name,
    required String city,
    required String country,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    double? lat,
    double? lng,
  }) async {
    final me = _c.auth.currentUser?.id;
    String d(DateTime x) => x.toIso8601String().split('T').first;
    final row = await _c
        .from('choir_history_trips')
        .insert({
          'name': name,
          'city': city,
          'country': country,
          'start_date': d(startDate),
          if (endDate != null) 'end_date': d(endDate),
          if (description != null && description.isNotEmpty)
            'description': description,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'created_by': me,
        })
        .select()
        .single();
    return row['id'] as String;
  }

  static Future<void> update(
    String id, {
    String? name,
    String? city,
    String? country,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    String? description,
    List<String>? photoUrls,
    double? lat,
    double? lng,
    bool clearCoordinates = false,
  }) async {
    String d(DateTime x) => x.toIso8601String().split('T').first;
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (city != null) patch['city'] = city;
    if (country != null) patch['country'] = country;
    if (startDate != null) patch['start_date'] = d(startDate);
    if (endDate != null) patch['end_date'] = d(endDate);
    if (clearEndDate) patch['end_date'] = null;
    if (description != null) patch['description'] = description;
    if (photoUrls != null) patch['photo_urls'] = photoUrls;
    if (lat != null) patch['lat'] = lat;
    if (lng != null) patch['lng'] = lng;
    if (clearCoordinates) {
      patch['lat'] = null;
      patch['lng'] = null;
    }
    if (patch.isEmpty) return;
    await _c.from('choir_history_trips').update(patch).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _c.from('choir_history_trips').delete().eq('id', id);
  }

  // ── Photos ─────────────────────────────────────────────────────────────────

  static Future<String> uploadPhoto({
    required String tripId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.isEmpty ? 'jpg' : fileExtension;
    final path = 'trips/$tripId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    await _c.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return _c.storage.from(_bucket).getPublicUrl(path);
  }

  // ── Activities ─────────────────────────────────────────────────────────────

  static Future<ChoirHistoryActivity> addActivity({
    required String tripId,
    required HistoryActivityType type,
    required String title,
    String? description,
    DateTime? activityDate,
  }) async {
    String d(DateTime x) => x.toIso8601String().split('T').first;
    final row = await _c
        .from('choir_history_activities')
        .insert({
          'trip_id': tripId,
          'type': type.dbValue,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (activityDate != null) 'activity_date': d(activityDate),
        })
        .select()
        .single();
    return ChoirHistoryActivity.fromMap(row);
  }

  static Future<void> deleteActivity(String id) async {
    await _c.from('choir_history_activities').delete().eq('id', id);
  }

  // ── Member participations ──────────────────────────────────────────────────

  static Future<Set<String>> fetchMyParticipations() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return {};
    final rows = await _c
        .from('member_history_trips')
        .select('trip_id')
        .eq('member_id', me);
    return {for (final r in rows as List) r['trip_id'] as String};
  }

  static Future<int> fetchParticipantCount(String tripId) async {
    final rows = await _c
        .from('member_history_trips')
        .select('member_id')
        .eq('trip_id', tripId);
    return (rows as List).length;
  }

  static Future<void> joinTrip(String tripId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return;
    await _c.from('member_history_trips').upsert({
      'member_id': me,
      'trip_id': tripId,
    });
  }

  static Future<void> leaveTrip(String tripId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return;
    await _c
        .from('member_history_trips')
        .delete()
        .eq('member_id', me)
        .eq('trip_id', tripId);
  }
}
