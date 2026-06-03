import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

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

  static Future<void> approve(String memberId) => _setStatus(memberId, 'active');
  static Future<void> deny(String memberId) => _setStatus(memberId, 'deleted');
  static Future<void> deactivate(String memberId) =>
      _setStatus(memberId, 'deactivated');
  static Future<void> reactivate(String memberId) =>
      _setStatus(memberId, 'active');
  static Future<void> remove(String memberId) => _setStatus(memberId, 'left');

  static Future<void> setRole(String memberId, String role) async {
    await _c.from('members').update({'role': role}).eq('id', memberId);
  }

  // ===== Content =====

  static Future<void> addSong({
    required String title,
    String? subtitle,
    String? composers,
    String? description,
    String? lyrics,
    String? youtubeUrl,
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
      'sort_order': ms ~/ 1000,
    });
  }

  static Future<void> addEvent({
    required String title,
    required String location,
    required DateTime startsAt,
    required String kind, // concert | rehearsal
    String? description,
    String? posterUrl,
  }) async {
    await _c.from('concerts').insert({
      'title': title,
      'location': location,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'kind': kind,
      'description': description,
      'poster_url': posterUrl,
    });
  }

  /// Uploads an event poster to the `event_posters` bucket and
  /// returns the public URL.
  static Future<String> uploadEventPoster({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.isEmpty ? 'jpg' : fileExtension;
    final path = 'event_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from('event_posters').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: 'image/$ext',
          ),
        );
    return _c.storage.from('event_posters').getPublicUrl(path);
  }

  static Future<void> addNews({
    required String dateLabel,
    required String title,
    required String body,
  }) async {
    await _c.from('news_posts').insert({
      'date_label': dateLabel,
      'title': title,
      'body': body,
      'sort_date': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
