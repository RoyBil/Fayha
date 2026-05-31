import 'package:supabase_flutter/supabase_flutter.dart';

class MemberSongsService {
  static final _c = Supabase.instance.client;

  /// Song IDs the given member knows. Used by the member detail screen
  /// and to hydrate the current user's `memorizedSongIds` on sign-in.
  static Future<Set<String>> fetchForMember(String memberId) async {
    final rows = await _c
        .from('member_songs')
        .select('song_id')
        .eq('member_id', memberId);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['song_id'] as String)
        .toSet();
  }

  static Future<void> add({
    required String memberId,
    required String songId,
  }) async {
    await _c.from('member_songs').upsert({
      'member_id': memberId,
      'song_id': songId,
    });
  }

  static Future<void> remove({
    required String memberId,
    required String songId,
  }) async {
    await _c
        .from('member_songs')
        .delete()
        .eq('member_id', memberId)
        .eq('song_id', songId);
  }
}
