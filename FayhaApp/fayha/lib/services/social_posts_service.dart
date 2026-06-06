import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_data.dart';

class SocialPostsService {
  static final _c = Supabase.instance.client;

  /// Everything (incl. hidden + normal) — editor / superAdmin only,
  /// enforced by RLS.
  static Future<List<SocialPost>> listAll() async {
    final rows = await _c
        .from('social_posts')
        .select()
        .order('posted_at', ascending: false);
    return (rows as List).map(_fromMap).toList();
  }

  /// Audience-side view: only the "important" posts.
  static Future<List<SocialPost>> listImportant() async {
    final rows = await _c
        .from('social_posts')
        .select()
        .eq('importance', 'important')
        .order('posted_at', ascending: false);
    return (rows as List).map(_fromMap).toList();
  }

  static Future<void> setImportance(
      String id, SocialImportance importance) async {
    await _c
        .from('social_posts')
        .update({'importance': importance.name})
        .eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _c.from('social_posts').delete().eq('id', id);
  }

  static SocialPost _fromMap(dynamic r) {
    final m = r as Map<String, dynamic>;
    return SocialPost(
      id: m['id'] as String?,
      platform: (m['platform'] as String?) ?? '',
      author: (m['author'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      postedAgo: (m['posted_label'] as String?) ?? '',
      permalink: m['permalink'] as String?,
      mediaUrl: m['media_url'] as String?,
      mediaType: m['media_type'] as String?,
      importance: _importanceFrom(m['importance'] as String?),
    );
  }

  static SocialImportance _importanceFrom(String? v) {
    switch (v) {
      case 'important':
        return SocialImportance.important;
      case 'hidden':
        return SocialImportance.hidden;
      default:
        return SocialImportance.normal;
    }
  }
}
