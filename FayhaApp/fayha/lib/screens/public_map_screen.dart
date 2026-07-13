import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/map_data.dart';
import '../services/audience_data.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';
import 'branch_detail_screen.dart';

class PublicMapScreen extends StatefulWidget {
  /// When set, the Branches tab auto-focuses on this branch and
  /// opens its info sheet as soon as the map loads. Used by the
  /// "Where We Rehearse" cards on the Events page.
  final String? initialBranchName;
  const PublicMapScreen({super.key, this.initialBranchName});

  @override
  State<PublicMapScreen> createState() => _PublicMapScreenState();
}

class _PublicMapScreenState extends State<PublicMapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.cream,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.gray,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(icon: Icon(Icons.location_city, size: 20), text: 'Branches'),
              Tab(icon: Icon(Icons.public, size: 20), text: 'Venues'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _BranchesTab(initialBranchName: widget.initialBranchName),
              const _VenuesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ============ Map plumbing ============

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

class _MapPin {
  final LatLng point;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _MapPin({
    required this.point,
    required this.color,
    required this.label,
    required this.onTap,
  });
}

class _RealMap extends StatefulWidget {
  final MapController controller;
  final List<_MapPin> pins;
  final LatLng center;
  final double zoom;
  const _RealMap({
    required this.controller,
    required this.pins,
    required this.center,
    required this.zoom,
  });

  @override
  State<_RealMap> createState() => _RealMapState();
}

class _RealMapState extends State<_RealMap> with TickerProviderStateMixin {
  void _zoom(double delta) {
    final c = widget.controller.camera;
    final newZoom = (c.zoom + delta).clamp(2.0, 20.0);
    smoothMove(
      this,
      widget.controller,
      c.center,
      newZoom,
      duration: const Duration(milliseconds: 550),
    );
  }

  void _recenter() {
    smoothMove(
      this,
      widget.controller,
      widget.center,
      widget.zoom,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final mapHeight = (screenH * 0.40).clamp(220.0, 380.0);
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

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

// ============ Info sheet ============

class _InfoSheet extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<_Fact> facts;
  final String? description;
  final String mapUrl;

  const _InfoSheet({
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.facts,
    this.description,
    required this.mapUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
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
              child: ElegantCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < facts.length; i++) ...[
                      if (i > 0) const Divider(height: 18),
                      _factRow(context, facts[i]),
                    ],
                  ],
                ),
              ),
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: ElegantCard(
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _open(mapUrl),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Google Maps'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _factRow(BuildContext context, _Fact f) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(f.icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(f.value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact {
  final IconData icon;
  final String label;
  final String value;
  const _Fact(this.icon, this.label, this.value);
}

void _showInfo(BuildContext context, Widget sheet) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => sheet,
  );
}

// ============ Tabs ============

