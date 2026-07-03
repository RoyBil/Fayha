import 'package:flutter_test/flutter_test.dart';
import 'package:fayha/services/qr_attendance_service.dart';

void main() {
  group('QrSession.fromMap', () {
    test('parses all fields including optional ones', () {
      final now = DateTime.now().toUtc();
      final map = {
        'id': 'qs-001',
        'rehearsal_id': 'reh-42',
        'concert_id': null,
        'branch': 'Tripoli',
        'token': 'ABCDEFGHIJ123456KLMN0123',
        'started_at': now.toIso8601String(),
        'valid_from': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 3)).toIso8601String(),
        'late_after': now.add(const Duration(minutes: 15)).toIso8601String(),
      };

      final s = QrSession.fromMap(map);

      expect(s.id, 'qs-001');
      expect(s.rehearsalId, 'reh-42');
      expect(s.concertId, isNull);
      expect(s.branch, 'Tripoli');
      expect(s.token, 'ABCDEFGHIJ123456KLMN0123');
      expect(s.lateAfter, isNotNull);
    });

    test('null late_after stays null', () {
      final now = DateTime.now().toUtc();
      final s = QrSession.fromMap({
        'id': 'qs-002',
        'token': 'XYZ',
        'started_at': now.toIso8601String(),
        'valid_from': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
        'late_after': null,
      });
      expect(s.lateAfter, isNull);
    });

    test('null valid_from falls back to started_at', () {
      final now = DateTime.now().toUtc();
      final s = QrSession.fromMap({
        'id': 'qs-003',
        'token': 'XYZ',
        'started_at': now.toIso8601String(),
        'valid_from': null,
        'expires_at': now.add(const Duration(hours: 2)).toIso8601String(),
        'late_after': null,
      });
      expect(
        s.validFrom.difference(s.startedAt).abs(),
        lessThan(const Duration(seconds: 1)),
      );
    });

    test('concert_id is parsed for concert sessions', () {
      final now = DateTime.now().toUtc();
      final s = QrSession.fromMap({
        'id': 'qs-004',
        'rehearsal_id': null,
        'concert_id': 'concert-99',
        'branch': null,
        'token': 'TOKCC',
        'started_at': now.toIso8601String(),
        'valid_from': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 4)).toIso8601String(),
        'late_after': null,
      });
      expect(s.concertId, 'concert-99');
      expect(s.rehearsalId, isNull);
      expect(s.branch, isNull);
    });

    test('timestamps are converted to local time', () {
      final utcNow = DateTime.now().toUtc();
      final s = QrSession.fromMap({
        'id': 'qs-005',
        'token': 'T',
        'started_at': utcNow.toIso8601String(),
        'valid_from': utcNow.toIso8601String(),
        'expires_at': utcNow.add(const Duration(hours: 1)).toIso8601String(),
        'late_after': null,
      });
      expect(s.startedAt.isUtc, false);
      expect(s.validFrom.isUtc, false);
      expect(s.expiresAt.isUtc, false);
    });
  });

  group('QrSession — computed state properties', () {
    test('isActive when now is between validFrom and expiresAt', () {
      final s = _session(
        validFrom: _ago(minutes: 30),
        expiresAt: _from(hours: 2),
      );
      expect(s.isActive, true);
      expect(s.isExpired, false);
      expect(s.isPending, false);
    });

    test('isExpired when expiresAt is in the past', () {
      final s = _session(validFrom: _ago(hours: 5), expiresAt: _ago(hours: 1));
      expect(s.isExpired, true);
      expect(s.isActive, false);
      expect(s.isPending, false);
    });

    test('isPending when validFrom is in the future', () {
      final s = _session(
        validFrom: _from(hours: 1),
        expiresAt: _from(hours: 4),
      );
      expect(s.isPending, true);
      expect(s.isActive, false);
      expect(s.isExpired, false);
    });

    test('isExpired beats isPending: expired session is never active', () {
      // Edge case: expiresAt in past, validFrom also in past
      final s = _session(
        validFrom: _ago(hours: 2),
        expiresAt: _ago(minutes: 1),
      );
      expect(s.isExpired, true);
      expect(s.isActive, false);
    });
  });

  group('QrSession — remaining duration', () {
    test('positive remaining for a session expiring in 2 hours', () {
      final s = _session(
        validFrom: _ago(minutes: 10),
        expiresAt: _from(hours: 2),
      );
      expect(s.remaining.inMinutes, greaterThan(110));
      expect(s.remaining.inMinutes, lessThanOrEqualTo(120));
    });

    test('negative remaining for an expired session', () {
      final s = _session(validFrom: _ago(hours: 5), expiresAt: _ago(hours: 2));
      expect(s.remaining.isNegative, true);
    });

    test('approximately zero remaining for a just-expired session', () {
      final s = _session(validFrom: _ago(hours: 3), expiresAt: DateTime.now());
      expect(s.remaining.inSeconds.abs(), lessThan(5));
    });
  });
}

// ──────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────

DateTime _ago({int hours = 0, int minutes = 0}) =>
    DateTime.now().subtract(Duration(hours: hours, minutes: minutes));

DateTime _from({int hours = 0, int minutes = 0}) =>
    DateTime.now().add(Duration(hours: hours, minutes: minutes));

QrSession _session({
  required DateTime validFrom,
  required DateTime expiresAt,
}) => QrSession(
  id: 'test-session',
  token: 'TESTTOKEN',
  startedAt: DateTime.now().subtract(const Duration(hours: 1)),
  validFrom: validFrom,
  expiresAt: expiresAt,
);
