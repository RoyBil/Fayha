import 'package:flutter_test/flutter_test.dart';
import 'package:fayha/state/app_state.dart';

void main() {
  // AppState is a singleton; reset to clean state before every test.
  setUp(() => AppState.instance.signOut());

  group('AppState — initial state', () {
    test('not signed in', () {
      expect(AppState.instance.isSignedIn, false);
    });

    test('currentMember is null', () {
      expect(AppState.instance.currentMember, isNull);
    });

    test('role flags are all false', () {
      expect(AppState.instance.isAdmin, false);
      expect(AppState.instance.isMaestro, false);
      expect(AppState.instance.isEditor, false);
      expect(AppState.instance.isContentEditor, false);
    });
  });

  group('AppState — signIn / signOut', () {
    test('signIn marks isSignedIn and exposes member', () {
      final m = _member();
      AppState.instance.signIn(m);
      expect(AppState.instance.isSignedIn, true);
      expect(AppState.instance.currentMember, m);
    });

    test('signOut clears member', () {
      AppState.instance.signIn(_member());
      AppState.instance.signOut();
      expect(AppState.instance.isSignedIn, false);
      expect(AppState.instance.currentMember, isNull);
    });

    test('signIn notifies listeners', () {
      var called = false;
      AppState.instance.addListener(() => called = true);
      AppState.instance.signIn(_member());
      expect(called, true);
      AppState.instance.removeListener(() {});
    });

    test('signOut notifies listeners', () {
      AppState.instance.signIn(_member());
      var called = false;
      AppState.instance.addListener(() => called = true);
      AppState.instance.signOut();
      expect(called, true);
      AppState.instance.removeListener(() {});
    });
  });

  group('AppState — signInAsDemo', () {
    test('sets a non-null member', () {
      AppState.instance.signInAsDemo();
      expect(AppState.instance.currentMember, isNotNull);
      expect(AppState.instance.isSignedIn, true);
    });

    test('asMaestro=true gives maestro + admin permissions', () {
      AppState.instance.signInAsDemo(asMaestro: true);
      expect(AppState.instance.isMaestro, true);
      expect(AppState.instance.isAdmin, true);
    });

    test('asMaestro=false gives a regular demo member', () {
      AppState.instance.signInAsDemo(asMaestro: false);
      expect(AppState.instance.isMaestro, false);
    });
  });

  group('AppState — role computed properties', () {
    test('isAdmin true for admin role', () {
      AppState.instance.signIn(_member(role: 'admin'));
      expect(AppState.instance.isAdmin, true);
      expect(AppState.instance.isMaestro, false);
    });

    test('isAdmin true for superAdmin role', () {
      AppState.instance.signIn(_member(role: 'superAdmin'));
      expect(AppState.instance.isAdmin, true);
      expect(AppState.instance.isMaestro, true);
    });

    test('isEditor true for editor role', () {
      AppState.instance.signIn(_member(role: 'editor'));
      expect(AppState.instance.isEditor, true);
      expect(AppState.instance.isContentEditor, true);
    });

    test('isContentEditor true for superAdmin', () {
      AppState.instance.signIn(_member(role: 'superAdmin'));
      expect(AppState.instance.isContentEditor, true);
    });

    test('isContentEditor false for plain admin', () {
      AppState.instance.signIn(_member(role: 'admin'));
      expect(AppState.instance.isContentEditor, false);
    });
  });

  group('AppState — updateProfile', () {
    test('updates name and phone', () {
      AppState.instance.signIn(_member());
      AppState.instance.updateProfile(name: 'New Name', phone: '+9611111111');
      expect(AppState.instance.currentMember?.name, 'New Name');
      expect(AppState.instance.currentMember?.phone, '+9611111111');
    });

    test('updates photoUrl', () {
      AppState.instance.signIn(_member());
      AppState.instance.updateProfile(
        photoUrl: 'https://cdn.example.com/x.jpg',
      );
      expect(
        AppState.instance.currentMember?.photoUrl,
        'https://cdn.example.com/x.jpg',
      );
    });

    test('updates house location fields', () {
      AppState.instance.signIn(_member());
      AppState.instance.updateProfile(
        houseLat: 33.9,
        houseLng: 35.5,
        houseAddress: '1 Main St',
      );
      expect(AppState.instance.currentMember?.houseLat, 33.9);
      expect(AppState.instance.currentMember?.houseLng, 35.5);
      expect(AppState.instance.currentMember?.houseAddress, '1 Main St');
    });

    test('updates concertsCount, practiceHours, travelsCount', () {
      AppState.instance.signIn(_member());
      AppState.instance.updateProfile(
        concertsCount: 10,
        practiceHours: 200.0,
        travelsCount: 5,
      );
      expect(AppState.instance.currentMember?.concertsCount, 10);
      expect(AppState.instance.currentMember?.practiceHours, 200.0);
      expect(AppState.instance.currentMember?.travelsCount, 5);
    });

    test('updates singerLevel to null when empty string is passed', () {
      AppState.instance.signIn(_member());
      AppState.instance.updateProfile(singerLevel: 'on_stage');
      expect(AppState.instance.currentMember?.singerLevel, 'on_stage');
      // Empty string is treated as "clear the level"
      AppState.instance.updateProfile(singerLevel: '');
      expect(AppState.instance.currentMember?.singerLevel, isNull);
    });

    test('is no-op when not signed in', () {
      // Must not throw
      expect(
        () => AppState.instance.updateProfile(name: 'Ghost'),
        returnsNormally,
      );
    });

    test('notifies listeners on update', () {
      AppState.instance.signIn(_member());
      var called = false;
      AppState.instance.addListener(() => called = true);
      AppState.instance.updateProfile(name: 'Updated');
      expect(called, true);
      AppState.instance.removeListener(() {});
    });
  });

  group('AppState — memorized songs', () {
    test('toggleMemorized adds a new song id', () {
      AppState.instance.signIn(_member());
      AppState.instance.toggleMemorized('song-abc');
      expect(
        AppState.instance.currentMember?.memorizedSongIds.contains('song-abc'),
        true,
      );
    });

    test('toggleMemorized removes an already-present song id', () {
      AppState.instance.signIn(_member(memorizedSongIds: {'song-1', 'song-2'}));
      AppState.instance.toggleMemorized('song-1');
      expect(
        AppState.instance.currentMember?.memorizedSongIds.contains('song-1'),
        false,
      );
      expect(
        AppState.instance.currentMember?.memorizedSongIds.contains('song-2'),
        true,
      );
    });

    test('toggleMemorized is no-op when not signed in', () {
      expect(
        () => AppState.instance.toggleMemorized('song-x'),
        returnsNormally,
      );
    });
  });

  group('AppState — favorite songs', () {
    test('setFavorite persists the song id', () {
      AppState.instance.signIn(_member());
      AppState.instance.setFavorite('song-fav');
      expect(AppState.instance.currentMember?.favoriteSongId, 'song-fav');
    });

    test('setFavorite to null clears it', () {
      AppState.instance.signIn(_member());
      AppState.instance.setFavorite('song-fav');
      AppState.instance.setFavorite(null);
      expect(AppState.instance.currentMember?.favoriteSongId, isNull);
    });

    test('setLeastFavorite persists the song id', () {
      AppState.instance.signIn(_member());
      AppState.instance.setLeastFavorite('song-least');
      expect(
        AppState.instance.currentMember?.leastFavoriteSongId,
        'song-least',
      );
    });
  });

  group('AppState — location sharing', () {
    test('setLocationSharing toggles the flag', () {
      AppState.instance.signIn(_member());
      AppState.instance.setLocationSharing(false);
      expect(AppState.instance.currentMember?.shareLocation, false);
      AppState.instance.setLocationSharing(true);
      expect(AppState.instance.currentMember?.shareLocation, true);
    });
  });

  group('AppState — stats versioning', () {
    test('bumpStats increments statsVersion by 1', () {
      final before = AppState.instance.statsVersion;
      AppState.instance.bumpStats();
      expect(AppState.instance.statsVersion, before + 1);
    });

    test('bumpStats notifies listeners', () {
      var called = false;
      AppState.instance.addListener(() => called = true);
      AppState.instance.bumpStats();
      expect(called, true);
      AppState.instance.removeListener(() {});
    });

    test('three consecutive bumps increment by 3', () {
      final before = AppState.instance.statsVersion;
      AppState.instance.bumpStats();
      AppState.instance.bumpStats();
      AppState.instance.bumpStats();
      expect(AppState.instance.statsVersion, before + 3);
    });
  });
}

Member _member({String role = 'member', Set<String>? memorizedSongIds}) =>
    Member(
      id: 'test-id',
      name: 'Test Member',
      email: 'test@fayha.com',
      phone: '+96100000000',
      joinDate: DateTime(2023, 1, 1),
      branch: 'Tripoli',
      voiceSection: 'Soprano',
      role: role,
      isAdmin: role == 'admin' || role == 'superAdmin',
      isMaestro: role == 'superAdmin',
      isEditor: role == 'editor',
      isPollCreator: ['admin', 'editor', 'superAdmin'].contains(role),
      memorizedSongIds: memorizedSongIds,
    );
