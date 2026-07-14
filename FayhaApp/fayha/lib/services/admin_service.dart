import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'push_notification_service.dart';

class AdminService {
  static final _c = Supabase.instance.client;

  static Future<List<Member>> fetchByStatus(String status) async {
    final rows = await _c
        .from('members')
        .select()
        .eq('status', status)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Member.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Active + deactivated members (excludes pending and removed).
  static Future<List<Member>> fetchRoster() async {
    final rows = await _c
        .from('members')
        .select()
        .inFilter('status', ['active', 'deactivated'])
        .order('name');
    return (rows as List)
        .map((r) => Member.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<Member?> fetchMember(String id) async {
    final row = await _c.from('members').select().eq('id', id).maybeSingle();
    return row == null ? null : Member.fromMap(row);
  }

  static Future<void> _setStatus(String memberId, String status) async {
    await _c.from('members').update({'status': status}).eq('id', memberId);
  }

  static Future<void> approve(String memberId) async {
    await _setStatus(memberId, 'active');
    // Notify the newly approved member. Fire-and-forget — the push may not
    // reach them if they haven't opened the app since signing up (no FCM token
    // yet), but it will succeed once they sign in and the token is registered.
    PushNotificationService.dispatch(
      title: '✅ Account Approved',
      body:
          'Welcome to Fayha National Choir! Your account has been approved — sign in now.',
      kind: 'announcement',
      memberIds: [memberId],
    ).catchError((_) {});
  }

  static Future<void> deny(String memberId) => _setStatus(memberId, 'deleted');
  static Future<void> deactivate(String memberId) =>
      _setStatus(memberId, 'deactivated');
  static Future<void> reactivate(String memberId) =>
      _setStatus(memberId, 'active');
  static Future<void> remove(String memberId) => _setStatus(memberId, 'left');

  static Future<void> setRole(String memberId, String role) async {
    if (role == 'admin') {
      final row = await _c
          .from('members')
          .select('role')
          .eq('id', memberId)
          .single();
      final currentRole = row['role'] as String?;
      await _c.from('members').update({'role': role}).eq('id', memberId);
      if (currentRole != 'admin') {
        // Inserting into member_notifications does two things:
        // 1. Stores the notification in the member's in-app history.
        // 2. Fires the push_on_member_notif DB trigger → sends FCM push.
        _c
            .from('member_notifications')
            .insert({
              'member_id': memberId,
              'kind': 'announcement',
              'title': '🎉 You\'re now an Admin!',
              'body':
                  'Congratulations! You\'ve been promoted to Admin of Fayha National Choir.',
            })
            .catchError((_) {});
      }
    } else {
      await _c.from('members').update({'role': role}).eq('id', memberId);
    }
  }

  static Future<void> setGalleryUploadPermission(
    String memberId,
    bool value,
  ) async {
    await _c
        .from('members')
        .update({'can_upload_gallery': value})
        .eq('id', memberId);
  }

  // ===== Content =====

  static Future<void> addSong({
    required String title,
    String? subtitle,
    String? composers,
    String? description,
    String? lyrics,
    String? youtubeUrl,
    String? audioUrl,
  }) async {
    final ms = DateTime.now().millisecondsSinceEpoch;
    await _c.from('songs').insert({
      'id': 'song_$ms',
      'title': title,
      'subtitle': subtitle,
      'composers': composers,
      'description': description,
      'lyrics': lyrics,
      'youtube_url': youtubeUrl,
      'audio_url': audioUrl,
      'sort_order': ms ~/ 1000,
    });
  }

  static Future<void> updateSong({
    required String id,
    required String title,
    String? subtitle,
    String? composers,
    String? description,
    String? lyrics,
    String? youtubeUrl,
    String? audioUrl,
  }) async {
    await _c
        .from('songs')
        .update({
          'title': title,
          'subtitle': subtitle,
          'composers': composers,
          'description': description,
          'lyrics': lyrics,
          'youtube_url': youtubeUrl,
          if (audioUrl != null) 'audio_url': audioUrl,
        })
        .eq('id', id);
  }

  static Future<void> deleteSong(String id) async {
    await _c.from('songs').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> fetchAudienceSongs() async {
    final rows = await _c.from('songs').select().order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Uploads an audio file for a public audience song.
  /// Returns the public URL.
  static Future<String> uploadSongAudio({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.isEmpty ? 'mp3' : fileExtension;
    // m4a files are MPEG-4 audio containers — correct MIME is audio/mp4.
    final mime = ext == 'm4a' ? 'audio/mp4' : 'audio/$ext';
    final path = 'song_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage
        .from('song_audio')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: mime),
        );
    return _c.storage.from('song_audio').getPublicUrl(path);
  }

  static Future<String> addEvent({
    required String title,
    required String location,
    required DateTime startsAt,
    required String kind, // concert | rehearsal
    String? description,
    String? posterUrl,
    String? mapsUrl,
  }) async {
    final row = await _c
        .from('concerts')
        .insert({
          'title': title,
          'location': location,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'kind': kind,
          'description': description,
          'poster_url': posterUrl,
          if (mapsUrl != null && mapsUrl.isNotEmpty) 'maps_url': mapsUrl,
        })
        .select('id')
        .single();
    final id = row['id'] as String;
    await PushNotificationService.dispatch(
      title: kind == 'concert'
          ? '🎵 New concert: $title'
          : '🎼 New rehearsal: $title',
      body: 'At $location',
      kind: 'event',
      sourceId: id,
    );
    return id;
  }

  /// Uploads an event poster to the `event_posters` bucket and
  /// returns the public URL.
  static Future<String> uploadEventPoster({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.isEmpty ? 'jpg' : fileExtension;
    final path = 'event_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage
        .from('event_posters')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: 'image/$ext'),
        );
    return _c.storage.from('event_posters').getPublicUrl(path);
  }

  static Future<void> addNews({
    required String dateLabel,
    required String title,
    required String body,
    String? posterUrl,
  }) async {
    await _c.from('news_posts').insert({
      'date_label': dateLabel,
      'title': title,
      'body': body,
      'poster_url': posterUrl,
      'sort_date': DateTime.now().toUtc().toIso8601String(),
    });
    await PushNotificationService.dispatch(
      title: '📢 $title',
      body: body.length > 100 ? '${body.substring(0, 100)}…' : body,
      kind: 'announcement',
    );
  }

  // ===== News + events: list + edit + delete =====

  static Future<List<Map<String, dynamic>>> listNews() async {
    final rows = await _c
        .from('news_posts')
        .select()
        .order('sort_date', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static Future<void> updateNews({
    required String id,
    String? dateLabel,
    String? title,
    String? body,
    String? posterUrl,
  }) async {
    final patch = <String, dynamic>{};
    if (dateLabel != null) patch['date_label'] = dateLabel;
    if (title != null) patch['title'] = title;
    if (body != null) patch['body'] = body;
    if (posterUrl != null) patch['poster_url'] = posterUrl;
    if (patch.isEmpty) return;
    await _c.from('news_posts').update(patch).eq('id', id);
  }

  static Future<void> deleteNews(String id) async {
    await _c.from('news_posts').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> listEvents() async {
    final rows = await _c
        .from('concerts')
        .select()
        .order('starts_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static Future<void> updateEvent({
    required String id,
    String? title,
    String? location,
    DateTime? startsAt,
    String? kind,
    String? description,
    String? posterUrl,
    String? mapsUrl,
    bool clearMapsUrl = false,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (location != null) patch['location'] = location;
    if (startsAt != null) {
      patch['starts_at'] = startsAt.toUtc().toIso8601String();
    }
    if (kind != null) patch['kind'] = kind;
    if (description != null) patch['description'] = description;
    if (posterUrl != null) patch['poster_url'] = posterUrl;
    if (mapsUrl != null) patch['maps_url'] = mapsUrl.isEmpty ? null : mapsUrl;
    if (clearMapsUrl) patch['maps_url'] = null;
    if (patch.isEmpty) return;
    await _c.from('concerts').update(patch).eq('id', id);
  }

  static Future<void> deleteEvent(String id) async {
    await _c.from('concerts').delete().eq('id', id);
  }
}
