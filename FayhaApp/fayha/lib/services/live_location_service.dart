import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

/// One row from the `live_locations` view (Maestro-only).
class LiveMemberLocation {
  final String id;
  final String name;
  final String branch;
  final String voiceSection;
  final String role;
  final String? photoUrl;
  final double lat;
  final double lng;
  final DateTime? at;
  const LiveMemberLocation({
    required this.id,
    required this.name,
    required this.branch,
    required this.voiceSection,
    required this.role,
    this.photoUrl,
    required this.lat,
    required this.lng,
    this.at,
  });
}

/// Singleton that streams the current member's live coordinates to
/// Supabase while the app is open. Uses Geolocator's positionStream
/// so every meaningful movement (5+ meters) is pushed quickly, with a
/// safety heartbeat every 60 seconds when stationary so the Maestro
/// always sees a recent timestamp.
class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  static final _c = Supabase.instance.client;
  // Push a fresh GPS reading every few seconds even when stationary,
  // so the Maestro always sees a recent `live_at` timestamp.
  static const _heartbeat = Duration(seconds: 8);
  // 0 = every GPS sample fires — no distance threshold at all.
  static const _minDistanceMeters = 0;
  // Use the highest accuracy the platform offers (true GPS on phones,
  // navigator.geolocation with enableHighAccuracy on the web).
  static const _accuracy = LocationAccuracy.bestForNavigation;

  StreamSubscription<Position>? _posSub;
  Timer? _heartbeatTimer;
  bool get isRunning => _posSub != null;

  /// Enables live sharing for the current member, then immediately
  /// pushes a position. Throws on permission/service errors.
  Future<void> enable() async {
    final me = AppState.instance.currentMember;
    if (me == null) throw 'Not signed in';

    // Ensure location services + permission.
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are off';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Location permission denied';
    }

    await _c.from('members').update({
      'live_location_enabled': true,
    }).eq('id', me.id);
    me.liveLocationEnabled = true;
    AppState.instance.bumpStats();
    await _pushOnce();
    _start();
  }

  /// Start the position stream + heartbeat. Idempotent.
  void _start() {
    _posSub?.cancel();
    _heartbeatTimer?.cancel();

    // Fast, movement-based updates from the OS.
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: _accuracy,
        distanceFilter: _minDistanceMeters,
      ),
    ).listen((pos) => _push(pos), onError: (_) {});

    // Heartbeat so the Maestro sees a recent `live_at` even when
    // the member is stationary.
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) => _pushOnce());
  }

  /// Stop pushing updates (does NOT disable sharing in the DB).
  void stopTimer() {
    _posSub?.cancel();
    _posSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Disables live sharing for the current member: stops the stream,
  /// flips the DB flag off, and clears the stored coordinates.
  Future<void> disable() async {
    final me = AppState.instance.currentMember;
    if (me == null) return;
    stopTimer();
    await _c.from('members').update({
      'live_location_enabled': false,
      'live_lat': null,
      'live_lng': null,
      'live_at': null,
    }).eq('id', me.id);
    me.liveLocationEnabled = false;
    AppState.instance.bumpStats();
  }

  /// Restart streaming if the current member has live sharing on
  /// (called after sign-in / on app start).
  void resumeIfEnabled() {
    final me = AppState.instance.currentMember;
    if (me == null) return;
    if (!me.liveLocationEnabled) return;
    _pushOnce();
    _start();
  }

  /// Maestro-only: every member currently sharing their live location.
  static Future<List<LiveMemberLocation>> fetchAll() async {
    final rows = await _c.from('live_locations').select();
    return (rows as List)
        .map((r) {
          final m = r as Map<String, dynamic>;
          return LiveMemberLocation(
            id: m['id'] as String,
            name: (m['name'] as String?) ?? 'Member',
            branch: (m['branch'] as String?) ?? '',
            voiceSection: (m['voice_section'] as String?) ?? '',
            role: (m['role'] as String?) ?? 'member',
            photoUrl: m['photo_url'] as String?,
            lat: (m['live_lat'] as num).toDouble(),
            lng: (m['live_lng'] as num).toDouble(),
            at: m['live_at'] != null
                ? DateTime.parse(m['live_at'] as String).toLocal()
                : null,
          );
        })
        .toList();
  }

  /// Pushes a single position to Supabase, updating the cached
  /// last-pushed point. Used by the position-stream listener and the
  /// heartbeat timer.
  Future<void> _push(Position pos) async {
    try {
      final me = AppState.instance.currentMember;
      if (me == null) {
        stopTimer();
        return;
      }
      await _c.from('members').update({
        'live_lat': pos.latitude,
        'live_lng': pos.longitude,
        'live_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', me.id);
    } catch (_) {
      // Swallow errors — next event/heartbeat will try again.
    }
  }

  /// Fetches the current position once and pushes it (used by the
  /// heartbeat and by `enable()` / `resumeIfEnabled()`).
  Future<void> _pushOnce() async {
    try {
      final me = AppState.instance.currentMember;
      if (me == null) {
        stopTimer();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: _accuracy,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _push(pos);
    } catch (_) {}
  }
}
