import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'live_location_service.dart';
import 'member_songs_service.dart';

class AuthService {
  static final _c = Supabase.instance.client;

  /// Creates the auth account. A database trigger creates the matching
  /// `members` row (status = pending, unless Maestro's email).
  static Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String branch,
    required String voiceSection,
    DateTime? joinDate,
    int concertsCount = 0,
    num practiceHours = 0,
    int travelsCount = 0,
    List<String> travelLocations = const [],
    bool isReturning = false,
    DateTime? breakFrom,
    DateTime? breakTo,
    List<Map<String, dynamic>> clothing = const [],
    String? singerLevel,
  }) async {
    String d(DateTime x) => x.toIso8601String().split('T').first;
    await _c.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'phone': phone,
        'branch': branch,
        'voice_section': voiceSection,
        if (joinDate != null) 'join_date': d(joinDate),
        'concerts_count': concertsCount,
        'practice_hours': practiceHours,
        'travels_count': travelsCount,
        'travel_locations': travelLocations,
        'is_returning': isReturning,
        if (breakFrom != null) 'break_from': d(breakFrom),
        if (breakTo != null) 'break_to': d(breakTo),
        'clothing': clothing,
        if (singerLevel != null) 'singer_level': singerLevel,
      },
    );
  }

  static Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    LiveLocationService.instance.stopTimer();
    await _c.auth.signOut();
    AppState.instance.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await _c.auth.resetPasswordForEmail(email);
  }

  static bool get hasSession => _c.auth.currentSession != null;

  static String? get currentUserId => _c.auth.currentUser?.id;

  /// Loads the signed-in user's member profile from the `members` table.
  static Future<Member?> loadCurrentMember() async {
    final user = _c.auth.currentUser;
    if (user == null) return null;
    final row =
        await _c.from('members').select().eq('id', user.id).maybeSingle();
    if (row == null) return null;
    final m = Member.fromMap(row);
    try {
      m.memorizedSongIds = await MemberSongsService.fetchForMember(user.id);
    } catch (_) {
      // ignore — member_songs table may not exist yet
    }
    return m;
  }

  /// Persists editable profile fields back to Supabase.
  static Future<void> updateProfile({
    required String id,
    String? name,
    String? phone,
    bool? shareLocation,
    String? favoriteSongId,
    String? leastFavoriteSongId,
    String? photoUrl,
    double? houseLat,
    double? houseLng,
    String? houseAddress,
    int? concertsCount,
    num? practiceHours,
    int? travelsCount,
    List<String>? travelLocations,
    String? singerLevel,
  }) async {
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (phone != null) patch['phone'] = phone;
    if (shareLocation != null) patch['share_location'] = shareLocation;
    if (favoriteSongId != null) patch['favorite_song_id'] = favoriteSongId;
    if (leastFavoriteSongId != null) {
      patch['least_favorite_song_id'] = leastFavoriteSongId;
    }
    if (photoUrl != null) patch['photo_url'] = photoUrl;
    if (houseLat != null) patch['house_lat'] = houseLat;
    if (houseLng != null) patch['house_lng'] = houseLng;
    if (houseAddress != null) patch['house_address'] = houseAddress;
    if (concertsCount != null) patch['concerts_count'] = concertsCount;
    if (practiceHours != null) patch['practice_hours'] = practiceHours;
    if (travelsCount != null) patch['travels_count'] = travelsCount;
    if (travelLocations != null) patch['travel_locations'] = travelLocations;
    if (singerLevel != null) {
      patch['singer_level'] = singerLevel.isEmpty ? null : singerLevel;
    }
    if (patch.isEmpty) return;
    await _c.from('members').update(patch).eq('id', id);
  }

  /// Uploads avatar bytes to the `avatars` Storage bucket and returns a
  /// public URL. Also saves the URL onto the member's `photo_url`.
  static Future<String> uploadAvatar({
    required String memberId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.isEmpty ? 'jpg' : fileExtension;
    final path = '$memberId/avatar.$ext';
    await _c.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final base = _c.storage.from('avatars').getPublicUrl(path);
    final url = '$base?t=${DateTime.now().millisecondsSinceEpoch}';
    await updateProfile(id: memberId, photoUrl: url);
    return url;
  }
}
