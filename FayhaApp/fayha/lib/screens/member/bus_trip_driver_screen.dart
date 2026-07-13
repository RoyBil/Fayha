import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/bus_route_models.dart';
import '../../services/driver_location_service.dart';
import '../../services/live_tracking_service.dart';
import '../../services/osrm_service.dart';
import '../../services/trip_service.dart';
import '../../theme/app_theme.dart';

/// Driver / admin view. Starts a trip, then streams GPS to the
/// `ingest_bus_position` RPC every 7–10s while showing the bus's
/// current position and the upcoming stop.
class BusTripDriverScreen extends StatefulWidget {
  final BusRoute route;
  final BusTrip? resumeTrip;
  const BusTripDriverScreen({super.key, required this.route, this.resumeTrip});

  @override
  State<BusTripDriverScreen> createState() => _BusTripDriverScreenState();
}

class _BusTripDriverScreenState extends State<BusTripDriverScreen> {
  final _mapCtrl = MapController();
  BusTrip? _trip;
  TripPosition? _position;
  StreamSubscription<TripPosition>? _posSub;
  StreamSubscription<TripEvent>? _evtSub;
  final List<TripEvent> _recentEvents = [];
  bool _busy = false;
  OsrmRoute? _computedRoute;

  @override
  void initState() {
    super.initState();
    _computeFullRoute();
    if (widget.resumeTrip != null) {
      _attachToTrip(widget.resumeTrip!);
    }
  }

  Future<void> _computeFullRoute() async {
    final r = widget.route;
    final waypoints = r.stops.map((s) => s.location).toList();
    final result = await OsrmService.route(
      r.startPoint,
      r.endPoint,
      waypoints: waypoints,
    );
    if (mounted && result != null) {
      setState(() => _computedRoute = result);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _evtSub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final trip = await TripService.start(widget.route.id);
      await DriverLocationService.instance.start(trip.id);
      _attachToTrip(trip);
    } on PostgrestException catch (e) {
      // RPC-raised reasons come through clean (e.g. "Cannot start trip:
      // route has no path yet. Edit the route and re-save…").
      _toast(e.message);
    } catch (e) {
      _toast('Could not start: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _attachToTrip(BusTrip trip) {
    _trip = trip;
    _posSub = LiveTrackingService.positions(trip.id).listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      _mapCtrl.move(p.location, 15.5);
    });
    _evtSub = LiveTrackingService.events(widget.route.id).listen((e) {
      if (!mounted) return;
      if (e.tripId != trip.id) return;
      setState(() {
        _recentEvents.insert(0, e);
        if (_recentEvents.length > 6) _recentEvents.removeLast();
      });
    });
    LiveTrackingService.currentPosition(trip.id).then((p) {
      if (mounted && p != null) setState(() => _position = p);
    });
    if (DriverLocationService.instance.tripId != trip.id) {
      DriverLocationService.instance.start(trip.id);
    }
  }

