import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class QrSession {
  final String id;
  final String? rehearsalId;
  final String? concertId;
  final String? branch;
  final String token;
  final DateTime startedAt;
  final DateTime validFrom;
  final DateTime expiresAt;
  final DateTime? lateAfter;
  QrSession({
    required this.id,
    this.rehearsalId,
    this.concertId,
    this.branch,
    required this.token,
    required this.startedAt,
    required this.validFrom,
    required this.expiresAt,
    this.lateAfter,
  });
  factory QrSession.fromMap(Map<String, dynamic> m) => QrSession(
    id: m['id'] as String,
    rehearsalId: m['rehearsal_id'] as String?,
    concertId: m['concert_id'] as String?,
    branch: m['branch'] as String?,
    token: m['token'] as String,
    startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
    validFrom: m['valid_from'] != null
        ? DateTime.parse(m['valid_from'] as String).toLocal()
        : DateTime.parse(m['started_at'] as String).toLocal(),
    expiresAt: DateTime.parse(m['expires_at'] as String).toLocal(),
    lateAfter: m['late_after'] == null
        ? null
        : DateTime.parse(m['late_after'] as String).toLocal(),
  );

  Duration get remaining => expiresAt.difference(DateTime.now());
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => DateTime.now().isBefore(validFrom);
  bool get isActive => !isExpired && !isPending;
}

class QrCheckin {
  final String memberId;
  final String memberName;
  final DateTime checkedInAt;
  final int lateMinutes;
  final double? lat;
  final double? lng;
  QrCheckin({
    required this.memberId,
    required this.memberName,
    required this.checkedInAt,
    required this.lateMinutes,
    this.lat,
    this.lng,
  });
}

class QrAttendanceService {
  static final _c = Supabase.instance.client;

  /// Creates a QR session for a rehearsal date on [branch].
  ///
  /// [validFrom] — when the QR becomes scannable. Defaults to now.
  /// [validFor] — duration the QR stays scannable. Defaults to 3h.
  /// [lateAfter] — scans after this moment are flagged as late.
  ///               Defaults to 15 min past [validFrom].
  static Future<QrSession> startSession({
    required String branch,
    DateTime? date,
    DateTime? validFrom,
    DateTime? lateAfter,
    Duration validFor = const Duration(hours: 3),
  }) async {
    final now = DateTime.now();
    final day = date ?? DateTime(now.year, now.month, now.day);
    final from = validFrom ?? now;
    final dayStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    final existingRehearsal = await _c
        .from('rehearsals')
        .select('id')
        .eq('branch', branch)
        .eq('session_date', dayStr)
        .maybeSingle();
    String rehearsalId;
    if (existingRehearsal != null) {
      rehearsalId = existingRehearsal['id'] as String;
    } else {
      final row = await _c
          .from('rehearsals')
          .insert({
            'branch': branch,
            'session_date': dayStr,
            'status': 'held',
            'recorded_by': _c.auth.currentUser?.id,
          })
          .select('id')
          .single();
      rehearsalId = row['id'] as String;
    }

    return _createSession(
      rehearsalId: rehearsalId,
      concertId: null,
      branch: branch,
      validFrom: from,
      validFor: validFor,
      lateAfter: lateAfter,
    );
  }

  /// Same as [startSession] but for a concert / big rehearsal event.
  static Future<QrSession> startSessionForConcert({
    required String concertId,
    DateTime? validFrom,
    DateTime? lateAfter,
    Duration validFor = const Duration(hours: 3),
  }) async {
    return _createSession(
      rehearsalId: null,
      concertId: concertId,
      branch: null,
      validFrom: validFrom ?? DateTime.now(),
      validFor: validFor,
      lateAfter: lateAfter,
    );
  }

