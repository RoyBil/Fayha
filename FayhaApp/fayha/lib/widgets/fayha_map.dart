import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// Smoothly animates the camera (center + zoom) of a [MapController].
Future<void> smoothMove(
  TickerProvider vsync,
  MapController controller,
  LatLng target,
  double targetZoom, {
  Duration duration = const Duration(milliseconds: 700),
  Curve curve = Curves.easeInOutCubic,
}) async {
  final camera = controller.camera;
  final lat0 = camera.center.latitude;
  final lng0 = camera.center.longitude;
  final z0 = camera.zoom;
  final ac = AnimationController(vsync: vsync, duration: duration);
  final curved = CurvedAnimation(parent: ac, curve: curve);
  void tick() {
    final t = curved.value;
    controller.move(
      LatLng(
        lat0 + (target.latitude - lat0) * t,
        lng0 + (target.longitude - lng0) * t,
      ),
      z0 + (targetZoom - z0) * t,
    );
  }

  ac.addListener(tick);
  try {
    await ac.forward();
  } finally {
    ac.removeListener(tick);
    ac.dispose();
  }
}

class MapPin {
  final LatLng point;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  const MapPin({
    required this.point,
    required this.color,
    required this.label,
    this.onTap,
    this.icon = Icons.location_on,
  });
}

/// The shared Fayha map — OpenStreetMap/CARTO tiles, dot pins,
/// optional route polylines, and zoom controls. Same look as the
/// audience map.
class FayhaMap extends StatefulWidget {
  final MapController controller;
  final List<MapPin> pins;
  final List<Polyline> polylines;
  final LatLng center;
  final double zoom;
  final double? height;

  const FayhaMap({
    super.key,
    required this.controller,
    required this.pins,
    this.polylines = const [],
    required this.center,
    required this.zoom,
    this.height,
  });

  @override
  State<FayhaMap> createState() => _FayhaMapState();
}

class _FayhaMapState extends State<FayhaMap> with TickerProviderStateMixin {
  void _zoom(double delta) {
    final c = widget.controller.camera;
    final newZoom = (c.zoom + delta).clamp(2.0, 20.0);
    smoothMove(
      this,
      widget.controller,
      c.center,
      newZoom,
      duration: const Duration(milliseconds: 350),
    );
  }

  void _recenter() {
    smoothMove(this, widget.controller, widget.center, widget.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final mapHeight = widget.height ?? (screenH * 0.40).clamp(220.0, 380.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: mapHeight,
          child: Stack(
            children: [
              FlutterMap(
                mapController: widget.controller,
                options: MapOptions(
                  initialCenter: widget.center,
                  initialZoom: widget.zoom,
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
                  if (widget.polylines.isNotEmpty)
                    PolylineLayer(polylines: widget.polylines),
                  MarkerLayer(
                    markers: widget.pins
                        .map(
                          (p) => Marker(
                            point: p.point,
                            width: 140,
                            height: 60,
                            alignment: Alignment.center,
                            rotate: false,
                            child: GestureDetector(
                              onTap: p.onTap,
                              child: _PinMarker(label: p.label, color: p.color),
                            ),
                          ),
                        )
                        .toList(),
                  ),
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
                    _ZoomButton(icon: Icons.add, onTap: () => _zoom(1)),
                    const SizedBox(height: 8),
                    _ZoomButton(icon: Icons.remove, onTap: () => _zoom(-1)),
                    const SizedBox(height: 8),
                    _ZoomButton(icon: Icons.my_location, onTap: _recenter),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  final String label;
  final Color color;
  const _PinMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 18,
          height: 18,
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
        ),
        Positioned(
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                fontSize: 10,
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

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

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
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Bottom-sheet info card — same style as the audience map.
class MapInfoSheet extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<MapFact> facts;
  final String? description;
  final String? mapUrl;
  final VoidCallback? onOpenMap;

  const MapInfoSheet({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.facts,
    this.description,
    this.mapUrl,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.32,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(icon, color: AppColors.cream, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.cream.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.offWhite),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < facts.length; i++) ...[
                      if (i > 0) const Divider(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              facts[i].icon,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    facts[i].label,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    facts[i].value,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.offWhite),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    description!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  if (onOpenMap != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpenMap,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Google Maps'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapFact {
  final IconData icon;
  final String label;
  final String value;
  const MapFact(this.icon, this.label, this.value);
}
