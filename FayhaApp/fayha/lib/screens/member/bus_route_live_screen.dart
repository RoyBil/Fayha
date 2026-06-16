import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../data/bus_route_models.dart';
import '../../services/bus_pickup_service.dart';
import '../../services/live_tracking_service.dart';
import '../../services/trip_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'bus_trip_driver_screen.dart';

/// Member view of a route: shows the polyline + stops, and (when a
/// trip is active) the live bus position, next stop, and ETA.
class BusRouteLiveScreen extends StatefulWidget {
  final BusRoute route;
  const BusRouteLiveScreen({super.key, required this.route});

  @override
  State<BusRouteLiveScreen> createState() => _BusRouteLiveScreenState();
}

class _BusRouteLiveScreenState extends State<BusRouteLiveScreen> {
  final _mapCtrl = MapController();
  BusTrip? _trip;
  TripPosition? _position;
  TripEvent? _latestEvent;
  Duration? _eta;
  double? _remainingM;

  StreamSubscription<TripPosition>? _posSub;
  StreamSubscription<TripEvent>? _evtSub;
  Timer? _etaTimer;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Subscribe to route-level events immediately. This catches ROUTE_STARTED
    // even if the member opens this screen before the driver starts the trip.
    _evtSub = LiveTrackingService.events(widget.route.id).listen(_onEvent);