  Future<void> _complete() async {
    final t = _trip;
    if (t == null) return;
    final ok = await _confirm('Complete this trip?');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await DriverLocationService.instance.stop();
      await TripService.complete(t.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _toast('Could not complete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final t = _trip;
    if (t == null) {
      Navigator.pop(context);
      return;
    }
    final ok = await _confirm('Cancel this trip?');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await DriverLocationService.instance.stop();
      await TripService.cancel(t.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _toast('Could not cancel: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return r == true;
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final nextStop = _nextStop();
    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          if (_trip != null)
            IconButton(
              tooltip: 'Cancel trip',
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : _cancel,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_trip == null)
            _PreStartCard(route: r, busy: _busy, onStart: _start)
          else
            _ActiveTripBar(route: r, position: _position, nextStop: nextStop),
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _position?.location ?? r.startPoint,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.fayhanationalchoir.app',
                  maxNativeZoom: 19,
                  maxZoom: 20,
                ),
                PolylineLayer(
                  polylines: [
                    if (_computedRoute != null)
                      Polyline(
                        points: _computedRoute!.polyline,
                        color: AppColors.primary,
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      )
                    else if (r.polyline.length >= 2)
                      Polyline(
                        points: r.polyline,
                        color: AppColors.primary,
                        strokeWidth: 4,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: r.startPoint,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.flag,
                        color: AppColors.secondary,
                        size: 28,
                      ),
                    ),
                    Marker(
                      point: r.endPoint,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    for (var i = 0; i < r.stops.length; i++)
                      Marker(
                        point: r.stops[i].location,
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (_position != null)
                      Marker(
                        point: _position!.location,
                        width: 44,
                        height: 44,
                        child: _BusMarker(heading: _position!.heading),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_recentEvents.isNotEmpty) _EventStrip(events: _recentEvents),
          if (_trip != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _busy ? null : _complete,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete Trip'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BusStop? _nextStop() {
    final t = _trip;
    if (t == null) return null;
    final r = widget.route;
    final cur = t.currentStopIndex ?? -1;
    for (final s in r.stops) {
      if (s.orderIndex > cur) return s;
    }
    return null;
  }
}

class _PreStartCard extends StatelessWidget {
  final BusRoute route;
  final bool busy;
  final VoidCallback onStart;
  const _PreStartCard({
    required this.route,
    required this.busy,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGray.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to drive',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            '${route.startName} → ${route.endName} · ${route.stops.length} stops',
            style: TextStyle(color: AppColors.gray, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: busy ? null : onStart,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('Start Trip'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.gray),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Keep this screen open. Tracking pauses if the app is closed or the phone locks.',
                  style: TextStyle(color: AppColors.gray, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveTripBar extends StatelessWidget {
  final BusRoute route;
  final TripPosition? position;
  final BusStop? nextStop;
  const _ActiveTripBar({
    required this.route,
    required this.position,
    required this.nextStop,
  });

  @override
  Widget build(BuildContext context) {
    final stale =
        position == null ||
        DateTime.now().difference(position!.recordedAt) >
            const Duration(seconds: 25);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: stale ? AppColors.primary : AppColors.secondary,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.directions_bus, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stale ? 'Waiting for GPS…' : 'Tracking live',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (nextStop != null)
                    Text(
                      'Next: ${nextStop!.name}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (position?.speedMps != null && position!.speedMps! > 0.3)
              Text(
                '${(position!.speedMps! * 3.6).toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventStrip extends StatelessWidget {
  final List<TripEvent> events;
  const _EventStrip({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.offWhite,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final e = events[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.lightGray.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(_iconFor(e.type), size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _labelFor(e.type),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(TripEventType t) {
    switch (t) {
      case TripEventType.routeStarted:
        return Icons.play_arrow;
      case TripEventType.stopApproaching:
        return Icons.near_me;
      case TripEventType.stopArrived:
        return Icons.flag;
      case TripEventType.stopLeft:
        return Icons.arrow_forward;
      case TripEventType.routeCompleted:
        return Icons.check_circle;
      case TripEventType.routeCancelled:
        return Icons.cancel;
      case TripEventType.unknown:
        return Icons.info_outline;
    }
  }

  String _labelFor(TripEventType t) {
    switch (t) {
      case TripEventType.routeStarted:
        return 'Started';
      case TripEventType.stopApproaching:
        return 'Approaching';
      case TripEventType.stopArrived:
        return 'Arrived';
      case TripEventType.stopLeft:
        return 'Departed';
      case TripEventType.routeCompleted:
        return 'Completed';
      case TripEventType.routeCancelled:
        return 'Cancelled';
      case TripEventType.unknown:
        return 'Event';
    }
  }
}

class _BusMarker extends StatelessWidget {
  final double? heading;
  const _BusMarker({this.heading});

  @override
  Widget build(BuildContext context) {
    final h = heading ?? 0;
    return Transform.rotate(
      angle: h * 3.14159 / 180,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.directions_bus, color: Colors.white, size: 22),
      ),
    );
  }
}