class _BranchesTab extends StatefulWidget {
  final String? initialBranchName;
  const _BranchesTab({this.initialBranchName});

  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab>
    with TickerProviderStateMixin {
  static const LatLng _defaultCenter = LatLng(34.05, 35.75);
  static const double _defaultZoom = 8.0;
  static const double _focusZoom = 15.0;
  final MapController _ctrl = MapController();
  late Future<List<BranchLocation>> _branches;
  bool _autoFocused = false;

  @override
  void initState() {
    super.initState();
    _branches = AudienceData.fetchBranches();
    final target = widget.initialBranchName;
    if (target != null) {
      _branches.then((list) {
        if (!mounted || _autoFocused) return;
        BranchLocation? match;
        for (final b in list) {
          if (b.name.toLowerCase() == target.toLowerCase()) {
            match = b;
            break;
          }
        }
        if (match == null) return;
        _autoFocused = true;
        // Defer until after the map widget has built so the controller
        // is attached and the sheet can show without context issues.
        WidgetsBinding.instance.addPostFrameCallback((_) => _focus(match!));
      });
    }
  }

  Future<void> _focus(BranchLocation b) async {
    await smoothMove(
      this,
      _ctrl,
      LatLng(b.lat, b.lng),
      _focusZoom,
      duration: const Duration(milliseconds: 1400),
    );
    if (!mounted) return;
    _showInfo(context, _branchSheet(b));
  }

  Widget _branchSheet(BranchLocation b) => _InfoSheet(
    color: b.color,
    icon: Icons.location_city,
    title: '${b.name} Branch',
    subtitle: b.practiceLocation,
    facts: [
      _Fact(Icons.calendar_month, 'Opened', '${b.yearOpened}'),
      _Fact(Icons.person_outline, 'Lead', b.conductor),
      _Fact(Icons.groups_outlined, 'Members', '≈ ${b.membersApprox}'),
      _Fact(Icons.event_repeat, 'Rehearsals', b.rehearsalSchedule),
    ],
    description: b.description,
    mapUrl: b.mapUrl,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchLocation>>(
      future: _branches,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final branches = snap.data ?? const <BranchLocation>[];
        final pins = branches
            .map(
              (b) => _MapPin(
                point: LatLng(b.lat, b.lng),
                color: b.color,
                label: b.name,
                onTap: () => _focus(b),
              ),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 16),
            _RealMap(
              controller: _ctrl,
              pins: pins,
              center: _defaultCenter,
              zoom: _defaultZoom,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: branches
                    .map((b) => _LegendChip(label: b.name, color: b.color))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                eyebrow: 'Practice',
                title: 'Where We Rehearse',
                subtitle: 'Tap a branch to see details and zoom on the map.',
              ),
            ),
            const SizedBox(height: 12),
            ...branches.map(
              (b) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ElegantCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BranchDetailScreen(branch: b),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 56,
                        decoration: BoxDecoration(
                          color: b.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: b.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: b.color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.practiceLocation,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.gray),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VenuesTab extends StatefulWidget {
  const _VenuesTab();

  @override
  State<_VenuesTab> createState() => _VenuesTabState();
}

class _VenuesTabState extends State<_VenuesTab> with TickerProviderStateMixin {
  static const LatLng _defaultCenter = LatLng(33.5, 38.0);
  static const double _defaultZoom = 4.0;
  static const double _focusZoom = 10.0;
  final MapController _ctrl = MapController();
  late Future<List<Venue>> _venuesF;

  @override
  void initState() {
    super.initState();
    _venuesF = AudienceData.fetchVenues();
  }

  Future<void> _focus(Venue v) async {
    await smoothMove(
      this,
      _ctrl,
      LatLng(v.lat, v.lng),
      _focusZoom,
      duration: const Duration(milliseconds: 1700),
    );
    if (!mounted) return;
    _showInfo(context, _venueSheet(v));
  }

  Widget _venueSheet(Venue v) => _InfoSheet(
    color: AppColors.accentDark,
    icon: Icons.public,
    title: '${v.city}, ${v.country}',
    subtitle: v.event,
    facts: [
      _Fact(Icons.event, 'Date', v.date),
      _Fact(Icons.theater_comedy, 'Event', v.event),
      _Fact(
        Icons.place,
        'Coordinates',
        '${v.lat.toStringAsFixed(4)}, ${v.lng.toStringAsFixed(4)}',
      ),
    ],
    description: v.notes,
    mapUrl:
        'https://www.google.com/maps/search/${Uri.encodeComponent('${v.city}, ${v.country}')}',
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Venue>>(
      future: _venuesF,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final venues = [...(snap.data ?? const <Venue>[])]
          ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
        final pins = venues
            .map(
              (v) => _MapPin(
                point: LatLng(v.lat, v.lng),
                color: AppColors.accentDark,
                label: v.city,
                onTap: () => _focus(v),
              ),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 16),
            _RealMap(
              controller: _ctrl,
              pins: pins,
              center: _defaultCenter,
              zoom: _defaultZoom,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                eyebrow: 'On Tour',
                title: 'Performance Venues',
                subtitle:
                    'Tap a venue to see details. 20+ countries from China to Canada.',
              ),
            ),
            const SizedBox(height: 12),
            ...venues.map(
              (v) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ElegantCard(
                  onTap: () => _focus(v),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.public,
                          color: AppColors.accentDark,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${v.city}, ${v.country}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.event,
                                  size: 12,
                                  color: AppColors.gray,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  v.date,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.gray),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
