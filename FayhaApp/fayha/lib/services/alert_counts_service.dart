import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

/// Centralised "unread / pending" counts used to render badge dots
/// throughout the app (home tiles, admin panel tabs, etc.).
///
/// All methods swallow errors and return 0 — a missing badge is
/// always better than a crash.
class AlertCountsService {
  static final _c = Supabase.instance.client;

  // ===== Per-user last-seen timestamps (SharedPreferences) =====

  static String _kDms() =>
      'last_seen_dms_${AppState.instance.currentMember?.id ?? "anon"}';
  static String _kAdminInbox() =>
      'last_seen_admin_inbox_${AppState.instance.currentMember?.id ?? "anon"}';

  static Future<DateTime?> _lastSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(key);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  static Future<void> _markSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, DateTime.now().toIso8601String());
  }

  static Future<void> markDmsSeen() => _markSeen(_kDms());
  static Future<void> markAdminInboxSeen() => _markSeen(_kAdminInbox());

  // ===== Polls a member hasn't voted on yet =====

  static Future<int> unvotedPolls() async {
    try {
      final me = AppState.instance.currentMember;
      final uid = _c.auth.currentUser?.id;
      if (me == null || uid == null) return 0;
      // Only OPEN polls count: a closed poll the user never voted on
      // would otherwise pin the badge at 1 forever.
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final polls = await _c
          .from('polls')
          .select('id')
          .or('closes_at.is.null,closes_at.gt.$nowIso');
      final myVotes = await _c
          .from('poll_votes')
          .select('poll_id')
          .eq('member_id', uid);
      final votedIds = (myVotes as List)
          .map((r) => (r as Map<String, dynamic>)['poll_id'] as String)
          .toSet();
      var unvoted = 0;
      for (final p in polls as List) {
        final id = (p as Map<String, dynamic>)['id'] as String;
        if (!votedIds.contains(id)) unvoted++;
      }
      return unvoted;
    } catch (_) {
      return 0;
    }
  }

  // ===== Unread DMs =====

  /// For a non-Maestro member: count of DMs received from Maestro newer
  /// than the last time they opened their thread.
  /// For Maestro: count of inbound member DMs newer than last inbox open.
  static Future<int> unreadDms() async {
    try {
      final me = AppState.instance.currentMember;
      if (me == null) return 0;
      final seen = await _lastSeen(_kDms());
      final seenIso = (seen ?? DateTime.fromMillisecondsSinceEpoch(0))
          .toUtc()
          .toIso8601String();
      if (me.isMaestro) {
        final rows = await _c
            .from('direct_messages')
            .select('id')
            .eq('from_maestro', false)
            .gt('created_at', seenIso);
        return (rows as List).length;
      } else {
        final rows = await _c
            .from('direct_messages')
            .select('id')
            .eq('member_id', me.id)
            .eq('from_maestro', true)
            .gt('created_at', seenIso);
        return (rows as List).length;
      }
    } catch (_) {
      return 0;
    }
  }

  // ===== Admin tile combined count =====

  /// New items in the admin inbox since the last time the admin
  /// opened the panel: pending member approvals (Maestro only) +
  /// new join requests. Old items the admin has already seen don't
  /// count — opening the admin panel clears the home badge.
  static Future<int> adminInbox() async {
    if (AppState.instance.currentMember == null) return 0;
    final seen = await _lastSeen(_kAdminInbox());
    final seenIso = (seen ?? DateTime.fromMillisecondsSinceEpoch(0))
        .toUtc()
        .toIso8601String();
    var total = 0;
    try {
      if (AppState.instance.isMaestro) {
        final pending = await _c
            .from('members')
            .select('id')
            .eq('status', 'pending')
            .gt('created_at', seenIso);
        total += (pending as List).length;
      }
    } catch (_) {}
    try {
      final joins = await _c
          .from('join_requests')
          .select('id')
          .eq('status', 'new')
          .gt('created_at', seenIso);
      total += (joins as List).length;
    } catch (_) {}
    return total;
  }

  // ===== Individual admin counts (for tab badges) =====

  static Future<int> pendingApprovalsCount() async {
    try {
      if (!AppState.instance.isMaestro) return 0;
      final rows = await _c
          .from('members')
          .select('id')
          .eq('status', 'pending');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> newJoinRequestsCount() async {
    try {
      final rows = await _c
          .from('join_requests')
          .select('id')
          .eq('status', 'new');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }
}