    final trip = await TripService.activeForRoute(widget.route.id);
    if (!mounted) return;
    if (trip != null) {
      setState(() => _trip = trip);
      _attachPositions(trip);
    }
    try {
      await LiveTrackingService.subscribeToRoute(widget.route.id);
      if (mounted) setState(() => _subscribed = true);
    } catch (_) {/* ignore — non-fatal */}
  }

  void _onEvent(TripEvent e) {
    if (!mounted) return;
    setState(() => _latestEvent = e);
    if (e.type == TripEventType.routeStarted && _trip == null) {
      // A driver just started — fetch the trip and attach positions.
      TripService.activeForRoute(widget.route.id).then((t) {
        if (!mounted || t == null) return;
        setState(() => _trip = t);
        _attachPositions(t);
      });
      return;
    }
    if (e.type == TripEventType.routeCompleted ||
        e.type == TripEventType.routeCancelled) {
      _posSub?.cancel();
      _etaTimer?.cancel();
    }
  }

  void _attachPositions(BusTrip trip) {
    _posSub?.cancel();
    _posSub = LiveTrackingService.positions(trip.id).listen((_) async {
      // Each raw GPS push triggers a snap-to-polyline query; we render
      // the snapped point so the bus icon stays glued to the road.
      final snapped = await LiveTrackingService.snappedPosition(trip.id);
      if (!mounted || snapped == null) return;
      setState(() => _position = snapped);
      _refreshEta();
    });
    LiveTrackingService.snappedPosition(trip.id).then((p) {
      if (mounted && p != null) {
        setState(() => _position = p);
        _refreshEta();
      }
    });
    _etaTimer?.cancel();
    _etaTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshEta());
  }

  Future<void> _refreshEta() async {
    final t = _trip;
    final p = _position;
    if (t == null || p == null) return;
    final progress = await LiveTrackingService.progress(t.id);
    if (!mounted || progress == null) return;
    setState(() {
      _remainingM = progress.remainingM;
      _eta = LiveTrackingService.estimateEta(
        progress: progress,
        position: p,
      );
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _evtSub?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPickup() async {
    try {
      final req = await BusPickupService.requestFromCurrentLocation(
        widget.route.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Pickup requested · ${req.distanceToRouteM.toStringAsFixed(0)} m from route',
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pickup failed: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          IconButton(
            tooltip: _subscribed ? 'Unsubscribe' : 'Subscribe',
            icon: Icon(_subscribed
                ? Icons.notifications_active
                : Icons.notifications_none),
            onPressed: () async {
              try {
                if (_subscribed) {
                  await LiveTrackingService.unsubscribeFromRoute(r.id);
                } else {
                  await LiveTrackingService.subscribeToRoute(r.id);
                }
                if (!mounted) return;
                setState(() => _subscribed = !_subscribed);
              } catch (_) {/* ignore */}
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusBanner(
            trip: _trip,
            position: _position,
            eta: _eta,
            remainingM: _remainingM,
            latestEvent: _latestEvent,
            route: r,
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter:
                    _position?.location ?? r.startPoint,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.fayhanationalchoir.app',
                  additionalOptions: const {'r': ''},
                ),
                if (r.polyline.length >= 2)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: r.polyline,
                      color: AppColors.primary,
                      strokeWidth: 4,
                    ),
                  ]),
                MarkerLayer(markers: [
                  Marker(
                    point: r.startPoint,
                    width: 32,
                    height: 32,
                    child: const Icon(Icons.flag,
                        color: AppColors.secondary, size: 28),
                  ),
                  Marker(
                    point: r.endPoint,
                    width: 32,
                    height: 32,
                    child: const Icon(Icons.location_on,
                        color: AppColors.primary, size: 28),
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
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (_position != null)
                    Marker(
                      point: _position!.location,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black38,
                                blurRadius: 6,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.directions_bus,
                            color: Colors.white, size: 22),
                      ),
                    ),
                ]),
              ],
            ),
          ),
          _BottomActions(
            route: widget.route,
            trip: _trip,
            onTripChanged: (t) {
              if (!mounted) return;
              setState(() => _trip = t);
              if (t != null) _attachPositions(t);
            },
            onRequestPickup: _requestPickup,
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final BusRoute route;
  final BusTrip? trip;
  final ValueChanged<BusTrip?> onTripChanged;
  final VoidCallback onRequestPickup;
  const _BottomActions({
    required this.route,
    required this.trip,
    required this.onTripChanged,
    required this.onRequestPickup,
  });

  @override
  Widget build(BuildContext context) {
    final me = AppState.instance.currentMember;
    final isAdmin =
        me != null && (me.role == 'admin' || me.role == 'superAdmin');
    final live = trip != null;
    final iAmDriver = trip != null && me?.id == trip!.driverId;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (isAdmin && !live)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusTripDriverScreen(route: route),
                      ),
                    );
                    if (updated == true) {
                      final t = await TripService.activeForRoute(route.id);
                      onTripChanged(t);
                    } else {
                      // Refresh in case the trip ended while we were away.
                      final t = await TripService.activeForRoute(route.id);
                      onTripChanged(t);
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Tracking This Bus'),
                ),
              ),
            if (isAdmin && live && iAmDriver) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusTripDriverScreen(
                          route: route,
                          resumeTrip: trip,
                        ),
                      ),
                    );
                    final t = await TripService.activeForRoute(route.id);
                    onTripChanged(t);
                  },
                  icon: const Icon(Icons.directions_bus),
                  label: const Text('Open Driver View'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.dark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onRequestPickup,
                icon: const Icon(Icons.front_hand),
                label: const Text('Request Pickup Here'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final BusTrip? trip;
  final TripPosition? position;
  final Duration? eta;
  final double? remainingM;
  final TripEvent? latestEvent;
  final BusRoute route;
  const _StatusBanner({
    required this.trip,
    required this.position,
    required this.eta,
    required this.remainingM,
    required this.latestEvent,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    if (trip == null) {
      return _bar(
        bg: AppColors.lightGray.withValues(alpha: 0.25),
        icon: Icons.directions_bus_outlined,
        title: 'No bus on this route right now',
        subtitle:
            '${route.stops.length} stops · ${(route.totalDistanceM / 1000).toStringAsFixed(1)} km',
        textColor: AppColors.charcoal,
      );
    }
    final next = _nextStopName();
    final etaLabel = eta == null
        ? null
        : eta!.inMinutes >= 1
            ? '${eta!.inMinutes} min'
            : '<1 min';
    final remainKm = remainingM == null
        ? null
        : '${(remainingM! / 1000).toStringAsFixed(1)} km left';
    final eventLabel = latestEvent != null ? _eventLabel(latestEvent!) : null;

    return _bar(
      bg: AppColors.secondary,
      icon: Icons.directions_bus,
      title: next != null ? 'Next stop: $next' : 'Bus en route',
      subtitle: [
        if (etaLabel != null) 'ETA $etaLabel',
        if (remainKm != null) remainKm,
        if (eventLabel != null) eventLabel,
      ].join(' · '),
      textColor: Colors.white,
    );
  }

  String? _nextStopName() {
    final cur = trip?.currentStopIndex ?? -1;
    for (final s in route.stops) {
      if (s.orderIndex > cur) return s.name;
    }
    return null;
  }

  String _eventLabel(TripEvent e) {
    switch (e.type) {
      case TripEventType.routeStarted:    return 'started';
      case TripEventType.stopApproaching: return 'approaching';
      case TripEventType.stopArrived:     return 'arrived';
      case TripEventType.stopLeft:        return 'departed';
      case TripEventType.routeCompleted:  return 'completed';
      case TripEventType.routeCancelled:  return 'cancelled';
      case TripEventType.unknown:         return '';
    }
  }

  Widget _bar({
    required Color bg,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: bg,
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.85),
                          fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