  static Future<QrSession> _createSession({
    required String? rehearsalId,
    required String? concertId,
    required String? branch,
    required DateTime validFrom,
    required Duration validFor,
    DateTime? lateAfter,
  }) async {
    final now = DateTime.now();
    // Reuse a still-valid session if one exists for the same target.
    final base = _c
        .from('qr_sessions')
        .select()
        .gt('expires_at', now.toUtc().toIso8601String());
    final liveRows =
        await (rehearsalId != null
                ? base.eq('rehearsal_id', rehearsalId)
                : base.eq('concert_id', concertId as Object))
            .order('started_at', ascending: false)
            .limit(1);
    if (liveRows.isNotEmpty) {
      return QrSession.fromMap(liveRows.first);
    }

    final token = _generateToken();
    final inserted = await _c
        .from('qr_sessions')
        .insert({
          'rehearsal_id': rehearsalId,
          'concert_id': concertId,
          'branch': branch,
          'token': token,
          'started_at': now.toUtc().toIso8601String(),
          'valid_from': validFrom.toUtc().toIso8601String(),
          'expires_at': validFrom.add(validFor).toUtc().toIso8601String(),
          'late_after':
              (lateAfter ?? validFrom.add(const Duration(minutes: 15)))
                  .toUtc()
                  .toIso8601String(),
          'created_by': _c.auth.currentUser?.id,
        })
        .select()
        .single();
    final session = QrSession.fromMap(inserted);

    // Admin running the session is, by definition, attending.
    await _autoAttendAdmin(
      rehearsalId: rehearsalId,
      concertId: concertId,
      sessionId: session.id,
    );
    return session;
  }

  /// Upserts the current admin / superAdmin as present for this
  /// target. Safe to call repeatedly. Swallows errors so session
  /// creation never blocks on it.
  static Future<void> _autoAttendAdmin({
    required String? rehearsalId,
    required String? concertId,
    required String sessionId,
  }) async {
    final adminId = _c.auth.currentUser?.id;
    if (adminId == null) return;
    try {
      // We can't use ON CONFLICT here: after v2 the `attendance`
      // uniqueness lives in two partial unique indexes (one per
      // target), and PostgREST's `upsert(onConflict: 'a,b')` only
      // matches a non-partial constraint. So: select then update or
      // insert.
      final row = <String, dynamic>{
        'member_id': adminId,
        'present': true,
        'late_minutes': 0,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
        'via': 'qr',
        'qr_session_id': sessionId,
      };

      final query = _c.from('attendance').select('id').eq('member_id', adminId);
      final existing =
          await (rehearsalId != null
                  ? query.eq('rehearsal_id', rehearsalId)
                  : query.eq('concert_id', concertId as Object))
              .maybeSingle();

      if (existing != null) {
        await _c
            .from('attendance')
            .update(row)
            .eq('id', existing['id'] as String);
      } else {
        if (rehearsalId != null) row['rehearsal_id'] = rehearsalId;
        if (concertId != null) row['concert_id'] = concertId;
        await _c.from('attendance').insert(row);
      }
    } catch (_) {
      // Don't fail session creation if the admin's own attendance row
      // can't be written — the QR session itself is the priority.
    }
  }

  /// Member side: send the scanned token + (optional) GPS to the
  /// `claim_attendance` RPC. Throws with a human message on failure
  /// (invalid / expired / already-checked-in / etc.).
  ///
  /// Returns the late-minute count from the server.
  static Future<int> claimAttendance({
    required String token,
    double? lat,
    double? lng,
  }) async {
    final res = await _c.rpc(
      'claim_attendance',
      params: {'p_token': token, 'p_lat': lat, 'p_lng': lng},
    );
    final map = (res as Map).cast<String, dynamic>();
    return (map['late_minutes'] as num?)?.toInt() ?? 0;
  }

  /// Returns the live list of check-ins for one session, newest first.
  static Future<List<QrCheckin>> checkins(QrSession session) async {
    final rows = await _c
        .from('attendance')
        .select(
          'member_id, late_minutes, checked_in_at, '
          'checked_in_lat, checked_in_lng, '
          'members:member_id(name)',
        )
        .eq('qr_session_id', session.id)
        .order('checked_in_at', ascending: false);
    return _mapCheckins(rows as List);
  }

