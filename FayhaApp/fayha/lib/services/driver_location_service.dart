import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Streams the driver's GPS to Supabase via the `ingest_bus_position`
/// RPC. The RPC upserts the latest position and evaluates stop
/// approach/arrival/leave events server-side — clients never write to
/// the events table directly.
///
/// Use:
///   await DriverLocationService.instance.start(tripId);
///   ...
///   await DriverLocationService.instance.stop();
class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  static final _c = Supabase.instance.client;

  /// Min seconds between RPC pushes. We accept every GPS sample from
  /// the platform but throttle the network round-trip to this cadence.
  static const _minPushInterval = Duration(seconds: 7);
  static const _heartbeat = Duration(seconds: 10);

  String? _tripId;
  StreamSubscription<Position>? _posSub;
  Timer? _heartbeatTimer;
  Position? _lastSample;
  DateTime? _lastPushAt;

  bool get isRunning => _tripId != null;
  String? get tripId => _tripId;

  Future<void> start(String tripId) async {
    if (_tripId != null) await stop();

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

    _tripId = tripId;

    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            // We don't filter here — the throttle below caps push rate.
          ),
        ).listen((p) {
          _lastSample = p;
          _maybePush();
        });

    _heartbeatTimer = Timer.periodic(_heartbeat, (_) {
      // Force a push even when stationary so the server sees a recent
      // recorded_at (used by UI to detect "stale" buses).
      _maybePush(force: true);
    });

    // Send an initial sample immediately.
    try {
      _lastSample = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      await _push();
    } catch (_) {
      /* will retry on next tick */
    }
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    _posSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _tripId = null;
    _lastSample = null;
    _lastPushAt = null;
  }

  Future<void> _maybePush({bool force = false}) async {
    if (_tripId == null || _lastSample == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastPushAt != null &&
        now.difference(_lastPushAt!) < _minPushInterval) {
      return;
    }
    await _push();
  }

  Future<void> _push() async {
    final trip = _tripId;
    final p = _lastSample;
    if (trip == null || p == null) return;
    try {
      await _c.rpc(
        'ingest_bus_position',
        params: {
          'p_trip': trip,
          'p_lat': p.latitude,
          'p_lng': p.longitude,
          'p_heading': p.heading,
          'p_speed_mps': p.speed,
        },
      );
      _lastPushAt = DateTime.now();
    } catch (_) {
      // Swallow — next tick will retry. The driver UI can surface a
      // stale-position warning if `_lastPushAt` drifts too far.
    }
  }
}
