import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/osrm_service.dart';
import '../../services/photon_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fayha_map.dart' show smoothMove;

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

class BusRoutePlannerTab extends StatefulWidget {
  const BusRoutePlannerTab({super.key});

  @override
  State<BusRoutePlannerTab> createState() => _BusRoutePlannerTabState();
}

class _BusRoutePlannerTabState extends State<BusRoutePlannerTab>
    with TickerProviderStateMixin {
  static const _defaultCenter = LatLng(34.05, 35.6);
  static const _defaultZoom = 9.0;

  final _ctrl = MapController();
  LatLng? _myLocation;
  bool _locating = false;

  LatLng? _fromPt;
  String _fromLabel = '';
  LatLng? _toPt;
  String _toLabel = '';
  final _stopPts = <LatLng?>[];
  final _stopLabels = <String>[];

  OsrmRoute? _route;
  bool _routing = false;

  bool get _canRoute => _fromPt != null && _toPt != null;
  bool get _hasAny => _fromPt != null || _toPt != null;

  @override
  void initState() {
    super.initState();
    _tryGetLocation();
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _tryGetLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _goToMyLocation() async {
    if (_myLocation != null) {
      smoothMove(this, _ctrl, _myLocation!, 15.0);
    } else {
      await _tryGetLocation();
      if (_myLocation != null && mounted) {
        smoothMove(this, _ctrl, _myLocation!, 15.0);
      }
    }
  }

  // ── Search modal ───────────────────────────────────────────────────────────

  Future<void> _openSearch({
    required String title,
    required void Function(String label, LatLng pt) onPick,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        title: title,
        nearHint: _myLocation,
        onPicked: onPick,
      ),
    );
  }

  // ── Routing ────────────────────────────────────────────────────────────────

  Future<void> _computeRoute() async {
    if (!_canRoute) return;
    setState(() {
      _routing = true;
      _route = null;
    });
    final via = [for (final p in _stopPts) if (p != null) p];
    final r = await OsrmService.route(_fromPt!, _toPt!, waypoints: via);
    if (!mounted) return;
    setState(() {
      _route = r;
      _routing = false;
    });
    if (r != null && r.polyline.length > 1) {
      try {
        _ctrl.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(r.polyline),
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 300),
        ));
      } catch (_) {}
    } else if (r == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No driving route found between those points.'),
        ),
      );
    }
  }

  void _clearAll() {
    setState(() {
      _fromPt = null;
      _fromLabel = '';
      _toPt = null;
      _toLabel = '';
      _stopPts.clear();
      _stopLabels.clear();
      _route = null;
    });
    _ctrl.move(_defaultCenter, _defaultZoom);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasRoute = _route != null;
    final polylines = hasRoute
        ? [
            Polyline(
              points: _route!.polyline,
              color: AppColors.primary,
              strokeWidth: 5,
              borderColor: Colors.white,
              borderStrokeWidth: 2,
            ),
          ]
        : <Polyline>[];

    return Stack(
      children: [
        // ── Map ───────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _ctrl,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: _defaultZoom,
            minZoom: 2,
            maxZoom: 20,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
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
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            MarkerLayer(markers: _buildMarkers()),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // ── Route planner card ─────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: _RoutePlannerPanel(
              fromLabel: _fromLabel,
              toLabel: _toLabel,
              stopLabels: List.unmodifiable(_stopLabels),
              route: _route,
              routing: _routing,
              hasAny: _hasAny,
              onPickFrom: () => _openSearch(
                title: 'Starting Point',
                onPick: (l, p) {
                  setState(() {
                    _fromPt = p;
                    _fromLabel = l;
                  });
                  if (_canRoute) _computeRoute();
                },
              ),
              onPickTo: () => _openSearch(
                title: 'Destination',
                onPick: (l, p) {
                  setState(() {
                    _toPt = p;
                    _toLabel = l;
                  });
                  if (_canRoute) _computeRoute();
                },
              ),
              onPickStop: (i) => _openSearch(
                title: 'Stop ${i + 1}',
                onPick: (l, p) {
                  setState(() {
                    _stopPts[i] = p;
                    _stopLabels[i] = l;
                  });
                  if (_canRoute) _computeRoute();
                },
              ),
              onAddStop: () => setState(() {
                _stopPts.add(null);
                _stopLabels.add('');
              }),
              onRemoveStop: (i) {
                setState(() {
                  _stopPts.removeAt(i);
                  _stopLabels.removeAt(i);
                });
                if (_canRoute) _computeRoute();
              },
              onCalculate: _computeRoute,
              onClear: _hasAny ? _clearAll : null,
            ),
          ),
        ),

        // ── My Location FAB ────────────────────────────────────────────────
        Positioned(
          right: 12,
          bottom: hasRoute ? 290 : 232,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _locating ? null : _goToMyLocation,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.my_location,
                        size: 20,
                        color: AppColors.primary,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_myLocation != null) {
      markers.add(Marker(
        point: _myLocation!,
        width: 22,
        height: 22,
        child: _BlueDot(),
      ));
    }
    if (_fromPt != null) {
      markers.add(Marker(
        point: _fromPt!,
        width: 36,
        height: 46,
        alignment: Alignment.bottomCenter,
        child: const _WaypointPin(label: 'A', color: AppColors.secondary),
      ));
    }
    for (int i = 0; i < _stopPts.length; i++) {
      if (_stopPts[i] != null) {
        markers.add(Marker(
          point: _stopPts[i]!,
          width: 36,
          height: 46,
          alignment: Alignment.bottomCenter,
          child: _WaypointPin(label: '${i + 1}', color: AppColors.accentDark),
        ));
      }
    }
    if (_toPt != null) {
      markers.add(Marker(
        point: _toPt!,
        width: 36,
        height: 46,
        alignment: Alignment.bottomCenter,
        child: const _WaypointPin(label: 'B', color: AppColors.primary),
      ));
    }

    return markers;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route planner bottom panel