  /// All QR check-ins on a given branch+date (across any sessions that
  /// were opened that day). Used to show admins past attendance even
  /// after the 3-hour window has closed.
  static Future<List<QrCheckin>> checkinsForDay({
    required String branch,
    required DateTime date,
  }) async {
    final dayStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rehearsal = await _c
        .from('rehearsals')
        .select('id')
        .eq('branch', branch)
        .eq('session_date', dayStr)
        .maybeSingle();
    if (rehearsal == null) return const [];
    final rows = await _c
        .from('attendance')
        .select(
          'member_id, late_minutes, checked_in_at, '
          'checked_in_lat, checked_in_lng, '
          'members:member_id(name)',
        )
        .eq('rehearsal_id', rehearsal['id'] as String)
        .eq('via', 'qr')
        .order('checked_in_at', ascending: false);
    return _mapCheckins(rows as List);
  }

  /// The latest QR session (active OR expired) for that branch+date,
  /// or null if no session was ever opened.
  static Future<QrSession?> latestSession({
    required String branch,
    required DateTime date,
  }) async {
    final dayStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rehearsal = await _c
        .from('rehearsals')
        .select('id')
        .eq('branch', branch)
        .eq('session_date', dayStr)
        .maybeSingle();
    if (rehearsal == null) return null;
    final rows = await _c
        .from('qr_sessions')
        .select()
        .eq('rehearsal_id', rehearsal['id'] as String)
        .order('started_at', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return QrSession.fromMap(rows.first);
  }

  /// Update the validity window of an existing session. Pass only
  /// the fields you want to change.
  static Future<QrSession> updateSession({
    required String id,
    DateTime? validFrom,
    DateTime? expiresAt,
    DateTime? lateAfter,
  }) async {
    final patch = <String, dynamic>{};
    if (validFrom != null) {
      patch['valid_from'] = validFrom.toUtc().toIso8601String();
    }
    if (expiresAt != null) {
      patch['expires_at'] = expiresAt.toUtc().toIso8601String();
    }
    if (lateAfter != null) {
      patch['late_after'] = lateAfter.toUtc().toIso8601String();
    }
    if (patch.isEmpty) {
      final row = await _c.from('qr_sessions').select().eq('id', id).single();
      return QrSession.fromMap(row);
    }
    final row = await _c
        .from('qr_sessions')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return QrSession.fromMap(row);
  }

  static Future<void> deleteSession(String id) async {
    await _c.from('qr_sessions').delete().eq('id', id);
  }

  /// Latest QR session for a given concert / big rehearsal.
  static Future<QrSession?> latestSessionForConcert(String concertId) async {
    final rows = await _c
        .from('qr_sessions')
        .select()
        .eq('concert_id', concertId)
        .order('started_at', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return QrSession.fromMap(rows.first);
  }

  /// All QR check-ins for a concert / big rehearsal.
  static Future<List<QrCheckin>> checkinsForConcert(String concertId) async {
    final rows = await _c
        .from('attendance')
        .select(
          'member_id, late_minutes, checked_in_at, '
          'checked_in_lat, checked_in_lng, '
          'members:member_id(name)',
        )
        .eq('concert_id', concertId)
        .eq('via', 'qr')
        .order('checked_in_at', ascending: false);
    return _mapCheckins(rows as List);
  }

  static List<QrCheckin> _mapCheckins(List rows) {
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final memberMap = m['members'] as Map<String, dynamic>?;
      return QrCheckin(
        memberId: m['member_id'] as String,
        memberName: (memberMap?['name'] as String?) ?? 'Unknown',
        checkedInAt: m['checked_in_at'] != null
            ? DateTime.parse(m['checked_in_at'] as String).toLocal()
            : DateTime.now(),
        lateMinutes: (m['late_minutes'] as num?)?.toInt() ?? 0,
        lat: (m['checked_in_lat'] as num?)?.toDouble(),
        lng: (m['checked_in_lng'] as num?)?.toDouble(),
      );
    }).toList();
  }

