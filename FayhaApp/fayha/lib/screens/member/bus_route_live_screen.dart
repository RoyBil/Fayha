import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/bus_route_models.dart';
import '../../data/map_data.dart';
import '../../services/audience_data.dart';
import '../../services/bus_pickup_service.dart';
import '../../services/osrm_service.dart';
import '../../services/live_location_service.dart';
import '../../services/live_tracking_service.dart';
import '../../services/member_houses_service.dart';
import '../../services/photon_service.dart';
import '../../services/trip_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/fayha_map.dart';
import 'bus_trip_driver_screen.dart';

/// Member view of a route: shows the polyline + stops, and (when a
/// trip is active) the live bus position, next stop, and ETA.
///
/// Layer toggle chips let the user overlay branch locations, member
/// houses, and live member positions on the same map — exactly like
/// the main Map page.
class BusRouteLiveScreen extends StatefulWidget {
  final BusRoute route;
  const BusRouteLiveScreen({super.key, required this.route});

  @override
  State<BusRouteLiveScreen> createState() => _BusRouteLiveScreenState();
}

class _BusRouteLiveScreenState extends State<BusRouteLiveScreen>
    with TickerProviderStateMixin {
  final _mapCtrl = MapController();

  // ── Bus tracking ────────────────────────────────────────────────────
  BusTrip? _trip;
  TripPosition? _position;
  TripEvent? _latestEvent;
  Duration? _eta;
  double? _remainingM;
  StreamSubscription<TripPosition>? _posSub;
  StreamSubscription<TripEvent>? _evtSub;
  Timer? _etaTimer;
  bool _subscribed = false;

  // ── Pickup point (tap-to-place or Photon search) ────────────────────
  LatLng? _pendingPickup;
  String? _pendingPickupLabel;

  // ── Full road-following route (OSRM: start → stops → end) ──────────
  OsrmRoute? _computedRoute;

  // ── Navigation to nearest stop ──────────────────────────────────────
  OsrmRoute? _navRoute;
  String? _navTargetName;
  LatLng? _myNavLocation;
  bool _navLoading = false;

  // ── Layer toggles ───────────────────────────────────────────────────
  bool _showRoute = true;
  bool _showBranches = false;
  bool _showHouses = false;
  bool _showLive = false;

  // ── Layer data ──────────────────────────────────────────────────────
  List<BranchLocation> _branches = [];
  List<MemberHouse> _houses = [];
  List<LiveMemberLocation> _liveMembers = [];
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadLayers();
    _computeFullRoute();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _showLive) _refreshLive();
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _evtSub?.cancel();
    _etaTimer?.cancel();
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  // ── Full road-following route ────────────────────────────────────────

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

  // ── Bus tracking ────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
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
    } catch (_) {}
  }

  void _onEvent(TripEvent e) {
    if (!mounted) return;
    setState(() => _latestEvent = e);
    if (e.type == TripEventType.routeStarted && _trip == null) {
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
    _etaTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshEta(),
    );
  }

  Future<void> _refreshEta() async {
    final t = _trip;
    final p = _position;
    if (t == null || p == null) return;
    final progress = await LiveTrackingService.progress(t.id);
    if (!mounted || progress == null) return;
    setState(() {
      _remainingM = progress.remainingM;
      _eta = LiveTrackingService.estimateEta(progress: progress, position: p);
    });
  }

  // ── Map layers ──────────────────────────────────────────────────────

  Future<void> _loadLayers() async {
    try {
      final results = await Future.wait([
        AudienceData.fetchBranches(),
        MemberHousesService.fetchAll(),
        LiveLocationService.fetchAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = results[0] as List<BranchLocation>;
        _houses = results[1] as List<MemberHouse>;
        _liveMembers = results[2] as List<LiveMemberLocation>;
      });
    } catch (_) {}
  }

  Future<void> _refreshLive() async {
    try {
      final live = await LiveLocationService.fetchAll();
      if (mounted) setState(() => _liveMembers = live);
    } catch (_) {}
  }

  // ── Map controls ────────────────────────────────────────────────────

  void _zoom(double delta) {
    final c = _mapCtrl.camera;
    final z = (c.zoom + delta).clamp(2.0, 18.0);
    smoothMove(
      this,
      _mapCtrl,
      c.center,
      z,
      duration: const Duration(milliseconds: 350),
    );
  }

  void _recenter() {
    smoothMove(
      this,
      _mapCtrl,
      _position?.location ?? widget.route.startPoint,
      13,
    );
  }

  // ── Info sheet launchers ────────────────────────────────────────────

  Future<void> _focusBranch(BranchLocation b) async {
    await smoothMove(
      this,
      _mapCtrl,
      LatLng(b.lat, b.lng),
      14.5,
      duration: const Duration(milliseconds: 800),
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MapInfoSheet(
        color: b.color,
        icon: Icons.location_city,
        title: '${b.name} Branch',
        subtitle: b.practiceLocation,
        facts: [
          MapFact(Icons.calendar_month, 'Opened', '${b.yearOpened}'),
          MapFact(Icons.person_outline, 'Conductor', b.conductor),
          MapFact(Icons.groups_outlined, 'Members', '≈ ${b.membersApprox}'),
          MapFact(Icons.event_repeat, 'Rehearsals', b.rehearsalSchedule),
        ],
        description: b.description.isNotEmpty ? b.description : null,
        mapUrl: b.mapUrl.isNotEmpty ? b.mapUrl : null,
        onOpenMap: b.mapUrl.isNotEmpty
            ? () => launchUrl(
                Uri.parse(b.mapUrl),
                mode: LaunchMode.externalApplication,
              )
            : null,
      ),
    );
  }

  Future<void> _focusHouse(MemberHouse h) async {
    await smoothMove(
      this,
      _mapCtrl,
      LatLng(h.lat, h.lng),
      15.5,
      duration: const Duration(milliseconds: 800),
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HouseSheet(house: h),
    );
  }

  Future<void> _focusLive(LiveMemberLocation m) async {
    await smoothMove(
      this,
      _mapCtrl,
      LatLng(m.lat, m.lng),
      15.5,
      duration: const Duration(milliseconds: 800),
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LiveMemberSheet(member: m),
    );
  }

  Future<void> _requestPickup() async {
    try {
      final PickupRequest req;
      if (_pendingPickup != null) {
        req = await BusPickupService.requestAt(
          widget.route.id,
          _pendingPickup!,
        );
      } else {
        req = await BusPickupService.requestFromCurrentLocation(
          widget.route.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _pendingPickup = null;
        _pendingPickupLabel = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pickup requested · ${req.distanceToRouteM.toStringAsFixed(0)} m from route',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pickup failed: $e')));
    }
  }

  Future<void> _openPickupSearch() async {
    final result = await showModalBottomSheet<PhotonResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickupSearchSheet(near: widget.route.startPoint),
    );
    if (!mounted || result == null) return;
    setState(() {
      _pendingPickup = result.location;
      _pendingPickupLabel = result.name;
    });
    smoothMove(this, _mapCtrl, result.location, 15);
  }

  void _clearPendingPickup() => setState(() {
    _pendingPickup = null;
    _pendingPickupLabel = null;
  });

  // ── Navigation to nearest stop ───────────────────────────────────────

  Future<void> _toggleNavigation() async {
    if (_navRoute != null || _myNavLocation != null) {
      setState(() {
        _navRoute = null;
        _navTargetName = null;
        _myNavLocation = null;
      });
      return;
    }
    setState(() => _navLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));
      final myLoc = LatLng(pos.latitude, pos.longitude);
      final target = _nearestTarget(myLoc);
      final nav = await OsrmService.route(myLoc, target.loc);
      if (!mounted) return;
      setState(() {
        _myNavLocation = myLoc;
        _navRoute = nav;
        _navTargetName = target.name;
      });
      if (nav != null) smoothMove(this, _mapCtrl, myLoc, 14);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Navigation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _navLoading = false);
    }
  }

  void _clearNavigation() => setState(() {
    _navRoute = null;
    _navTargetName = null;
    _myNavLocation = null;
  });

  ({String name, LatLng loc}) _nearestTarget(LatLng from) {
    final r = widget.route;
    final candidates = <({String name, LatLng loc})>[
      (name: r.startName, loc: r.startPoint),
      ...r.stops.map((s) => (name: s.name, loc: s.location)),
      (name: r.endName, loc: r.endPoint),
    ];
    ({String name, LatLng loc})? best;
    double minD = double.infinity;
    for (final c in candidates) {
      final d = _distM(from, c.loc);
      if (d < minD) {
        minD = d;
        best = c;
      }
    }
    return best!;
  }

  double _distM(LatLng a, LatLng b) {
    const earthR = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final x =
        sinDLat * sinDLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinDLng *
            sinDLng;
    return earthR * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  // ── Markers ─────────────────────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final r = widget.route;
    final markers = <Marker>[];

    if (_showRoute) {
      markers.addAll([
        Marker(
          point: r.startPoint,
          width: 32,
          height: 32,
          child: const Icon(Icons.flag, color: AppColors.secondary, size: 28),
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
              child: const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
      ]);
    }

    if (_myNavLocation != null) {
      markers.add(
        Marker(
          point: _myNavLocation!,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_pendingPickup != null) {
      markers.add(
        Marker(
          point: _pendingPickup!,
          width: 140,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  _pendingPickupLabel ?? 'Pickup here',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(width: 3, height: 12, color: AppColors.accent),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showBranches) {
      for (final b in _branches) {
        markers.add(
          Marker(
            point: LatLng(b.lat, b.lng),
            width: 140,
            height: 60,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _focusBranch(b),
              child: _LayerPin(
                label: b.name,
                color: b.color,
                icon: Icons.location_city,
              ),
            ),
          ),
        );
      }
    }

    if (_showHouses) {
      for (final h in _houses) {
        markers.add(
          Marker(
            point: LatLng(h.lat, h.lng),
            width: 130,
            height: 55,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _focusHouse(h),
              child: _LayerPin(
                label: h.name.split(' ').first,
                color: MapData.colorFor(h.branch),
                icon: Icons.home,
              ),
            ),
          ),
        );
      }
    }

    if (_showLive) {
      for (final m in _liveMembers) {
        markers.add(
          Marker(
            point: LatLng(m.lat, m.lng),
            width: 130,
            height: 55,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _focusLive(m),
              child: _LayerPin(
                label: m.name.split(' ').first,
                color: const Color(0xFF2E7D32),
                icon: Icons.person_pin,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          IconButton(
            tooltip: _subscribed ? 'Unsubscribe' : 'Subscribe',
            icon: Icon(
              _subscribed
                  ? Icons.notifications_active
                  : Icons.notifications_none,
            ),
            onPressed: () async {
              try {
                if (_subscribed) {
                  await LiveTrackingService.unsubscribeFromRoute(r.id);
                } else {
                  await LiveTrackingService.subscribeToRoute(r.id);
                }
                if (!mounted) return;
                setState(() => _subscribed = !_subscribed);
              } catch (_) {}
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
          _LayerFilterBar(
            showRoute: _showRoute,
            showBranches: _showBranches,
            showHouses: _showHouses,
            showLive: _showLive,
            liveCount: _liveMembers.length,
            onRouteChanged: (v) => setState(() => _showRoute = v),
            onBranchesChanged: (v) => setState(() => _showBranches = v),
            onHousesChanged: (v) => setState(() => _showHouses = v),
            onLiveChanged: (v) {
              setState(() => _showLive = v);
              if (v) _refreshLive();
            },
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _position?.location ?? r.startPoint,
                    initialZoom: 13,
                    minZoom: 2,
                    maxZoom: 20,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.flingAnimation |
                          InteractiveFlag.scrollWheelZoom,
                    ),
                    onTap: (_, point) => setState(() {
                      _pendingPickup = point;
                      _pendingPickupLabel = 'Tap location';
                    }),
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
                    if (_showRoute)
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
                    if (_navRoute != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _navRoute!.polyline,
                            color: const Color(0xFF1565C0),
                            strokeWidth: 4.5,
                            borderColor: Colors.white,
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _buildMarkers()),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    children: [
                      _ZoomBtn(icon: Icons.add, onTap: () => _zoom(1)),
                      const SizedBox(height: 8),
                      _ZoomBtn(icon: Icons.remove, onTap: () => _zoom(-1)),
                      const SizedBox(height: 8),
                      _ZoomBtn(icon: Icons.my_location, onTap: _recenter),
                      const SizedBox(height: 8),
                      _navLoading
                          ? Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            )
                          : _ZoomBtn(
                              icon:
                                  (_navRoute != null || _myNavLocation != null)
                                  ? Icons.navigation
                                  : Icons.navigation_outlined,
                              iconColor:
                                  (_navRoute != null || _myNavLocation != null)
                                  ? const Color(0xFF1565C0)
                                  : null,
                              onTap: _toggleNavigation,
                            ),
                    ],
                  ),
                ),
                if (_navRoute != null)
                  Positioned(
                    left: 60,
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'To: ${_navTargetName ?? 'stop'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_navRoute!.distanceLabel} · ${_navRoute!.etaLabel}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _clearNavigation,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'search_pickup',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        tooltip: 'Search pickup location',
                        onPressed: _openPickupSearch,
                        child: const Icon(Icons.search),
                      ),
                      if (_pendingPickup != null) ...[
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'clear_pickup',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.gray,
                          tooltip: 'Clear pickup pin',
                          onPressed: _clearPendingPickup,
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_pendingPickup != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 52,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.front_hand,
                            size: 16,
                            color: AppColors.dark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pickup: ${_pendingPickupLabel ?? 'Selected location'}\nTap the button below to confirm',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.dark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _BottomActions(
            route: widget.route,
            trip: _trip,
            hasPendingPickup: _pendingPickup != null,
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

// ════════════════════════════════════════════════════════════════════════
// Layer filter bar
// ════════════════════════════════════════════════════════════════════════

class _LayerFilterBar extends StatelessWidget {
  final bool showRoute;
  final bool showBranches;
  final bool showHouses;
  final bool showLive;
  final int liveCount;
  final ValueChanged<bool> onRouteChanged;
  final ValueChanged<bool> onBranchesChanged;
  final ValueChanged<bool> onHousesChanged;
  final ValueChanged<bool> onLiveChanged;
  const _LayerFilterBar({
    required this.showRoute,
    required this.showBranches,
    required this.showHouses,
    required this.showLive,
    required this.liveCount,
    required this.onRouteChanged,
    required this.onBranchesChanged,
    required this.onHousesChanged,
    required this.onLiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.cream,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _FilterChip(
            label: 'Route',
            icon: Icons.route,
            selected: showRoute,
            color: AppColors.primary,
            onChanged: onRouteChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Branches',
            icon: Icons.location_city,
            selected: showBranches,
            color: AppColors.accentDark,
            onChanged: onBranchesChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Houses',
            icon: Icons.home_outlined,
            selected: showHouses,
            color: AppColors.secondary,
            onChanged: onHousesChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: liveCount > 0 ? 'Live ($liveCount)' : 'Live',
            icon: Icons.person_pin,
            selected: showLive,
            color: const Color(0xFF2E7D32),
            onChanged: onLiveChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.lightGray,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : AppColors.gray),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Pin marker — dot + label badge (same style as the public map)
// ════════════════════════════════════════════════════════════════════════

class _LayerPin extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _LayerPin({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        Positioned(
          top: -1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Bottom sheets
// ════════════════════════════════════════════════════════════════════════

class _HouseSheet extends StatelessWidget {
  final MemberHouse house;
  const _HouseSheet({required this.house});

  @override
  Widget build(BuildContext context) {
    final color = MapData.colorFor(house.branch);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Avatar(name: house.name, size: 52, photoUrl: house.photoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        house.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${house.branch} · ${house.voiceSection}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (house.address != null &&
                          house.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          house.address!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMemberSheet extends StatelessWidget {
  final LiveMemberLocation member;
  const _LiveMemberSheet({required this.member});

  @override
  Widget build(BuildContext context) {
    final color = MapData.colorFor(member.branch);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  children: [
                    Avatar(
                      name: member.name,
                      size: 52,
                      photoUrl: member.photoUrl,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${member.branch} · ${member.voiceSection}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (member.at != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _ago(member.at!),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: const Color(0xFF2E7D32)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 30) return '● Live now';
    if (d.inSeconds < 60) return 'Updated ${d.inSeconds}s ago';
    if (d.inMinutes < 60) return 'Updated ${d.inMinutes}m ago';
    return 'Updated ${d.inHours}h ago';
  }
}

// ════════════════════════════════════════════════════════════════════════
// Zoom button
// ════════════════════════════════════════════════════════════════════════

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  const _ZoomBtn({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Status banner + bottom actions (unchanged logic)
// ════════════════════════════════════════════════════════════════════════

class _BottomActions extends StatelessWidget {
  final BusRoute route;
  final BusTrip? trip;
  final bool hasPendingPickup;
  final ValueChanged<BusTrip?> onTripChanged;
  final VoidCallback onRequestPickup;
  const _BottomActions({
    required this.route,
    required this.trip,
    required this.hasPendingPickup,
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
                        builder: (_) =>
                            BusTripDriverScreen(route: route, resumeTrip: trip),
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
                label: Text(
                  hasPendingPickup
                      ? 'Confirm Pickup at Selected Location'
                      : 'Request Pickup at My GPS Location',
                ),
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
      case TripEventType.routeStarted:
        return 'started';
      case TripEventType.stopApproaching:
        return 'approaching';
      case TripEventType.stopArrived:
        return 'arrived';
      case TripEventType.stopLeft:
        return 'departed';
      case TripEventType.routeCompleted:
        return 'completed';
      case TripEventType.routeCancelled:
        return 'cancelled';
      case TripEventType.unknown:
        return '';
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
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Pickup location search sheet (Photon)
// ════════════════════════════════════════════════════════════════════════

class _PickupSearchSheet extends StatefulWidget {
  final LatLng near;
  const _PickupSearchSheet({required this.near});

  @override
  State<_PickupSearchSheet> createState() => _PickupSearchSheetState();
}

class _PickupSearchSheetState extends State<_PickupSearchSheet> {
  final _ctrl = TextEditingController();
  List<PhotonResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      final r = await PhotonService.search(q.trim(), near: widget.near);
      if (mounted)
        setState(() {
          _results = r;
          _loading = false;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search for your pickup location…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  leading: const Icon(
                    Icons.place_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: r.subtitle.isNotEmpty
                      ? Text(r.subtitle, style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