// ─────────────────────────────────────────────────────────────────────────────

class _RoutePlannerPanel extends StatelessWidget {
  final String fromLabel;
  final String toLabel;
  final List<String> stopLabels;
  final OsrmRoute? route;
  final bool routing;
  final bool hasAny;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final void Function(int i) onPickStop;
  final VoidCallback onAddStop;
  final void Function(int i) onRemoveStop;
  final VoidCallback onCalculate;
  final VoidCallback? onClear;

  const _RoutePlannerPanel({
    required this.fromLabel,
    required this.toLabel,
    required this.stopLabels,
    required this.route,
    required this.routing,
    required this.hasAny,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onPickStop,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onCalculate,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canRoute = fromLabel.isNotEmpty && toLabel.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      elevation: 12,
      shadowColor: Colors.black26,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 10, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Plan Bus Route', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gray,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),

          // Waypoints
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _WaypointTile(
                  dotColor: AppColors.secondary,
                  label: 'FROM',
                  value: fromLabel,
                  hint: 'Choose starting point',
                  showConnector: true,
                  onTap: onPickFrom,
                ),
                for (int i = 0; i < stopLabels.length; i++) ...[
                  _WaypointTile(
                    dotColor: AppColors.accentDark,
                    label: 'STOP ${i + 1}',
                    value: stopLabels[i],
                    hint: 'Search for a pickup stop',
                    showConnector: true,
                    onTap: () => onPickStop(i),
                    trailing: IconButton(
                      onPressed: () => onRemoveStop(i),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: AppColors.gray,
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Remove stop',
                    ),
                  ),
                ],
                _WaypointTile(
                  dotColor: AppColors.primary,
                  label: 'TO',
                  value: toLabel,
                  hint: 'Choose destination',
                  showConnector: false,
                  onTap: onPickTo,
                ),
              ],
            ),
          ),

          // Actions row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onAddStop,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: const Text('Add Stop'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (canRoute)
                  FilledButton.icon(
                    onPressed: routing ? null : onCalculate,
                    icon: routing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.route_rounded, size: 16),
                    label: Text(routing ? 'Routing…' : 'Get Route'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Route info
          if (route != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBadge(
                    icon: Icons.straighten_rounded,
                    value: route!.distanceLabel,
                    sub: 'Distance',
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.lightGray,
                  ),
                  _StatBadge(
                    icon: Icons.schedule_rounded,
                    value: route!.etaLabel,
                    sub: 'Drive time',
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waypoint tile (row in the panel)
// ─────────────────────────────────────────────────────────────────────────────

class _WaypointTile extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;
  final String hint;
  final bool showConnector;
  final VoidCallback onTap;
  final Widget? trailing;

  const _WaypointTile({
    required this.dotColor,
    required this.label,
    required this.value,
    required this.hint,
    required this.showConnector,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dot + connector line
        SizedBox(
          width: 24,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.35),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (showConnector)
                Container(
                  width: 2,
                  height: 30,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Text
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 6, 10, showConnector ? 10 : 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lightGray,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEmpty ? hint : value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isEmpty ? FontWeight.w400 : FontWeight.w600,
                      color: isEmpty ? AppColors.lightGray : AppColors.dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final String title;
  final LatLng? nearHint;
  final void Function(String label, LatLng pt) onPicked;

  const _LocationPickerSheet({
    required this.title,
    required this.onPicked,
    this.nearHint,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<PhotonResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final r = await PhotonService.search(q, near: widget.nearHint);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    });
  }

  void _pick(String label, LatLng pt) {
    Navigator.of(context).pop();
    widget.onPicked(label, pt);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search for a place or address…',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.gray,
                  ),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Use my location
            if (widget.nearHint != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _pick('My Location', widget.nearHint!),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Use my current location'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),

            const SizedBox(height: 6),

            // Results area
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenH * 0.4),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                  ),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.place_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        r.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: r.subtitle.isNotEmpty
                          ? Text(
                              r.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => _pick(r.name, r.location),
                      dense: true,
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Center(
                  child: Text(
                    _ctrl.text.length < 2
                        ? 'Type at least 2 characters to search'
                        : 'No results found',
                    style: const TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WaypointPin extends StatelessWidget {
  final String label;
  final Color color;

  const _WaypointPin({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(2)),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _BlueDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x441565C0),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String sub;

  const _StatBadge({required this.icon, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.gray,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