  /// Used by the admin screen to keep the attendee list live.
  static Stream<List<QrCheckin>> watchCheckins(QrSession session) async* {
    yield await checkins(session);
    // Re-poll every 5s. Could use Supabase realtime channels too.
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        yield await checkins(session);
      } catch (_) {
        // Swallow transient errors — next tick will retry.
      }
    }
  }

  /// Pre-schedules a QR session for a concert/big-rehearsal at the time the
  /// event is created, without auto-attending anyone.  The session stays
  /// pending until [validFrom] arrives.  Safe to call for future dates; skips
  /// silently if the window has already passed or a session already exists.
  static Future<void> preScheduleForConcert({
    required String concertId,
    required DateTime validFrom,
    required DateTime expiresAt,
    DateTime? lateAfter,
  }) async {
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return; // past event — skip

    // Reuse if a non-expired session already exists for this concert.
    final existing = await _c
        .from('qr_sessions')
        .select('id')
        .eq('concert_id', concertId)
        .gt('expires_at', now.toUtc().toIso8601String())
        .limit(1);
    if ((existing as List).isNotEmpty) return;

    final token = _generateToken();
    await _c.from('qr_sessions').insert({
      'concert_id': concertId,
      'rehearsal_id': null,
      'branch': null,
      'token': token,
      'started_at': now.toUtc().toIso8601String(),
      'valid_from': validFrom.toUtc().toIso8601String(),
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'late_after': (lateAfter ?? validFrom.add(const Duration(minutes: 15)))
          .toUtc()
          .toIso8601String(),
      'created_by': _c.auth.currentUser?.id,
    });
  }

  /// Auto-create a default QR window (5:55 PM – 9:00 PM) for a branch
  /// rehearsal the first time an admin opens the QR screen for that day.
  /// Returns the existing or newly-created session, or null if the default
  /// window has already ended (safe to call on every screen open).
  static Future<QrSession?> ensureDefaultSessionForRehearsal({
    required String branch,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final d = date;
    final defaultStart = DateTime(d.year, d.month, d.day, 17, 55);
    final defaultEnd = DateTime(d.year, d.month, d.day, 21, 0);
    if (defaultEnd.isBefore(now)) return null;

    final dayStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Find or create the rehearsal row.
    final existingRehearsal = await _c
        .from('rehearsals')
        .select('id')
        .eq('branch', branch)
        .eq('session_date', dayStr)
        .maybeSingle();
    String rehearsalId;
    if (existingRehearsal != null) {
      rehearsalId = existingRehearsal['id'] as String;
    } else {
      final row = await _c
          .from('rehearsals')
          .insert({
            'branch': branch,
            'session_date': dayStr,
            'status': 'held',
            'recorded_by': _c.auth.currentUser?.id,
          })
          .select('id')
          .single();
      rehearsalId = row['id'] as String;
    }

    // Reuse if a non-expired session already exists.
    final existing = await _c
        .from('qr_sessions')
        .select()
        .eq('rehearsal_id', rehearsalId)
        .gt('expires_at', now.toUtc().toIso8601String())
        .order('started_at', ascending: false)
        .limit(1);
    if ((existing as List).isNotEmpty) {
      return QrSession.fromMap(existing.first);
    }

    // Create the default session without auto-attending anyone.
    final from = defaultStart.isBefore(now) ? now : defaultStart;
    final lateAfter = defaultStart.add(const Duration(minutes: 15));
    final token = _generateToken();
    final inserted = await _c
        .from('qr_sessions')
        .insert({
          'rehearsal_id': rehearsalId,
          'concert_id': null,
          'branch': branch,
          'token': token,
          'started_at': now.toUtc().toIso8601String(),
          'valid_from': from.toUtc().toIso8601String(),
          'expires_at': defaultEnd.toUtc().toIso8601String(),
          'late_after': lateAfter.toUtc().toIso8601String(),
          'created_by': _c.auth.currentUser?.id,
        })
        .select()
        .single();
    return QrSession.fromMap(inserted);
  }

  static String _generateToken() {
    final r = Random.secure();
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnpqrstuvwxyz';
    return List.generate(24, (_) => charset[r.nextInt(charset.length)]).join();
  }
}
