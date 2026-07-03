import 'package:supabase_flutter/supabase_flutter.dart';

/// One member's record for a single rehearsal — used by the
/// week drill-down screen.
class SessionMember {
  final String id;
  final String name;
  final String voiceSection;
  final String? photoUrl;
  final bool present;
  final int lateMinutes;
  const SessionMember({
    required this.id,
    required this.name,
    required this.voiceSection,
    this.photoUrl,
    required this.present,
    required this.lateMinutes,
  });
}

/// Full roster for one recorded rehearsal date.
class SessionRoster {
  final DateTime date;
  final String branch;
  final String status; // 'held' | 'cancelled'
  final List<SessionMember> members;
  const SessionRoster({
    required this.date,
    required this.branch,
    required this.status,
    required this.members,
  });

  Iterable<SessionMember> get present =>
      members.where((m) => m.present && m.lateMinutes == 0);
  Iterable<SessionMember> get late =>
      members.where((m) => m.present && m.lateMinutes > 0);
  Iterable<SessionMember> get absent => members.where((m) => !m.present);
}

class DayStats {
  final DateTime date;
  final String branch;
  final String status; // 'held' | 'cancelled'
  final int total; // active members in that branch
  final int present;
  final int late;
  final int absent;
  final int avgLateMinutes;

  const DayStats({
    required this.date,
    required this.branch,
    required this.status,
    required this.total,
    required this.present,
    required this.late,
    required this.absent,
    required this.avgLateMinutes,
  });

  double get presentRate => total == 0 ? 0 : present / total;
  double get absentRate => total == 0 ? 0 : absent / total;
}

class WeekStats {
  final DateTime weekStart; // Monday of the week (local time)
  final int sessions;
  final int presentTotal;
  final int lateTotal;
  final int absentTotal;
  final int avgLateMinutes;
  final List<DayStats> days;

  const WeekStats({
    required this.weekStart,
    required this.sessions,
    required this.presentTotal,
    required this.lateTotal,
    required this.absentTotal,
    required this.avgLateMinutes,
    this.days = const [],
  });

  int get attendedTotal => presentTotal + lateTotal;
}

class AttendanceStatsService {
  static final _c = Supabase.instance.client;

  /// Per-rehearsal stats for a branch over the last [weeks] weeks,
  /// newest first.
  static Future<List<DayStats>> dayStats({
    required String branch,
    int weeks = 8,
  }) async {
    final from = DateTime.now().subtract(Duration(days: weeks * 7));
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';

    final rehearsals = await _c
        .from('rehearsals')
        .select('id, session_date, status, branch')
        .eq('branch', branch)
        .gte('session_date', fromStr)
        .order('session_date', ascending: false);

    final reList = (rehearsals as List).cast<Map<String, dynamic>>();
    if (reList.isEmpty) return [];

    // Total active members in this branch (denominator).
    final memberRows = await _c
        .from('members')
        .select('id')
        .eq('branch', branch)
        .eq('status', 'active');
    final total = (memberRows as List).length;

    // Pull all attendance rows for these rehearsals in one round-trip.
    final rehIds = reList.map((r) => r['id'] as String).toList(growable: false);
    final attRows = await _c
        .from('attendance')
        .select('rehearsal_id, present, late_minutes')
        .inFilter('rehearsal_id', rehIds);

    final byReh = <String, List<Map<String, dynamic>>>{};
    for (final a in attRows as List) {
      final m = a as Map<String, dynamic>;
      byReh.putIfAbsent(m['rehearsal_id'] as String, () => []).add(m);
    }

    return reList.map((r) {
      final id = r['id'] as String;
      final rows = byReh[id] ?? const <Map<String, dynamic>>[];
      var present = 0, late = 0, lateMin = 0;
      for (final a in rows) {
        if (a['present'] == true) {
          final lm = (a['late_minutes'] as int?) ?? 0;
          if (lm > 0) {
            late++;
            lateMin += lm;
          } else {
            present++;
          }
        }
      }
      final absent = (total - present - late).clamp(0, total);
      return DayStats(
        date: DateTime.parse(r['session_date'] as String),
        branch: r['branch'] as String,
        status: (r['status'] as String?) ?? 'held',
        total: total,
        present: present,
        late: late,
        absent: absent,
        avgLateMinutes: late == 0 ? 0 : (lateMin / late).round(),
      );
    }).toList();
  }

  /// Roll up the day stats into weekly buckets (Mon–Sun).
  static List<WeekStats> rollupWeeks(List<DayStats> days) {
    DateTime weekOf(DateTime d) {
      // Monday = 1. Normalize to start-of-week midnight.
      final local = DateTime(d.year, d.month, d.day);
      return local.subtract(Duration(days: local.weekday - 1));
    }

    final buckets = <DateTime, List<DayStats>>{};
    for (final d in days) {
      buckets.putIfAbsent(weekOf(d.date), () => []).add(d);
    }
    final weeks = buckets.entries.map((e) {
      var present = 0, late = 0, absent = 0, lateMin = 0;
      for (final s in e.value) {
        present += s.present;
        late += s.late;
        absent += s.absent;
        lateMin += s.avgLateMinutes * s.late;
      }
      final sorted = [...e.value]..sort((a, b) => b.date.compareTo(a.date));
      return WeekStats(
        weekStart: e.key,
        sessions: e.value.length,
        presentTotal: present,
        lateTotal: late,
        absentTotal: absent,
        avgLateMinutes: late == 0 ? 0 : (lateMin / late).round(),
        days: sorted,
      );
    }).toList()..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return weeks;
  }

  /// Full member-by-member roster for one rehearsal date.
  static Future<SessionRoster> sessionRoster({
    required String branch,
    required DateTime date,
  }) async {
    final dStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final reh = await _c
        .from('rehearsals')
        .select('id, status')
        .eq('branch', branch)
        .eq('session_date', dStr)
        .maybeSingle();

    // All active branch members (so absent members still show up).
    final memberRows = await _c
        .from('members')
        .select('id, name, voice_section, photo_url')
        .eq('branch', branch)
        .eq('status', 'active')
        .order('name');

    final att = <String, ({bool present, int lateMinutes})>{};
    if (reh != null) {
      final attRows = await _c
          .from('attendance')
          .select('member_id, present, late_minutes')
          .eq('rehearsal_id', reh['id'] as String);
      for (final a in attRows as List) {
        final m = a as Map<String, dynamic>;
        att[m['member_id'] as String] = (
          present: m['present'] as bool,
          lateMinutes: (m['late_minutes'] as int?) ?? 0,
        );
      }
    }

    final members = (memberRows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final id = m['id'] as String;
      final rec = att[id];
      return SessionMember(
        id: id,
        name: (m['name'] as String?) ?? 'Member',
        voiceSection: (m['voice_section'] as String?) ?? '',
        photoUrl: m['photo_url'] as String?,
        present: rec?.present ?? false,
        lateMinutes: rec?.lateMinutes ?? 0,
      );
    }).toList();

    return SessionRoster(
      date: date,
      branch: branch,
      status: (reh?['status'] as String?) ?? 'held',
      members: members,
    );
  }
}
