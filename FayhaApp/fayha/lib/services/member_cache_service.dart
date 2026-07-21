import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_state.dart';

/// Persists the signed-in member's profile locally so the app can restore
/// the session instantly on the next launch without a round-trip to Supabase.
/// Only the DB-backed fields are cached; memorizedSongIds is omitted and
/// reloaded lazily once the network is available.
class MemberCacheService {
  static const _key = 'member_profile_v1';

  // In-memory mirror so repeated calls within the same session are free.
  static Member? _cached;

  static Future<void> save(Member m) async {
    _cached = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(m.toMap()));
    } catch (_) {}
  }

  static Future<Member?> load() async {
    if (_cached != null) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final m = Member.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      _cached = m;
      return m;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    _cached = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
