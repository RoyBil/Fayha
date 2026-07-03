import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/bus_route_models.dart';
import '../../services/bus_route_service.dart';
import '../../services/google_places_service.dart';
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

  static const _defaultCenter = LatLng(34.05, 35.7); // Lebanon

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
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _startName.dispose();
    _endName.dispose();
    super.dispose();
  }

  void _handleTap(LatLng p) {
    setState(() {
      switch (_mode) {
        case _PickMode.start:
          _start = p;
          _mode = _PickMode.stop;
          break;
        case _PickMode.end:
          _end = p;
          break;
        case _PickMode.stop:
          _stops.add(
            _EditableStop(name: 'Stop ${_stops.length + 1}', location: p),
          );
          break;
      }
    });
  }

  /// Opens a Places search sheet. When the user picks a result we
  /// apply it according to the current mode (start / stop / end).
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
    if (picked == null) return;
    setState(() {
      switch (_mode) {
        case _PickMode.start:
          _start = picked.location;
          if (_startName.text.trim().isEmpty) _startName.text = picked.name;
          _mode = _PickMode.stop;
          break;
        case _PickMode.end:
          _end = picked.location;
          if (_endName.text.trim().isEmpty) _endName.text = picked.name;
          break;
        case _PickMode.stop:
          _stops.add(
            _EditableStop(name: picked.name, location: picked.location),
          );
          break;
      }
    });
    _mapCtrl.move(picked.location, 15.5);
  }

  Future<void> _editStop(int i) async {
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
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      setState(() {
        s.name = nameCtrl.text.trim().isEmpty ? s.name : nameCtrl.text.trim();
        s.geofenceRadiusM = int.tryParse(geoCtrl.text) ?? s.geofenceRadiusM;
        s.approachRadiusM = int.tryParse(appCtrl.text) ?? s.approachRadiusM;
      });
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _startName.text.trim().isEmpty ||
        _endName.text.trim().isEmpty) {
      _toast('Please fill in route, start and end names.');
      return;
    }
    if (_start == null || _end == null) {
      _toast('Tap the map to set both start and end points.');
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
          startPoint: _start!,
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

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (_start != null)
        Marker(
          point: _start!,
          width: 36,
          height: 36,
          child: const Icon(Icons.flag, color: AppColors.secondary, size: 32),
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
                border: Border.all(color: Colors.white, width: 2),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Route name',
                    isDense: true,
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
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ModeBar(
            mode: _mode,
            onMode: (m) => setState(() => _mode = m),
            stopCount: _stops.length,
            onSearch: _searchPlace,
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _start ?? _defaultCenter,
                initialZoom: 12,
                onTap: (_, p) => _handleTap(p),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.fayhanationalchoir.app',
                  additionalOptions: const {'r': ''},
                ),
                if (_start != null && _end != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          _start!,
                          ..._stops.map((s) => s.location),
                          _end!,
                        ],
                        color: AppColors.primary.withValues(alpha: 0.45),
                        strokeWidth: 3,
                        pattern: StrokePattern.dashed(segments: const [8, 6]),
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          _StopsStrip(
            stops: _stops,
            onRemove: (i) => setState(() => _stops.removeAt(i)),
            onMoveUp: (i) {
              if (i == 0) return;
              setState(() {
                final t = _stops.removeAt(i);
                _stops.insert(i - 1, t);
              });
            },
            onMoveDown: (i) {
              if (i == _stops.length - 1) return;
              setState(() {
                final t = _stops.removeAt(i);
                _stops.insert(i + 1, t);
              });
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

/// Bottom sheet that drives Google Places autocomplete. Returns the
/// picked [PlaceDetail] via Navigator.pop.
class _PlacesSearchSheet extends StatefulWidget {
  final LatLng near;
  const _PlacesSearchSheet({required this.near});

  @override
  State<_PlacesSearchSheet> createState() => _PlacesSearchSheetState();
}

class _PlacesSearchSheetState extends State<_PlacesSearchSheet> {
  final _ctrl = TextEditingController();
  List<PlaceSuggestion> _results = const [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() => _searching = true);
    final res = await GooglePlacesService.autocomplete(q, near: widget.near);
    if (!mounted) return;
    setState(() {
      _results = res;
      _searching = false;
    });
  }

  Future<void> _pick(PlaceSuggestion s) async {
    setState(() => _searching = true);
    final d = await GooglePlacesService.details(s.placeId);
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
                hintText: 'Search universities, landmarks, cafés…',
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
            if (GooglePlacesService.apiKey == null ||
                GooglePlacesService.apiKey!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Places search needs a Google API key. '
                  'Set GooglePlacesService.apiKey at app boot.',
                  style: TextStyle(color: AppColors.gray, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_results.isEmpty &&
                _ctrl.text.trim().isNotEmpty &&
                !_searching)
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
                  final s = _results[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      s.primaryText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: s.secondaryText.isEmpty
                        ? null
                        : Text(s.secondaryText),
                    onTap: () => _pick(s),
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
