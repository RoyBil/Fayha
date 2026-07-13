import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/nominatim_service.dart';
import '../../services/osrm_service.dart';
import '../../services/photon_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fayha_map.dart' show smoothMove;

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point widget
// ─────────────────────────────────────────────────────────────────────────────

class NavigateTab extends StatefulWidget {
  const NavigateTab({super.key});

  @override
  State<NavigateTab> createState() => _NavigateTabState();
}

class _NavigateTabState extends State<NavigateTab>
    with TickerProviderStateMixin {
  static const _defaultCenter = LatLng(34.05, 35.7);
  static const _defaultZoom = 10.0;

  final _ctrl = MapController();

  // Search state
  final _startCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _startFocus = FocusNode();
  final _destFocus = FocusNode();
  bool _editingStart = false;
  List<PhotonResult> _suggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;

  // Location + routing state
  LatLng? _currentLocation;
  LatLng? _start;
  LatLng? _destination;
  OsrmRoute? _route;
  bool _locating = false;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _startFocus.addListener(_onFocusChange);
    _destFocus.addListener(_onFocusChange);
    _fetchCurrentLocation(centerOnIt: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _startCtrl.dispose();
    _destCtrl.dispose();
    _startFocus.removeListener(_onFocusChange);
    _destFocus.removeListener(_onFocusChange);
    _startFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_startFocus.hasFocus) setState(() => _editingStart = true);
    if (_destFocus.hasFocus) setState(() => _editingStart = false);
    if (!_startFocus.hasFocus && !_destFocus.hasFocus) {
      setState(() => _suggestions = []);
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _fetchCurrentLocation({bool centerOnIt = false}) async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'Location services are off';

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLocation = here;
        if (_start == null) {
          _start = here;
          _startCtrl.text = 'My Location';
        }
      });
      if (centerOnIt) smoothMove(this, _ctrl, here, 14.0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location: $e'), duration: const Duration(seconds: 3)),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _goToCurrentLocation() {
    if (_currentLocation != null) {
      smoothMove(this, _ctrl, _currentLocation!, 16.0);
    } else {
      _fetchCurrentLocation(centerOnIt: true);
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _loadingSuggestions = true);
      final results = await PhotonService.search(
        q,
        near: _currentLocation ?? _start,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loadingSuggestions = false;
      });
    });
  }

  Future<void> _selectSuggestion(PhotonResult r) async {
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = []);
    if (_editingStart) {
      setState(() {
        _start = r.location;
        _startCtrl.text = r.name;
      });
    } else {
      setState(() {
        _destination = r.location;
        _destCtrl.text = r.name;
      });
    }
    smoothMove(this, _ctrl, r.location, 15.0);
    await _computeRoute();
  }

  // ── Map tap (reverse geocode → set destination) ───────────────────────────

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _destination = point;
      _destCtrl.text = 'Loading…';
      _suggestions = [];
    });
    final result = await NominatimService.reverse(point);
    if (!mounted) return;
    final label = result?.shortName.isNotEmpty == true
        ? result!.shortName
        : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    setState(() => _destCtrl.text = label);
    await _computeRoute();
  }

  // ── Routing ───────────────────────────────────────────────────────────────

  Future<void> _computeRoute() async {
    final start = _start ?? _currentLocation;
    final dest = _destination;
    if (start == null || dest == null) return;

    setState(() {
      _routing = true;
      _route = null;
    });
    final r = await OsrmService.route(start, dest);
    if (!mounted) return;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find a driving route between those points.'),
        ),
      );
    }
    setState(() {
      _route = r;
      _routing = false;
    });
  }

  void _clearRoute() {
    setState(() {
      _route = null;
      _destination = null;
      _destCtrl.clear();
      _suggestions = [];
    });
  }

  void _swapPoints() {
    final oldStart = _start;
    final oldStartText = _startCtrl.text;
    setState(() {
      _start = _destination;
      _startCtrl.text = _destCtrl.text;
      _destination = oldStart;
      _destCtrl.text = oldStartText;
      _route = null;
    });
    _computeRoute();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showSuggestions =
        _suggestions.isNotEmpty &&
        (_startFocus.hasFocus || _destFocus.hasFocus);

    final markers = _buildMarkers();
    final polylines = _route != null
        ? [
            Polyline(
              points: _route!.polyline,
              color: AppColors.primary,
              strokeWidth: 4.5,
              borderColor: Colors.white,
              borderStrokeWidth: 1.5,
            ),
          ]
        : <Polyline>[];

    return Stack(
      children: [
        // ── Map ──────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _ctrl,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: _defaultZoom,
            minZoom: 2,
            maxZoom: 20,
            onTap: _onMapTap,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fayhanationalchoir.app',
              maxNativeZoom: 19,
              maxZoom: 20,
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // ── Search panel ─────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchCard(
                    startCtrl: _startCtrl,
                    destCtrl: _destCtrl,
                    startFocus: _startFocus,
                    destFocus: _destFocus,
                    onStartChanged: _onSearchChanged,
                    onDestChanged: _onSearchChanged,
                    onSwap: _swapPoints,
                    onClear: _destination != null ? _clearRoute : null,
                    routing: _routing,
                    locating: _locating,
                  ),
                  if (showSuggestions || _loadingSuggestions) ...[
                    const SizedBox(height: 4),
                    _SuggestionsDropdown(
                      results: _suggestions,
                      loading: _loadingSuggestions,
                      onSelect: _selectSuggestion,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Route info card ───────────────────────────────────────────────────
        if (_route != null)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: _RouteInfoCard(
              route: _route!,
              onClear: _clearRoute,
            ),
          ),

        // ── FABs ──────────────────────────────────────────────────────────────
        Positioned(
          right: 12,
          bottom: _route != null ? 130 : 20,
          child: _MapFabs(
            locating: _locating,
            onMyLocation: _goToCurrentLocation,
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Blue dot — current GPS position
    if (_currentLocation != null) {
      markers.add(Marker(
        point: _currentLocation!,
        width: 22,
        height: 22,
        child: _CurrentLocationDot(),
      ));
    }

    // Green start marker (when explicitly set and different from current GPS)
    final startPt = _start;
    if (startPt != null &&
        (_currentLocation == null || startPt != _currentLocation)) {
      markers.add(Marker(
        point: startPt,
        width: 34,
        height: 40,
        alignment: Alignment.bottomCenter,
        child: const _PinIcon(color: AppColors.secondary),
      ));
    }

    // Red destination marker
    if (_destination != null) {
      markers.add(Marker(
        point: _destination!,
        width: 34,
        height: 40,
        alignment: Alignment.bottomCenter,
        child: const _PinIcon(color: AppColors.primary),
      ));
    }

    return markers;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SearchCard extends StatelessWidget {
  final TextEditingController startCtrl;
  final TextEditingController destCtrl;
  final FocusNode startFocus;
  final FocusNode destFocus;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onDestChanged;
  final VoidCallback onSwap;
  final VoidCallback? onClear;
  final bool routing;
  final bool locating;

  const _SearchCard({
    required this.startCtrl,
    required this.destCtrl,
    required this.startFocus,
    required this.destFocus,
    required this.onStartChanged,
    required this.onDestChanged,
    required this.onSwap,
    required this.routing,
    required this.locating,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Waypoint icons column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.my_location, size: 18, color: AppColors.secondary),
                Container(
                  width: 2,
                  height: 22,
                  color: AppColors.lightGray,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                ),
                Icon(Icons.location_pin, size: 18, color: AppColors.primary),
              ],
            ),
            const SizedBox(width: 10),
            // Text fields column
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Field(
                    controller: startCtrl,
                    focusNode: startFocus,
                    hint: locating ? 'Getting location…' : 'Start (my location)',
                    onChanged: onStartChanged,
                    suffix: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  _Field(
                    controller: destCtrl,
                    focusNode: destFocus,
                    hint: 'Search destination or tap map',
                    onChanged: onDestChanged,
                    suffix: routing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : onClear != null
                            ? GestureDetector(
                                onTap: onClear,
                                child: const Icon(Icons.close, size: 16, color: AppColors.gray),
                              )
                            : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Swap button
            IconButton(
              onPressed: onSwap,
              icon: const Icon(Icons.swap_vert, color: AppColors.primary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Swap start and destination',
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: AppColors.dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.lightGray),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: suffix,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}

class _SuggestionsDropdown extends StatelessWidget {
  final List<PhotonResult> results;
  final bool loading;
  final ValueChanged<PhotonResult> onSelect;

  const _SuggestionsDropdown({
    required this.results,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: Colors.black26,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: loading && results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = results[i];
                    return InkWell(
                      onTap: () => onSelect(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.dark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (r.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      r.subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.gray,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _RouteInfoCard extends StatelessWidget {
  final OsrmRoute route;
  final VoidCallback onClear;

  const _RouteInfoCard({required this.route, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _InfoBadge(
                    icon: Icons.straighten,
                    value: route.distanceLabel,
                    label: 'Distance',
                  ),
                  const SizedBox(width: 24),
                  _InfoBadge(
                    icon: Icons.schedule,
                    value: route.etaLabel,
                    label: 'Drive time',
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              tooltip: 'Clear route',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoBadge({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapFabs extends StatelessWidget {
  final bool locating;
  final VoidCallback onMyLocation;

  const _MapFabs({required this.locating, required this.onMyLocation});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onMyLocation,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 20, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x441565C0), blurRadius: 8, spreadRadius: 2),
        ],
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  final Color color;
  const _PinIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_pin, color: color, size: 34, shadows: const [
      Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
    ]);
  }
}
