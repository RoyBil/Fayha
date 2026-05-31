import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

class SessionInfo {
  final DateTime date;
  final String? status; // held | cancelled | null (not recorded)
  final DateTime? recordedAt;
  const SessionInfo(this.date, this.status, this.recordedAt);
  bool get recorded => status != null;
  bool get cancelled => status == 'cancelled';
}

/// A single entry in a member's personal attendance/events history.
/// `kind` is one of: 'rehearsal' (a past practice they attended),
/// 'concert' (past public performance), or 'big_rehearsal' (past
/// admin-scheduled big rehearsal event).
class HistoryItem {
  final String kind;
  final String title;
  final String subtitle;
  final DateTime date;
  const HistoryItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}

class AttendanceService {
  static final _c = Supabase.instance.client;

  /// Rehearsal weekdays per branch (DateTime: Mon=1 … Sun=7).
  /// Tripoli: Thursday(4), Friday(5), Saturday(6).
  // DateTime weekdays: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7.
  static const branchDays = <String, List<int>>{
    'Tripoli': [4, 5, 6], // Thursday, Friday, Saturday
    'Beirut': [1, 2, 3], // Monday, Tuesday, Wednesday
    'Chouf': [1, 2, 3], // Monday, Tuesday, Wednesday
    'Aley': [3, 4, 5], // Wednesday, Thursday, Friday
  };
  static const sessionTime = '6:00 – 9:00 PM';

  static List<int> daysFor(String branch) => branchDays[branch] ?? const [6];

  static String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Sessions to show an admin, sorted oldest→newest (today at top):
  ///  • upcoming sessions from today forward that aren't recorded yet
  ///  • sessions recorded within the last 24 hours
  /// A recorded session drops off the list 24h after it was recorded.
  static Future<List<SessionInfo>> displaySessions(String branch,
      {int weeks = 6}) async {
    final days = daysFor(branch);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Recorded rehearsals from the database.
    final rows = await _c
        .from('rehearsals')
        .select('session_date,status,recorded_at')
        .eq('branch', branch);
    final recorded = <String, ({String status, DateTime? at})>{};
    for (final r in rows as List) {
      recorded[r['session_date'] as String] = (
        status: r['status'] as String,
        at: r['recorded_at'] != null
            ? DateTime.parse(r['recorded_at'] as String).toLocal()
            : null,
      );
    }

    bool withinDay(DateTime? at) =>
        at != null && now.difference(at) < const Duration(hours: 24);

    final result = <SessionInfo>[];
    final seen = <String>{};

    // Upcoming rehearsal dates (today → +weeks).
    for (var d = today;
        !d.isAfter(today.add(Duration(days: weeks * 7)));
        d = d.add(const Duration(days: 1))) {
      if (!days.contains(d.weekday)) continue;
      final k = _d(d);
      seen.add(k);
      final rec = recorded[k];
      if (rec == null) {
        result.add(SessionInfo(d, null, null)); // pending
      } else if (withinDay(rec.at)) {
        result.add(SessionInfo(d, rec.status, rec.at)); // recorded, still in 24h
      }
      // recorded & older than 24h → hidden
    }

    // Recorded past dates still inside their 24h window.
    for (final e in recorded.entries) {
      if (seen.contains(e.key)) continue;
      if (withinDay(e.value.at)) {
        result.add(SessionInfo(
            DateTime.parse(e.key), e.value.status, e.value.at));
      }
    }

    result.sort((a, b) => a.date.compareTo(b.date)); // today/oldest first
    return result;
  }

