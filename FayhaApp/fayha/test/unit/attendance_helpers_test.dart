import 'package:flutter_test/flutter_test.dart';
import 'package:fayha/services/attendance_service.dart';

void main() {
  group('AttendanceService — branch rehearsal days', () {
    // Weekday encoding: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7

    test('Tripoli rehearses on Thursday(4), Friday(5), Saturday(6)', () {
      expect(AttendanceService.daysFor('Tripoli'), [4, 5, 6]);
    });

    test('Beirut rehearses on Monday(1), Tuesday(2), Wednesday(3)', () {
      expect(AttendanceService.daysFor('Beirut'), [1, 2, 3]);
    });

    test('Chouf rehearses on Monday(1), Tuesday(2), Wednesday(3)', () {
      expect(AttendanceService.daysFor('Chouf'), [1, 2, 3]);
    });

    test('Aley rehearses on Wednesday(3), Thursday(4), Friday(5)', () {
      expect(AttendanceService.daysFor('Aley'), [3, 4, 5]);
    });

    test('unknown branch returns the safe default [6]', () {
      expect(AttendanceService.daysFor('UnknownCity'), [6]);
      expect(AttendanceService.daysFor(''), [6]);
    });

    test('every known branch has exactly 3 rehearsal days', () {
      for (final branch in ['Tripoli', 'Beirut', 'Chouf', 'Aley']) {
        expect(
          AttendanceService.daysFor(branch).length,
          3,
          reason: '$branch should have 3 rehearsal days',
        );
      }
    });

    test('rehearsal days are valid weekday values (1–7)', () {
      for (final branch in ['Tripoli', 'Beirut', 'Chouf', 'Aley']) {
        for (final day in AttendanceService.daysFor(branch)) {
          expect(day, greaterThanOrEqualTo(1), reason: '$branch day $day');
          expect(day, lessThanOrEqualTo(7), reason: '$branch day $day');
        }
      }
    });
  });

  group('SessionInfo', () {
    test('recorded=true when status is "held"', () {
      final s = SessionInfo(DateTime(2025, 6, 1), 'held', DateTime.now());
      expect(s.recorded, true);
      expect(s.cancelled, false);
    });

    test('recorded=true when status is "cancelled"', () {
      final s = SessionInfo(DateTime(2025, 6, 1), 'cancelled', DateTime.now());
      expect(s.recorded, true);
      expect(s.cancelled, true);
    });

    test('recorded=false and cancelled=false when status is null', () {
      final s = SessionInfo(DateTime(2025, 6, 1), null, null);
      expect(s.recorded, false);
      expect(s.cancelled, false);
    });

    test('cancelled is false for status="held"', () {
      final s = SessionInfo(DateTime(2025, 6, 2), 'held', DateTime.now());
      expect(s.cancelled, false);
    });

    test('stores the date correctly', () {
      final date = DateTime(2025, 10, 15);
      final s = SessionInfo(date, 'held', DateTime.now());
      expect(s.date, date);
    });
  });

  group('HistoryItem', () {
    test('lateMinutes defaults to 0', () {
      final item = HistoryItem(
        kind: 'rehearsal',
        title: 'Rehearsal · Tripoli',
        subtitle: AttendanceService.sessionTime,
        date: DateTime(2025, 5, 1),
      );
      expect(item.lateMinutes, 0);
    });

    test('custom lateMinutes is stored', () {
      final item = HistoryItem(
        kind: 'rehearsal',
        title: 'Rehearsal · Tripoli',
        subtitle: '5:55 – 9:00 PM · Late 20 min',
        date: DateTime(2025, 5, 2),
        lateMinutes: 20,
      );
      expect(item.lateMinutes, 20);
    });

    test('kind is preserved correctly for each type', () {
      for (final kind in ['rehearsal', 'concert', 'big_rehearsal']) {
        final item = HistoryItem(
          kind: kind,
          title: 'Test',
          subtitle: '',
          date: DateTime(2025, 1, 1),
        );
        expect(item.kind, kind);
      }
    });

    test('sessionTime constant has expected format', () {
      expect(AttendanceService.sessionTime, '5:55 – 9:00 PM');
    });
  });
}
