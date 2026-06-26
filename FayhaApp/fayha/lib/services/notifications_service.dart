import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

/// One row in the notifications feed. `kind` tells the UI which icon
/// and label to use; `sourceId` / `extra` carry enough info to deep-
/// link to the right destination when the user taps the item.
class FeedItem {
  /// 'announcement' | 'news' | 'concert' | 'big_rehearsal' | 'message' | 'poll'
  final String kind;
  final String title;
  final String body;
  final DateTime date;

  /// Stable id for per-item state (star, mark-unread). Built from
  /// the underlying row's primary key when possible.
  final String id;

  /// Reference to the underlying row used for navigation. For
  /// concerts, includes title/location/etc so the detail screen can
  /// render without a refetch.
  final Map<String, dynamic> extra;

  const FeedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.date,
    this.extra = const {},
  });
}

class NotificationsService {
  static final _c = Supabase.instance.client;

  /// Aggregated feed for members/admins: admin announcements,
  /// official news, upcoming concerts, DMs, polls — newest first.
  static Future<List<FeedItem>> feed() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final isMaestro =
        AppState.instance.currentMember?.role == 'superAdmin';
    final myId = _c.auth.currentUser?.id ?? '';
    final memberNotifsFuture = myId.isNotEmpty
        ? _c
            .from('member_notifications')
            .select()
            .eq('member_id', myId)
            .order('created_at', ascending: false)
            .then((r) => r as List<dynamic>)
            .catchError((_) => <dynamic>[])
        : Future.value(<dynamic>[]);

    final results = await Future.wait([
      _c.from('messages').select('id,title,body,created_at,sender_name')
          .order('created_at', ascending: false),
      _c.from('news_posts').select('id,title,body,sort_date,poster_url,date_label')
          .order('sort_date', ascending: false),
      _c.from('concerts')
          .select('id,title,description,location,starts_at,kind,poster_url,created_at')
          .gte('starts_at', nowIso).order('starts_at'),
      _c.from('direct_messages')
          .select('id,member_id,body,from_maestro,created_at,members(name)')
          .order('created_at', ascending: false),
      _c.from('polls').select('id,question,created_by_name,created_at')
          .order('created_at', ascending: false),
      memberNotifsFuture,
    ]);