  /// Active members of a branch, ordered by name.
  static Future<List<Member>> branchMembers(String branch) async {
    final rows = await _c
        .from('members')
        .select()
        .eq('branch', branch)
        .eq('status', 'active')
        .order('name');
    return (rows as List)
        .map((r) => Member.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Loads the saved sheet for one session.
  static Future<({String? status, Map<String, bool> present})> loadSheet(
      String branch, DateTime date) async {
    final reh = await _c
        .from('rehearsals')
        .select('id,status')
        .eq('branch', branch)
        .eq('session_date', _d(date))
        .maybeSingle();
    if (reh == null) return (status: null, present: <String, bool>{});
    final att = await _c
        .from('attendance')
        .select('member_id,present')
        .eq('rehearsal_id', reh['id'] as String);
    final present = <String, bool>{};
    for (final a in att as List) {
      present[a['member_id'] as String] = a['present'] as bool;
    }
    return (status: reh['status'] as String, present: present);
  }

  /// Subscribes to live changes on the `attendance` table for the
  /// current user. The callback fires whenever an admin records (or
  /// edits) their attendance from any device. Caller is responsible
  /// for unsubscribing the returned channel.
  static RealtimeChannel? subscribeToMyAttendance(VoidCallback onChange) {
    final userId = _c.auth.currentUser?.id;
    if (userId == null) return null;
    final channel = _c.channel('public:attendance:member=$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'member_id',
            value: userId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  static Future<void> unsubscribe(RealtimeChannel? c) async {
    if (c == null) return;
    try {
      await _c.removeChannel(c);
    } catch (_) {}
  }

  /// Number of rehearsals the current member has been marked present at.
  /// Used by the home screen to keep stats in sync after attendance is taken.
  static Future<int> myRehearsalCount() async {
    final me = AppState.instance.currentMember;
    if (me == null) return 0;
    return rehearsalCountFor(me.id);
  }

  /// Number of rehearsals any given member has been marked present at.
  /// Used by the member detail page to keep stats live for every profile.
  static Future<int> rehearsalCountFor(String memberId) async {
    try {
      final rows = await _c
          .from('attendance')
          .select('rehearsal_id')
          .eq('member_id', memberId)
          .eq('present', true);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// One entry in a member's personal history feed: either a rehearsal
  /// they attended or a past concert/event the choir performed.
  /// `kind` is 'rehearsal' | 'concert' | 'big_rehearsal'.
  static Future<List<HistoryItem>> myHistory({int limit = 200}) async {
    final me = AppState.instance.currentMember;
    if (me == null) return [];

    final items = <HistoryItem>[];

    // Rehearsals where I was present.
    try {
      final attRows = await _c
          .from('attendance')
          .select('rehearsal_id, present, rehearsals(branch, session_date, status)')
          .eq('member_id', me.id)
          .eq('present', true)
          .limit(limit);
      for (final r in attRows as List) {
        final reh = r['rehearsals'] as Map<String, dynamic>?;
        if (reh == null) continue;
        final dateStr = reh['session_date'] as String?;
        if (dateStr == null) continue;
        items.add(HistoryItem(
          kind: 'rehearsal',
          title: 'Rehearsal · ${reh['branch']}',
          subtitle: sessionTime,
          date: DateTime.parse(dateStr),
        ));
      }
    } catch (_) {
      // ignore — table may be missing on a fresh install
    }

    // Past concerts/big rehearsals (events) the choir performed.
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final evRows = await _c
          .from('concerts')
          .select('title, location, starts_at, kind')
          .lt('starts_at', nowIso)
          .order('starts_at', ascending: false)
          .limit(limit);
      for (final e in evRows as List) {
        final starts = DateTime.parse(e['starts_at'] as String).toLocal();
        final kind = (e['kind'] as String?) ?? 'concert';
        final isRehearsal = kind == 'rehearsal' || kind == 'big_rehearsal';
        items.add(HistoryItem(
          kind: isRehearsal ? 'big_rehearsal' : 'concert',
          title:
              '${isRehearsal ? "Big rehearsal" : "Concert"} · ${e['title']}',
          subtitle: (e['location'] as String?) ?? '',
          date: starts,
        ));
      }
    } catch (_) {
      // ignore
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  /// Saves a session: marks it held/cancelled and upserts attendance.
  static Future<void> save({
    required String branch,
    required DateTime date,
    required bool cancelled,
    required Map<String, bool> present,
  }) async {
    final me = AppState.instance.currentMember;
    final reh = await _c.from('rehearsals').upsert({
      'branch': branch,
      'session_date': _d(date),
      'status': cancelled ? 'cancelled' : 'held',
      'recorded_by': me?.id,
      'recorded_by_name': me?.name,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'branch,session_date').select('id').single();

    if (cancelled) return;
    final rehId = reh['id'] as String;
    final rows = present.entries
        .map((e) => {
              'rehearsal_id': rehId,
              'member_id': e.key,
              'present': e.value,
            })
        .toList();
    if (rows.isNotEmpty) {
      await _c
          .from('attendance')
          .upsert(rows, onConflict: 'rehearsal_id,member_id');
    }
  }
}
