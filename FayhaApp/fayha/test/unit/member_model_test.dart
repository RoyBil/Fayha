import 'package:flutter_test/flutter_test.dart';
import 'package:fayha/state/app_state.dart';

void main() {
  group('Member.fromMap', () {
    test('parses all basic fields correctly', () {
      final map = _baseMap({
        'id': 'abc-123',
        'name': 'Rima Haddad',
        'email': 'rima@fayha.com',
        'phone': '+96170000000',
        'join_date': '2024-03-15',
        'branch': 'Beirut',
        'voice_section': 'Mezzo-Soprano',
        'role': 'member',
        'status': 'active',
        'photo_url': 'https://cdn.example.com/avatar.jpg',
        'concerts_count': 7,
        'practice_hours': 120.5,
        'travels_count': 2,
        'travel_locations': ['France', 'Italy'],
        'can_upload_gallery': true,
        'share_location': false,
        'is_returning': true,
        'singer_level': 'on_stage',
      });
      final m = Member.fromMap(map);

      expect(m.id, 'abc-123');
      expect(m.name, 'Rima Haddad');
      expect(m.email, 'rima@fayha.com');
      expect(m.phone, '+96170000000');
      expect(m.joinDate, DateTime(2024, 3, 15));
      expect(m.branch, 'Beirut');
      expect(m.voiceSection, 'Mezzo-Soprano');
      expect(m.role, 'member');
      expect(m.state, AccountState.active);
      expect(m.photoUrl, 'https://cdn.example.com/avatar.jpg');
      expect(m.concertsCount, 7);
      expect(m.practiceHours, 120.5);
      expect(m.travelsCount, 2);
      expect(m.travelLocations, ['France', 'Italy']);
      expect(m.canUploadGallery, true);
      expect(m.shareLocation, false);
      expect(m.isReturning, true);
      expect(m.singerLevel, 'on_stage');
      expect(m.isAdmin, false);
      expect(m.isMaestro, false);
      expect(m.leftChoir, false);
    });

    group('role mapping', () {
      test('member role gives no elevated permissions', () {
        final m = Member.fromMap(_baseMap({'role': 'member'}));
        expect(m.isAdmin, false);
        expect(m.isMaestro, false);
        expect(m.isEditor, false);
        expect(m.isPollCreator, false);
        expect(m.isContentEditor, false);
      });

      test(
        'admin role gives admin + pollCreator but not maestro or editor',
        () {
          final m = Member.fromMap(_baseMap({'role': 'admin'}));
          expect(m.isAdmin, true);
          expect(m.isMaestro, false);
          expect(m.isEditor, false);
          expect(m.isPollCreator, true);
          expect(m.isContentEditor, false);
        },
      );

      test('superAdmin role gives all elevated permissions', () {
        final m = Member.fromMap(_baseMap({'role': 'superAdmin'}));
        expect(m.isAdmin, true);
        expect(m.isMaestro, true);
        expect(m.isEditor, false);
        expect(m.isPollCreator, true);
        expect(m.isContentEditor, true);
      });

      test('editor role gives editor + contentEditor + pollCreator', () {
        final m = Member.fromMap(_baseMap({'role': 'editor'}));
        expect(m.isAdmin, false);
        expect(m.isMaestro, false);
        expect(m.isEditor, true);
        expect(m.isPollCreator, true);
        expect(m.isContentEditor, true);
      });
    });

    group('status → AccountState mapping', () {
      test('status=active → AccountState.active, leftChoir=false', () {
        final m = Member.fromMap(_baseMap({'status': 'active'}));
        expect(m.state, AccountState.active);
        expect(m.leftChoir, false);
      });

      test('status=deactivated → AccountState.deactivated', () {
        final m = Member.fromMap(_baseMap({'status': 'deactivated'}));
        expect(m.state, AccountState.deactivated);
        expect(m.leftChoir, false);
      });

      test('status=left → AccountState.deleted, leftChoir=true', () {
        final m = Member.fromMap(_baseMap({'status': 'left'}));
        expect(m.state, AccountState.deleted);
        expect(m.leftChoir, true);
      });

      test('status=pending → AccountState.pending', () {
        final m = Member.fromMap(_baseMap({'status': 'pending'}));
        expect(m.state, AccountState.pending);
        expect(m.leftChoir, false);
      });

      test('unknown status falls back to AccountState.pending', () {
        final m = Member.fromMap(_baseMap({'status': 'unknown_value'}));
        expect(m.state, AccountState.pending);
      });
    });

    group('null / missing field defaults', () {
      test('null name defaults to "Member"', () {
        final m = Member.fromMap({'id': 'x', 'name': null});
        expect(m.name, 'Member');
      });

      test('null email defaults to empty string', () {
        final m = Member.fromMap({'id': 'x', 'email': null});
        expect(m.email, '');
      });

      test('null branch defaults to Tripoli', () {
        final m = Member.fromMap({'id': 'x', 'branch': null});
        expect(m.branch, 'Tripoli');
      });

      test('null voice_section defaults to Soprano', () {
        final m = Member.fromMap({'id': 'x', 'voice_section': null});
        expect(m.voiceSection, 'Soprano');
      });

      test('null concerts_count defaults to 0', () {
        final m = Member.fromMap({'id': 'x', 'concerts_count': null});
        expect(m.concertsCount, 0);
      });

      test('null travel_locations defaults to empty list', () {
        final m = Member.fromMap({'id': 'x', 'travel_locations': null});
        expect(m.travelLocations, isEmpty);
      });

      test('null clothing defaults to empty list', () {
        final m = Member.fromMap({'id': 'x', 'clothing': null});
        expect(m.clothing, isEmpty);
      });

      test('null share_location defaults to true', () {
        final m = Member.fromMap({'id': 'x', 'share_location': null});
        expect(m.shareLocation, true);
      });

      test('null can_upload_gallery defaults to false', () {
        final m = Member.fromMap({'id': 'x', 'can_upload_gallery': null});
        expect(m.canUploadGallery, false);
      });

      test('null join_date uses current date (does not throw)', () {
        expect(
          () => Member.fromMap({'id': 'x', 'join_date': null}),
          returnsNormally,
        );
      });
    });

    group('clothing parsing', () {
      test('parses multiple clothing items', () {
        final m = Member.fromMap(
          _baseMap({
            'clothing': [
              {'type': 'dress', 'size': 'S', 'quantity': 1},
              {'type': 'shoes', 'size': '38', 'quantity': 2},
            ],
          }),
        );
        expect(m.clothing.length, 2);
        expect(m.clothing[0].type, 'dress');
        expect(m.clothing[0].size, 'S');
        expect(m.clothing[0].quantity, 1);
        expect(m.clothing[1].type, 'shoes');
        expect(m.clothing[1].size, '38');
        expect(m.clothing[1].quantity, 2);
      });

      test('clothing item null fields default safely', () {
        final m = Member.fromMap(
          _baseMap({
            'clothing': [
              {'type': null, 'size': null, 'quantity': null},
            ],
          }),
        );
        expect(m.clothing.length, 1);
        expect(m.clothing[0].type, '');
        expect(m.clothing[0].size, '');
        expect(m.clothing[0].quantity, 1);
      });
    });

    group('break dates', () {
      test('parses break_from and break_to', () {
        final m = Member.fromMap(
          _baseMap({'break_from': '2025-07-01', 'break_to': '2025-09-30'}),
        );
        expect(m.breakFrom, DateTime(2025, 7, 1));
        expect(m.breakTo, DateTime(2025, 9, 30));
      });

      test('null break dates remain null', () {
        final m = Member.fromMap(
          _baseMap({'break_from': null, 'break_to': null}),
        );
        expect(m.breakFrom, isNull);
        expect(m.breakTo, isNull);
      });
    });

    group('house location', () {
      test('parses house_lat, house_lng, house_address', () {
        final m = Member.fromMap(
          _baseMap({
            'house_lat': 33.8935,
            'house_lng': 35.5018,
            'house_address': '12 Hamra St, Beirut',
          }),
        );
        expect(m.houseLat, closeTo(33.8935, 0.0001));
        expect(m.houseLng, closeTo(35.5018, 0.0001));
        expect(m.houseAddress, '12 Hamra St, Beirut');
      });

      test('null house fields remain null', () {
        final m = Member.fromMap(
          _baseMap({'house_lat': null, 'house_lng': null}),
        );
        expect(m.houseLat, isNull);
        expect(m.houseLng, isNull);
      });

      test('integer house_lat is cast to double', () {
        // Supabase might return 34 instead of 34.0
        final m = Member.fromMap(_baseMap({'house_lat': 34, 'house_lng': 35}));
        expect(m.houseLat, 34.0);
        expect(m.houseLat, isA<double>());
      });
    });

    group('singer_level', () {
      for (final level in [
        'not_on_stage',
        'on_stage',
        'assistant_conductor',
        'friend',
      ]) {
        test('parses $level', () {
          final m = Member.fromMap(_baseMap({'singer_level': level}));
          expect(m.singerLevel, level);
        });
      }

      test('null singer_level stays null', () {
        final m = Member.fromMap(_baseMap({'singer_level': null}));
        expect(m.singerLevel, isNull);
      });
    });
  });
}

// Builds a minimal valid map, merged with [overrides].
Map<String, dynamic> _baseMap([Map<String, dynamic>? overrides]) {
  final base = <String, dynamic>{
    'id': 'base-id',
    'name': 'Base Member',
    'email': 'base@fayha.com',
    'phone': '+961000000',
    'join_date': '2023-01-01',
    'branch': 'Tripoli',
    'voice_section': 'Alto',
    'role': 'member',
    'status': 'active',
    'clothing': <dynamic>[],
  };
  if (overrides != null) base.addAll(overrides);
  return base;
}
