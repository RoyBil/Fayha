import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_route_models.dart';
import '../../services/bus_route_service.dart';
import '../../services/google_places_service.dart';
import '../../services/nominatim_service.dart';
import '../../services/osrm_service.dart';
import '../../services/photon_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Admin route editor.
///
/// Workflow: tap on the map to drop start → stops → end. Reorder or
/// rename stops in the bottom sheet. Hit Save to upsert and fetch a
/// Google Directions polyline (or fall back to straight-line in dev).
class BusRouteEditorScreen extends StatefulWidget {
  final BusRoute? existing;
  const BusRouteEditorScreen({super.key, this.existing});

  @override
  State<BusRouteEditorScreen> createState() => _BusRouteEditorScreenState();
}

enum _PickMode { start, stop, end }

class _EditableStop {
  String name;
  LatLng location;
  int geofenceRadiusM;
  int approachRadiusM;
  _EditableStop({
    required this.name,
    required this.location,
    this.geofenceRadiusM = 200,
    this.approachRadiusM = 800,
  });
}

class _BusRouteEditorScreenState extends State<BusRouteEditorScreen> {
  final _name = TextEditingController();
  final _startName = TextEditingController();
  final _endName = TextEditingController();
  final _mapCtrl = MapController();

  LatLng? _start;
  LatLng? _end;
  final List<_EditableStop> _stops = [];
  _PickMode _mode = _PickMode.start;
  bool _saving = false;

  // Live OSRM route preview
  OsrmRoute? _preview;
  bool _previewLoading = false;
  Timer? _recalcDebounce;

