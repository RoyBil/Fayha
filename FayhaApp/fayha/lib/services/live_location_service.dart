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

/// Singleton that pushes the current member's coordinates to Supabase
/// every [_interval] while the app is open. The Maestro reads these
/// from the `live_locations` view.
class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  static final _c = Supabase.instance.client;
  static const _interval = Duration(seconds: 30);

  Timer? _timer;
  bool get isRunning => _timer != null;

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

    // Flip the DB flag on, then push one position immediately.
    await _c.from('members').update({
      'live_location_enabled': true,
    }).eq('id', me.id);
    me.liveLocationEnabled = true;
    AppState.instance.bumpStats(); // triggers home rebuild
    await _pushOnce();
    _start();
  }

  /// Start the periodic timer. Idempotent.
  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _pushOnce());
  }

  /// Stop the periodic timer (does NOT disable sharing in the DB —
  /// only the Maestro can do that). Used on sign-out / app close.
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disables live sharing for the current member: stops the timer,
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

  /// Restart the timer if the current member has live sharing on
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

  Future<void> _pushOnce() async {
    try {
      final me = AppState.instance.currentMember;
      if (me == null) {
        stopTimer();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _c.from('members').update({
        'live_lat': pos.latitude,
        'live_lng': pos.longitude,
        'live_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', me.id);
    } catch (_) {
      // Swallow errors — next tick will try again.
    }
  }
}
