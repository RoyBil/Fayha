import 'package:flutter/foundation.dart';
import '../data/mock_data.dart';

enum AccountState { active, deactivated, deleted, pending }

class Member {
  String id;
  String name;
  String email;
  String phone;
  final DateTime joinDate;
  String branch;
  String voiceSection;
  String role; // member | admin | superAdmin
  String? photoUrl;
  AccountState state;
  bool isAdmin;
  bool isMaestro;
  bool isEditor;
  bool isPollCreator;
  bool canUploadGallery;

  /// Anyone who is allowed to post news / events / announcements.
  bool get isContentEditor => isEditor || isMaestro;
  bool leftChoir;
  bool shareLocation;
  Set<String> memorizedSongIds;
  String? favoriteSongId;
  String? leastFavoriteSongId;
  int concertsCount;
  num practiceHours;
  int travelsCount;
  List<String> travelLocations;
  bool isReturning;
  DateTime? breakFrom;
  DateTime? breakTo;
  List<ClothingItem> clothing;
  double? houseLat;
  double? houseLng;
  String? houseAddress;
  bool liveLocationEnabled;

  /// 'not_on_stage' | 'on_stage' | 'assistant_conductor' | 'friend' | null
  String? singerLevel;

  Member({
    this.id = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.joinDate,
    required this.branch,
    required this.voiceSection,
    this.role = 'member',
    this.photoUrl,
    this.state = AccountState.active,
    this.isAdmin = false,
    this.isMaestro = false,
    this.isEditor = false,
    this.isPollCreator = false,
    this.canUploadGallery = false,
    this.leftChoir = false,
    this.shareLocation = true,
    Set<String>? memorizedSongIds,
    this.favoriteSongId,
    this.leastFavoriteSongId,
    this.concertsCount = 0,
    this.practiceHours = 0,
    this.travelsCount = 0,
    List<String>? travelLocations,
    this.isReturning = false,
    this.breakFrom,
    this.breakTo,
    List<ClothingItem>? clothing,
    this.houseLat,
    this.houseLng,
    this.houseAddress,
    this.liveLocationEnabled = false,
    this.singerLevel,
  }) : memorizedSongIds = memorizedSongIds ?? <String>{},
       travelLocations = travelLocations ?? <String>[],
       clothing = clothing ?? <ClothingItem>[];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'join_date': joinDate.toIso8601String().split('T').first,
    'branch': branch,
    'voice_section': voiceSection,
    'role': role,
    'photo_url': photoUrl,
    'status': switch (state) {
      AccountState.active => 'active',
      AccountState.deactivated => 'deactivated',
      AccountState.deleted => 'left',
      AccountState.pending => 'pending',
    },
    'can_upload_gallery': canUploadGallery,
    'share_location': shareLocation,
    'favorite_song_id': favoriteSongId,
    'least_favorite_song_id': leastFavoriteSongId,
    'concerts_count': concertsCount,
    'practice_hours': practiceHours,
    'travels_count': travelsCount,
    'travel_locations': travelLocations,
    'clothing': clothing
        .map((c) => {'type': c.type, 'size': c.size, 'quantity': c.quantity})
        .toList(),
    'is_returning': isReturning,
    'break_from': breakFrom?.toIso8601String().split('T').first,
    'break_to': breakTo?.toIso8601String().split('T').first,
    'house_lat': houseLat,
    'house_lng': houseLng,
    'house_address': houseAddress,
    'live_location_enabled': liveLocationEnabled,
    'singer_level': singerLevel,
  };

  factory Member.fromMap(Map<String, dynamic> r) {
    final role = (r['role'] as String?) ?? 'member';
    final status = (r['status'] as String?) ?? 'pending';
    return Member(
      id: r['id'] as String,
      name: (r['name'] as String?) ?? 'Member',
      email: (r['email'] as String?) ?? '',
      phone: (r['phone'] as String?) ?? '',
      joinDate: r['join_date'] != null
          ? DateTime.parse(r['join_date'] as String)
          : DateTime.now(),
      branch: (r['branch'] as String?) ?? 'Tripoli',
      voiceSection: (r['voice_section'] as String?) ?? 'Soprano',
      role: role,
      photoUrl: r['photo_url'] as String?,
      state: switch (status) {
        'active' => AccountState.active,
        'deactivated' => AccountState.deactivated,
        'left' => AccountState.deleted,
        _ => AccountState.pending,
      },
      isAdmin: role == 'admin' || role == 'superAdmin',
      isMaestro: role == 'superAdmin',
      isEditor: role == 'editor',
      isPollCreator:
          role == 'admin' || role == 'editor' || role == 'superAdmin',
      canUploadGallery: (r['can_upload_gallery'] as bool?) ?? false,
      leftChoir: status == 'left',
      shareLocation: (r['share_location'] as bool?) ?? true,
      favoriteSongId: r['favorite_song_id'] as String?,
      leastFavoriteSongId: r['least_favorite_song_id'] as String?,
      concertsCount: (r['concerts_count'] as int?) ?? 0,
      practiceHours: (r['practice_hours'] as num?) ?? 0,
      travelsCount: (r['travels_count'] as int?) ?? 0,
      travelLocations:
          (r['travel_locations'] as List?)?.cast<String>() ?? <String>[],
      clothing: ((r['clothing'] as List?) ?? [])
          .map(
            (c) => ClothingItem(
              type: (c['type'] as String?) ?? '',
              size: (c['size'] as String?) ?? '',
              quantity: (c['quantity'] as int?) ?? 1,
            ),
          )
          .toList(),
      isReturning: (r['is_returning'] as bool?) ?? false,
      breakFrom: r['break_from'] != null
          ? DateTime.parse(r['break_from'] as String)
          : null,
      breakTo: r['break_to'] != null
          ? DateTime.parse(r['break_to'] as String)
          : null,
      houseLat: (r['house_lat'] as num?)?.toDouble(),
      houseLng: (r['house_lng'] as num?)?.toDouble(),
      houseAddress: r['house_address'] as String?,
      liveLocationEnabled: (r['live_location_enabled'] as bool?) ?? false,
      singerLevel: r['singer_level'] as String?,
    );
  }
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._();
  AppState._();

  Member? _currentMember;
  Member? get currentMember => _currentMember;
  bool get isSignedIn => _currentMember != null;
  bool get isMaestro => _currentMember?.isMaestro ?? false;
  bool get isAdmin => _currentMember?.isAdmin ?? false;
  bool get isEditor => _currentMember?.isEditor ?? false;
  bool get isContentEditor => _currentMember?.isContentEditor ?? false;

  /// Bumped whenever something happens that should invalidate the
  /// home-page stat boxes (e.g. attendance was just recorded).
  /// Screens that show stats listen to AppState and refetch when this
  /// integer changes.
  int _statsVersion = 0;
  int get statsVersion => _statsVersion;

  /// Mark stats as dirty — anyone showing them should refetch.
  void bumpStats() {
    _statsVersion++;
    notifyListeners();
  }

  void signIn(Member m) {
    _currentMember = m;
    notifyListeners();
  }

  void signInAsDemo({bool asMaestro = false}) {
    _currentMember = MockData.demoMember(asMaestro: asMaestro);
    notifyListeners();
  }

  void signOut() {
    _currentMember = null;
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    double? houseLat,
    double? houseLng,
    String? houseAddress,
    int? concertsCount,
    num? practiceHours,
    int? travelsCount,
    List<String>? travelLocations,
    String? singerLevel,
  }) {
    if (_currentMember == null) return;
    if (name != null) _currentMember!.name = name;
    if (email != null) _currentMember!.email = email;
    if (phone != null) _currentMember!.phone = phone;
    if (photoUrl != null) _currentMember!.photoUrl = photoUrl;
    if (houseLat != null) _currentMember!.houseLat = houseLat;
    if (houseLng != null) _currentMember!.houseLng = houseLng;
    if (houseAddress != null) _currentMember!.houseAddress = houseAddress;
    if (concertsCount != null) _currentMember!.concertsCount = concertsCount;
    if (practiceHours != null) _currentMember!.practiceHours = practiceHours;
    if (travelsCount != null) _currentMember!.travelsCount = travelsCount;
    if (travelLocations != null) {
      _currentMember!.travelLocations = travelLocations;
    }
    if (singerLevel != null) {
      _currentMember!.singerLevel = singerLevel.isEmpty ? null : singerLevel;
    }
    notifyListeners();
  }

  void toggleMemorized(String songId) {
    if (_currentMember == null) return;
    if (_currentMember!.memorizedSongIds.contains(songId)) {
      _currentMember!.memorizedSongIds.remove(songId);
    } else {
      _currentMember!.memorizedSongIds.add(songId);
    }
    notifyListeners();
  }

  void setFavorite(String? songId) {
    _currentMember?.favoriteSongId = songId;
    notifyListeners();
  }

  void setLeastFavorite(String? songId) {
    _currentMember?.leastFavoriteSongId = songId;
    notifyListeners();
  }

  void setLocationSharing(bool value) {
    _currentMember?.shareLocation = value;
    notifyListeners();
  }
}