  static const _defaultCenter = LatLng(34.05, 35.7);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _startName.text = e.startName;
      _endName.text = e.endName;
      _start = e.startPoint;
      _end = e.endPoint;
      _stops.addAll(
        e.stops.map(
          (s) => _EditableStop(
            name: s.name,
            location: s.location,
            geofenceRadiusM: s.geofenceRadiusM,
            approachRadiusM: s.approachRadiusM,
          ),
        ),
      );
      _mode = _PickMode.stop;
      _scheduleRecalc();
    }
  }

  @override
  void dispose() {
    _recalcDebounce?.cancel();
    _name.dispose();
    _startName.dispose();
    _endName.dispose();
    super.dispose();
  }

  // ── OSRM live preview ──────────────────────────────────────────────

  void _scheduleRecalc() {
    _recalcDebounce?.cancel();
    _recalcDebounce = Timer(const Duration(milliseconds: 400), _recalcRoute);
  }

  Future<void> _recalcRoute() async {
    final s = _start;
    final e = _end;
    if (s == null || e == null) {
      _fitBounds();
      return;
    }
    setState(() => _previewLoading = true);
    final waypoints = _stops.map((st) => st.location).toList();
    final result = await OsrmService.route(s, e, waypoints: waypoints);
    if (!mounted) return;
    setState(() {
      _preview = result;
      _previewLoading = false;
    });
    _fitBounds();
  }

  void _fitBounds() {
    final points = <LatLng>[
      if (_start != null) _start!,
      ..._stops.map((s) => s.location),
      if (_end != null) _end!,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      try {
        _mapCtrl.move(points.first, 14);
      } catch (_) {}
      return;
    }
    try {
      _mapCtrl.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {}
  }

  // ── Map interactions ───────────────────────────────────────────────

  Future<void> _handleTap(LatLng p) async {
    final originalMode = _mode;

    if (originalMode == _PickMode.stop &&
        _stops.any((s) => _sameSpot(s.location, p))) {
      return;
    }

    // Place immediately with placeholder name
    setState(() {
      switch (originalMode) {
        case _PickMode.start:
          _start = p;
          _mode = _PickMode.stop;
        case _PickMode.end:
          _end = p;
        case _PickMode.stop:
          _stops.add(
            _EditableStop(name: 'Stop ${_stops.length + 1}', location: p),
          );
      }
    });
    _scheduleRecalc();

    // Reverse geocode and refine name
    final geo = await NominatimService.reverse(p);
    if (!mounted || geo == null || geo.shortName.isEmpty) return;
    setState(() {
      switch (originalMode) {
        case _PickMode.start:
          if (_startName.text.trim().isEmpty) _startName.text = geo.shortName;
        case _PickMode.end:
          if (_endName.text.trim().isEmpty) _endName.text = geo.shortName;
        case _PickMode.stop:
          for (final s in _stops) {
            if (_sameSpot(s.location, p) && s.name.startsWith('Stop ')) {
              s.name = geo.shortName;
              break;
            }
          }
      }
    });
  }

  bool _sameSpot(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 0.00009 &&
      (a.longitude - b.longitude).abs() < 0.00009;

  Future<void> _searchPlace() async {
    final picked = await showModalBottomSheet<PlaceDetail>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PlacesSearchSheet(near: _start ?? _defaultCenter),
    );
    if (!mounted || picked == null) return;
    setState(() {
      switch (_mode) {
        case _PickMode.start:
          _start = picked.location;
          if (_startName.text.trim().isEmpty) _startName.text = picked.name;
          _mode = _PickMode.stop;
        case _PickMode.end:
          _end = picked.location;
          if (_endName.text.trim().isEmpty) _endName.text = picked.name;
        case _PickMode.stop:
          if (!_stops.any((s) => _sameSpot(s.location, picked.location))) {
            _stops.add(
              _EditableStop(name: picked.name, location: picked.location),
            );
          }
      }
    });
    _scheduleRecalc();
    try {
      _mapCtrl.move(picked.location, 15);
    } catch (_) {}
  }

  // ── Stop editing ───────────────────────────────────────────────────

  Future<void> _editStop(int i) async {
    if (i < 0 || i >= _stops.length) return;
    final s = _stops[i];
    final nameCtrl = TextEditingController(text: s.name);
    final geoCtrl = TextEditingController(text: s.geofenceRadiusM.toString());
    final appCtrl = TextEditingController(text: s.approachRadiusM.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            TextField(
              controller: geoCtrl,
              decoration: const InputDecoration(
                labelText: 'Geofence radius (m)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: appCtrl,
              decoration: const InputDecoration(
                labelText: 'Approach radius (m)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Read values before disposing controllers
    if (result == true && mounted) {
      final newName = nameCtrl.text.trim();
      final newGeo = int.tryParse(geoCtrl.text);
      final newApp = int.tryParse(appCtrl.text);
      setState(() {
        s.name = newName.isEmpty ? s.name : newName;
        if (newGeo != null) s.geofenceRadiusM = newGeo;
        if (newApp != null) s.approachRadiusM = newApp;
      });
    }
    nameCtrl.dispose();
    geoCtrl.dispose();
    appCtrl.dispose();
  }

  // ── Save / Delete ──────────────────────────────────────────────────

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _startName.text.trim().isEmpty ||
        _endName.text.trim().isEmpty) {
      _toast('Fill in route name, start name, and end name.');
      return;
    }
    if (_start == null || _end == null) {
      _toast('Set both start and end points on the map.');
      return;
    }
    setState(() => _saving = true);
    try {
      final me = AppState.instance.currentMember!;
      final stops = _stops
          .map(
            (s) => (
              name: s.name,
              location: s.location,
              geofenceRadiusM: s.geofenceRadiusM as int?,
              approachRadiusM: s.approachRadiusM as int?,
            ),
          )
          .toList();

      if (widget.existing == null) {
        await BusRouteService.create(
          branch: me.branch,
          name: _name.text.trim(),
          startName: _startName.text.trim(),
          startPoint: _start!,
          endName: _endName.text.trim(),
          endPoint: _end!,
          stops: stops,
        );
      } else {
        await BusRouteService.updateStopsAndPolyline(
          routeId: widget.existing!.id,
          name: _name.text.trim(),
          startName: _startName.text.trim(),
          startPoint: _start!,
          endName: _endName.text.trim(),
          endPoint: _end!,
          stops: stops,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _toast('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete route?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BusRouteService.deleteRoute(e.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (err) {
      _toast('Delete failed: $err');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allPoints = <LatLng>[
      if (_start != null) _start!,
      ..._stops.map((s) => s.location),
      if (_end != null) _end!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Route' : 'Edit Route'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Delete route',
              icon: const Icon(Icons.delete_outline, color: AppColors.primary),
              onPressed: _delete,
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Route metadata ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Route name',
                    isDense: true,
                    prefixIcon: Icon(Icons.route, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startName,
                        decoration: const InputDecoration(
                          labelText: 'Start name',
                          isDense: true,
                          prefixIcon: Icon(Icons.flag_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _endName,
                        decoration: const InputDecoration(
                          labelText: 'End name',
                          isDense: true,
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Mode bar ───────────────────────────────────────────────
          _ModeBar(
            mode: _mode,
            onMode: (m) => setState(() => _mode = m),
            stopCount: _stops.length,
            onSearch: _searchPlace,
          ),
          // ── Map ────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _start ?? _defaultCenter,
                    initialZoom: 12,
                    maxZoom: 20,
                    onTap: (_, p) => _handleTap(p),
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
                    // OSRM road-following polyline
                    if (_preview != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _preview!.polyline,
                            color: AppColors.primary,
                            strokeWidth: 5,
                            borderColor: Colors.white,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      )
                    // Dashed fallback before OSRM resolves
                    else if (allPoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: allPoints,
                            color: AppColors.primary.withValues(alpha: 0.4),
                            strokeWidth: 3,
                            pattern: StrokePattern.dashed(
                              segments: const [8, 6],
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (_start != null)
                          Marker(
                            point: _start!,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.flag,
                              color: AppColors.secondary,
                              size: 32,
                            ),
                          ),
                        if (_end != null)
                          Marker(
                            point: _end!,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                        for (var i = 0; i < _stops.length; i++)
                          Marker(
                            point: _stops[i].location,
                            width: 30,
                            height: 30,
                            child: GestureDetector(
                              onTap: () => _editStop(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                // Routing indicator (top-right)
                if (_previewLoading)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Routing…', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Fit-bounds button (bottom-right)
                Positioned(
                  right: 12,
                  bottom: _preview != null ? 70 : 12,
                  child: FloatingActionButton.small(
                    heroTag: 'editor_fit',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    onPressed: allPoints.isNotEmpty ? _fitBounds : null,
                    child: const Icon(Icons.fit_screen),
                  ),
                ),
                // Route info card (bottom)
                if (_preview != null)
                  Positioned(
                    left: 12,
                    right: 60,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
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
                            Icons.route,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _preview!.distanceLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _preview!.etaLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_stops.length} stop${_stops.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Stops strip ────────────────────────────────────────────
          _StopsStrip(
            stops: _stops,
            onRemove: (i) {
              setState(() => _stops.removeAt(i));
              _scheduleRecalc();
            },
            onMoveUp: (i) {
              if (i == 0) return;
              setState(() {
                final t = _stops.removeAt(i);
                _stops.insert(i - 1, t);
              });
              _scheduleRecalc();
            },
            onMoveDown: (i) {
              if (i == _stops.length - 1) return;
              setState(() {
                final t = _stops.removeAt(i);
                _stops.insert(i + 1, t);
              });
              _scheduleRecalc();
            },
            onTap: _editStop,
          ),
        ],
      ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  final _PickMode mode;
  final ValueChanged<_PickMode> onMode;
  final int stopCount;
  final VoidCallback onSearch;
  const _ModeBar({
    required this.mode,
    required this.onMode,
    required this.stopCount,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(_PickMode m, String label, IconData icon) {
      final selected = mode == m;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          selected: selected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.gray,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.charcoal,
                ),
              ),
            ],
          ),
          selectedColor: AppColors.primary,
          onSelected: (_) => onMode(m),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          chip(_PickMode.start, 'Start', Icons.flag_outlined),
          chip(_PickMode.stop, 'Stops ($stopCount)', Icons.add_location_alt),
          chip(_PickMode.end, 'End', Icons.location_on_outlined),
          const Spacer(),
          IconButton(
            tooltip: 'Search places',
            icon: const Icon(Icons.search),
            color: AppColors.primary,
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for location search.
/// Uses Google Places when an API key is configured; falls back to
/// Photon (free, no key) otherwise. Always returns a [PlaceDetail].
class _PlacesSearchSheet extends StatefulWidget {
  final LatLng near;
  const _PlacesSearchSheet({required this.near});

  @override
  State<_PlacesSearchSheet> createState() => _PlacesSearchSheetState();
}

class _PlacesSearchSheetState extends State<_PlacesSearchSheet> {
  final _ctrl = TextEditingController();
  List<_SearchHit> _results = const [];
  bool _searching = false;
  Timer? _debounce;

  bool get _hasGoogleKey => (GooglePlacesService.apiKey?.isNotEmpty ?? false);

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() => _searching = true);
    if (_hasGoogleKey) {
      final res = await GooglePlacesService.autocomplete(q, near: widget.near);
      if (!mounted) return;
      setState(() {
        _results = res.map(_SearchHit.fromGoogle).toList();
        _searching = false;
      });
    } else {
      final res = await PhotonService.search(q, near: widget.near);
      if (!mounted) return;
      setState(() {
        _results = res.map(_SearchHit.fromPhoton).toList();
        _searching = false;
      });
    }
  }

  Future<void> _pick(_SearchHit hit) async {
    if (hit.resolved != null) {
      Navigator.pop(context, hit.resolved);
      return;
    }
    // Google Places — resolve coordinates via details call
    setState(() => _searching = true);
    final d = await GooglePlacesService.details(hit.placeId!);
    if (!mounted) return;
    setState(() => _searching = false);
    if (d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load place details.')),
      );
      return;
    }
    Navigator.pop(context, d);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search universities, landmarks, streets…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 10),
            if (_results.isEmpty && _ctrl.text.trim().isNotEmpty && !_searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No matches.'),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    Divider(color: AppColors.lightGray.withValues(alpha: 0.5)),
                itemBuilder: (_, i) {
                  final hit = _results[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      hit.primaryText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: hit.secondaryText.isEmpty
                        ? null
                        : Text(hit.secondaryText),
                    onTap: () => _pick(hit),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified search result that works for both Google Places and Photon.
class _SearchHit {
  final String primaryText;
  final String secondaryText;
  final String? placeId; // set when coming from Google Places
  final PlaceDetail?
  resolved; // set when coming from Photon (no extra call needed)

  const _SearchHit({
    required this.primaryText,
    required this.secondaryText,
    this.placeId,
    this.resolved,
  });

  factory _SearchHit.fromGoogle(PlaceSuggestion s) => _SearchHit(
    primaryText: s.primaryText,
    secondaryText: s.secondaryText,
    placeId: s.placeId,
  );

  factory _SearchHit.fromPhoton(PhotonResult p) => _SearchHit(
    primaryText: p.name,
    secondaryText: p.subtitle,
    resolved: PlaceDetail(
      placeId: '',
      name: p.name,
      address: p.subtitle,
      location: p.location,
    ),
  );
}

class _StopsStrip extends StatelessWidget {
  final List<_EditableStop> stops;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onMoveUp;
  final ValueChanged<int> onMoveDown;
  final ValueChanged<int> onTap;
  const _StopsStrip({
    required this.stops,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No stops yet — switch to "Stops" mode and tap the map.',
          style: TextStyle(color: AppColors.gray, fontSize: 12),
        ),
      );
    }
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: stops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = stops[i];
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.lightGray.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.accent,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _MiniIconButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => onMoveUp(i),
                      ),
                      _MiniIconButton(
                        icon: Icons.arrow_forward_ios,
                        onTap: () => onMoveDown(i),
                      ),
                      const Spacer(),
                      _MiniIconButton(
                        icon: Icons.close,
                        onTap: () => onRemove(i),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _MiniIconButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: color ?? AppColors.gray),
      ),
    );
  }
}
