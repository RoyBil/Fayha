import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

class FeedItem {
  final String kind; // announcement | news | concert
  final String title;
  final String body;
  final DateTime date;
  const FeedItem({
    required this.kind,
    required this.title,
    required this.body,
    required this.date,
  });
}

class NotificationsService {
  static final _c = Supabase.instance.client;

  /// Aggregated feed for members/admins: admin announcements,
  /// official news, and upcoming concerts — newest first.
  static Future<List<FeedItem>> feed() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final isMaestro =
        AppState.instance.currentMember?.role == 'superAdmin';
    final results = await Future.wait([
      _c.from('messages').select('title,body,created_at')
          .order('created_at', ascending: false),
      _c.from('news_posts').select('title,body,sort_date')
          .order('sort_date', ascending: false),
      _c.from('concerts')
          .select('title,description,location,starts_at,created_at')
          .gte('starts_at', nowIso).order('starts_at'),
      _c.from('direct_messages')
          .select('body,from_maestro,created_at,members(name)')
          .order('created_at', ascending: false),
      _c.from('polls').select('question,created_by_name,created_at')
          .order('created_at', ascending: false),
    ]);

    final items = <FeedItem>[];
    for (final m in results[0] as List) {
      items.add(FeedItem(
        kind: 'announcement',
        title: m['title'] as String,
        body: m['body'] as String,
        date: DateTime.parse(m['created_at'] as String).toLocal(),
      ));
    }
    for (final n in results[1] as List) {
      items.add(FeedItem(
        kind: 'news',
        title: n['title'] as String,
        body: n['body'] as String,
        date: DateTime.parse(n['sort_date'] as String).toLocal(),
      ));
    }
    for (final c in results[2] as List) {
      final starts = DateTime.parse(c['starts_at'] as String).toLocal();
      // Sort by when the concert was announced, not by its event date.
      final announced = c['created_at'] != null
          ? DateTime.parse(c['created_at'] as String).toLocal()
          : starts;
      items.add(FeedItem(
        kind: 'concert',
        title: 'Concert · ${c['title']}',
        body: '${c['location']} · ${starts.day}/${starts.month}/${starts.year}',
        date: announced,
      ));
    }
    // Direct messages received (not the ones you sent yourself).
    for (final d in results[3] as List) {
      final fromMaestro = d['from_maestro'] as bool;
      if (isMaestro == fromMaestro) continue; // skip own sent messages
      final senderName = fromMaestro
          ? 'Maestro Barkev'
          : ((d['members'] as Map<String, dynamic>?)?['name'] as String? ??
              'A member');
      items.add(FeedItem(
        kind: 'message',
        title: 'Message from $senderName',
        body: d['body'] as String,
        date: DateTime.parse(d['created_at'] as String).toLocal(),
      ));
    }
    for (final p in results[4] as List) {
      items.add(FeedItem(
        kind: 'poll',
        title: 'New poll · ${p['question']}',
        body: 'From ${p['created_by_name'] ?? 'an admin'} — tap Polls to vote',
        date: DateTime.parse(p['created_at'] as String).toLocal(),
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  /// SharedPreferences key for the last-seen timestamp, per signed-in user.
  static String _lastSeenKey() {
    final uid =
        AppState.instance.currentMember?.id ?? 'anon';
    return 'notifications_last_seen_$uid';
  }

  static Future<DateTime?> lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSeenKey());
    return iso == null ? null : DateTime.tryParse(iso);
  }

  /// Marks "now" as the last-seen moment for the current user.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastSeenKey(), DateTime.now().toIso8601String());
  }

  /// Count of feed items newer than the last-seen timestamp.
  static Future<int> unreadCount() async {
    final seen = await lastSeen();
    final items = await feed();
    if (seen == null) return items.length;
    return items.where((i) => i.date.isAfter(seen)).length;
  }
}