    final items = <FeedItem>[];
    for (final m in results[0]) {
      items.add(FeedItem(
        id: 'msg:${m['id']}',
        kind: 'announcement',
        title: m['title'] as String,
        body: m['body'] as String,
        date: DateTime.parse(m['created_at'] as String).toLocal(),
        extra: {
          'sender_name': m['sender_name'],
        },
      ));
    }
    for (final n in results[1]) {
      items.add(FeedItem(
        id: 'news:${n['id']}',
        kind: 'news',
        title: n['title'] as String,
        body: n['body'] as String,
        date: DateTime.parse(n['sort_date'] as String).toLocal(),
        extra: {
          'poster_url': n['poster_url'],
          'date_label': n['date_label'],
        },
      ));
    }
    for (final c in results[2]) {
      final starts = DateTime.parse(c['starts_at'] as String).toLocal();
      final announced = c['created_at'] != null
          ? DateTime.parse(c['created_at'] as String).toLocal()
          : starts;
      final isRehearsal = (c['kind'] as String?) == 'rehearsal';
      items.add(FeedItem(
        id: 'concert:${c['id']}',
        kind: isRehearsal ? 'big_rehearsal' : 'concert',
        title: '${isRehearsal ? "Rehearsal" : "Concert"} · ${c['title']}',
        body: '${c['location']} · ${starts.day}/${starts.month}/${starts.year}',
        date: announced,
        extra: {
          'concert_title': c['title'],
          'location': c['location'],
          'description': c['description'] ?? '',
          'starts_at': c['starts_at'],
          'kind': c['kind'] ?? 'concert',
          'poster_url': c['poster_url'],
        },
      ));
    }
    // Direct messages received (skip own sent ones).
    for (final d in results[3]) {
      final fromMaestro = d['from_maestro'] as bool;
      if (isMaestro == fromMaestro) continue;
      final senderName = fromMaestro
          ? 'Maestro Barkev'
          : ((d['members'] as Map<String, dynamic>?)?['name'] as String? ??
              'A member');
      items.add(FeedItem(
        id: 'dm:${d['id']}',
        kind: 'message',
        title: 'Message from $senderName',
        body: (d['body'] as String?) ?? '🎙 Voice message',
        date: DateTime.parse(d['created_at'] as String).toLocal(),
        extra: {
          'member_id': d['member_id'],
          'sender_name': senderName,
        },
      ));
    }
    for (final p in results[4]) {
      items.add(FeedItem(
        id: 'poll:${p['id']}',
        kind: 'poll',
        title: 'New poll · ${p['question']}',
        body: 'From ${p['created_by_name'] ?? 'an admin'} — tap to vote',
        date: DateTime.parse(p['created_at'] as String).toLocal(),
      ));
    }
    // Personal notifications (trip added, etc.)
    if (results.length > 5) {
      for (final n in results[5]) {
        items.add(FeedItem(
          id: 'notif:${n['id']}',
          kind: n['kind'] as String,
          title: n['title'] as String,
          body: n['body'] as String,
          date: DateTime.parse(n['created_at'] as String).toLocal(),
          extra: {
            'source_id': n['source_id'],
          },
        ));
      }
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  // ===== Per-user "last seen" timestamp (bell badge) =====

  static String _lastSeenKey() {
    final uid = AppState.instance.currentMember?.id ?? 'anon';
    return 'notifications_last_seen_$uid';
  }

  static Future<DateTime?> lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSeenKey());
    return iso == null ? null : DateTime.tryParse(iso);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastSeenKey(), DateTime.now().toIso8601String());
  }

  static Future<int> unreadCount() async {
    // Bail out early when the app hasn't finished loading the signed-in
    // member. Otherwise every read goes under the "anon" SharedPrefs
    // key, has no last-seen timestamp, and the badge lights up with
    // every notification ever.
    if (AppState.instance.currentMember == null) return 0;
    final seen = await lastSeen();
    final items = await feed();
    final read = await readIds();
    final forcedUnread = await forcedUnreadIds();
    return items.where((i) {
      if (forcedUnread.contains(i.id)) return true;
      if (read.contains(i.id)) return false;
      if (seen == null) return true;
      return i.date.isAfter(seen);
    }).length;
  }

  // ===== Per-item star + mark-unread state (SharedPreferences) =====

  static String _starKey() {
    final uid = AppState.instance.currentMember?.id ?? 'anon';
    return 'notif_starred_$uid';
  }

  static String _unreadKey() {
    final uid = AppState.instance.currentMember?.id ?? 'anon';
    return 'notif_forced_unread_$uid';
  }

  static Future<Set<String>> starredIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_starKey()) ?? const []).toSet();
  }

  static Future<void> toggleStar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final s = (prefs.getStringList(_starKey()) ?? <String>[]).toSet();
    if (!s.add(id)) s.remove(id);
    await prefs.setStringList(_starKey(), s.toList());
  }

  // ===== Per-item "read" set =====
  // Items the user has explicitly tapped open. They stay read forever
  // (unless explicitly marked unread again) regardless of `lastSeen`.

  static String _readKey() {
    final uid = AppState.instance.currentMember?.id ?? 'anon';
    return 'notif_read_$uid';
  }

  static Future<Set<String>> readIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_readKey()) ?? const []).toSet();
  }

  /// Marks one notification as read. Also clears any forced-unread
  /// flag for that id.
  static Future<void> markItemRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final r = (prefs.getStringList(_readKey()) ?? <String>[]).toSet();
    r.add(id);
    await prefs.setStringList(_readKey(), r.toList());
    final u = (prefs.getStringList(_unreadKey()) ?? <String>[]).toSet();
    if (u.remove(id)) {
      await prefs.setStringList(_unreadKey(), u.toList());
    }
  }

  /// IDs the user has explicitly marked unread (overrides the
  /// timestamp-based "seen" logic for the bell badge).
  static Future<Set<String>> forcedUnreadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_unreadKey()) ?? const []).toSet();
  }

  static Future<void> markUnread(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final s = (prefs.getStringList(_unreadKey()) ?? <String>[]).toSet();
    s.add(id);
    await prefs.setStringList(_unreadKey(), s.toList());
    // Also lift the "read" flag so the item is genuinely unread again.
    final r = (prefs.getStringList(_readKey()) ?? <String>[]).toSet();
    if (r.remove(id)) {
      await prefs.setStringList(_readKey(), r.toList());
    }
  }

  static Future<void> clearForcedUnread(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final s = (prefs.getStringList(_unreadKey()) ?? <String>[]).toSet();
    s.remove(id);
    await prefs.setStringList(_unreadKey(), s.toList());
  }
}
