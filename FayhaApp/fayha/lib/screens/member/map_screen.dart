import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/map_data.dart';
import '../../services/choir_history_service.dart';
import '../../services/live_location_service.dart';
import '../../services/member_houses_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fayha_map.dart';
import '../../widgets/section_header.dart';
import 'bus_routes_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
              Tab(icon: Icon(Icons.home_outlined, size: 20), text: 'Members'),
              Tab(
                icon: Icon(Icons.directions_bus_outlined, size: 20),
                text: 'Bus',
              ),
              Tab(icon: Icon(Icons.place_outlined, size: 20), text: 'Villages'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [_MembersTab(), BusRoutesScreen(), _VillagesTab()],
          ),
        ),
      ],
    );
  }
}

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

void _showSheet(BuildContext context, Widget sheet) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => sheet,
  );
}

// ================= MEMBERS =================
class _MembersTab extends StatefulWidget {
  const _MembersTab();
  @override
  State<_MembersTab> createState() => _MembersTabState();
}

enum _MapFilter { all, houses, branches, live }

class _MembersTabState extends State<_MembersTab>
    with TickerProviderStateMixin {
  static const LatLng _center = LatLng(34.05, 35.7);
  static const double _zoom = 8.0;
  static const double _focusZoom = 16.0;
  final MapController _ctrl = MapController();
  late Future<List<MemberHouse>> _houses;
  List<LiveMemberLocation> _live = const [];
  _MapFilter _filter = _MapFilter.all;

  @override
  void initState() {
    super.initState();
    _houses = MemberHousesService.fetchAll();
    _loadLive();
  }

  Future<void> _loadLive() async {
    try {
      final list = await LiveLocationService.fetchAll();
      if (!mounted) return;
      setState(() => _live = list);
    } catch (_) {
      // ignore — view may be empty
    }
  }

  Future<void> _reload() async {
    final fut = MemberHousesService.fetchAll();
    setState(() => _houses = fut);
    await _loadLive();
    await fut;
  }

  Future<void> _focusLive(LiveMemberLocation m) async {
    await smoothMove(
      this,
      _ctrl,
      LatLng(m.lat, m.lng),
      _focusZoom,
      duration: const Duration(milliseconds: 1100),
    );
  }

  Future<void> _focusHouse(MemberHouse m) async {
    final color = MapData.colorFor(m.branch);
    await smoothMove(
      this,
      _ctrl,
      LatLng(m.lat, m.lng),
      _focusZoom,
      duration: const Duration(milliseconds: 1300),
    );
    if (!mounted) return;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${m.lat},${m.lng}';
    _showSheet(
      context,
      MapInfoSheet(
        color: color,
        icon: Icons.home,
        title: m.name,
        subtitle:
            '${m.role[0].toUpperCase()}${m.role.substring(1)} · ${m.branch}',
        facts: [
          MapFact(Icons.music_note, 'Voice Section', m.voiceSection),
          MapFact(Icons.location_city, 'Branch', m.branch),
          if (m.address != null && m.address!.isNotEmpty)
            MapFact(Icons.place_outlined, 'Address', m.address!),
          MapFact(
            Icons.my_location,
            'Coordinates',
            '${m.lat.toStringAsFixed(4)}, ${m.lng.toStringAsFixed(4)}',
          ),
        ],
        onOpenMap: () => _open(url),
      ),
    );
  }

  Future<void> _focusBranch(BranchLocation b) async {
    await smoothMove(
      this,
      _ctrl,
      LatLng(b.lat, b.lng),
      13.0,
      duration: const Duration(milliseconds: 1300),
    );
    if (!mounted) return;
    _showSheet(
      context,
      MapInfoSheet(
        color: b.color,
        icon: Icons.account_balance,
        title: '${b.name} Branch',
        subtitle: b.practiceLocation,
        facts: [
          MapFact(Icons.event_outlined, 'Opened', '${b.yearOpened}'),
          MapFact(Icons.person_outline, 'Conductor', b.conductor),
          MapFact(
            Icons.groups_outlined,
            'Members',
            '~${b.membersApprox} singers',
          ),
          MapFact(Icons.schedule, 'Rehearsals', b.rehearsalSchedule),
        ],
        description: b.description,
        mapUrl: b.mapUrl,
        onOpenMap: () => _open(b.mapUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MemberHouse>>(
      future: _houses,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load member houses',
            message: '${snap.error}',
          );
        }
        // Only admins / Maestro can see other members' houses. A
        // regular member can still see their own house pin.
        final canSeeHouses =
            AppState.instance.isAdmin || AppState.instance.isMaestro;
        final me = AppState.instance.currentMember;
        final allFetched = snap.data ?? const <MemberHouse>[];
        final houses = canSeeHouses
            ? allFetched
            : (me == null
                  ? const <MemberHouse>[]
                  : allFetched.where((h) => h.id == me.id).toList());

        final branchPins = MapData.branches
            .map(
              (b) => MapPin(
                point: LatLng(b.lat, b.lng),
                color: b.color,
                label: b.name,
                icon: Icons.account_balance,
                onTap: () => _focusBranch(b),
              ),
            )
            .toList();
        final housePins = houses
            .map(
              (m) => MapPin(
                point: LatLng(m.lat, m.lng),
                color: MapData.colorFor(m.branch),
                label: m.name.split(' ').first,
                icon: Icons.home,
                onTap: () => _focusHouse(m),
              ),
            )
            .toList();
        final livePins = _live
            .map(
              (m) => MapPin(
                point: LatLng(m.lat, m.lng),
                color: MapData.colorFor(m.branch),
                label: m.name.split(' ').first,
                icon: Icons.person_pin_circle,
                onTap: () => _focusLive(m),
              ),
            )
            .toList();

        // "All" shows everything available; otherwise show only the picked layer.
        final showAll = _filter == _MapFilter.all;
        final showBranches = showAll || _filter == _MapFilter.branches;
        final showHouses = showAll || _filter == _MapFilter.houses;
        final showLive = showAll || _filter == _MapFilter.live;
        final visiblePins = [
          if (showBranches) ...branchPins,
          if (showHouses) ...housePins,
          if (showLive) ...livePins,
        ];

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      icon: Icons.public,
                      selected: _filter == _MapFilter.all,
                      onTap: () => setState(() => _filter = _MapFilter.all),
                    ),
                    if (canSeeHouses)
                      _FilterChip(
                        label: 'Houses',
                        icon: Icons.home_outlined,
                        selected: _filter == _MapFilter.houses,
                        onTap: () =>
                            setState(() => _filter = _MapFilter.houses),
                      ),
                    _FilterChip(
                      label: 'Live',
                      icon: Icons.share_location,
                      selected: _filter == _MapFilter.live,
                      onTap: () => setState(() => _filter = _MapFilter.live),
                    ),
                    _FilterChip(
                      label: 'Branches',
                      icon: Icons.account_balance,
                      selected: _filter == _MapFilter.branches,
                      onTap: () =>
                          setState(() => _filter = _MapFilter.branches),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FayhaMap(
                controller: _ctrl,
                pins: visiblePins,
                center: _center,
                zoom: _zoom,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: MapData.branches
                      .map((b) => _LegendChip(label: b.name, color: b.color))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(
                  eyebrow: 'Branches',
                  title: 'Rehearsal Locations',
                  subtitle: 'Tap a branch to zoom in.',
                ),
              ),
              const SizedBox(height: 12),
              ...MapData.branches.map(
                (b) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: ElegantCard(
                    onTap: () => _focusBranch(b),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 52,
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
                            Icons.account_balance,
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
                                '${b.name} Branch',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.practiceLocation,
                                style: Theme.of(context).textTheme.bodySmall,
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
              if (canSeeHouses || houses.isNotEmpty) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionHeader(
                    eyebrow: 'Houses',
                    title: canSeeHouses ? 'Member Locations' : 'My House',
                    subtitle: canSeeHouses
                        ? 'Tap a member to zoom in and see details.'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (houses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: EmptyState(
                      icon: Icons.home_outlined,
                      title: 'No houses pinned yet',
                      message:
                          'Members can add their house from the Profile screen.',
                    ),
                  )
                else
                  ...houses.map((m) {
                    final color = MapData.colorFor(m.branch);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: ElegantCard(
                        onTap: () => _focusHouse(m),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 52,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.home, color: color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${m.branch} · ${m.voiceSection}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.gray,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ================= VILLAGES =================
class _VillagesTab extends StatefulWidget {
  const _VillagesTab();
  @override
  State<_VillagesTab> createState() => _VillagesTabState();
}

class _VillagesTabState extends State<_VillagesTab>
    with TickerProviderStateMixin {
  static const LatLng _center = LatLng(33.5, 38.0);
  static const double _zoom = 4.0;
  final MapController _ctrl = MapController();

  List<ChoirHistoryTrip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trips = await ChoirHistoryService.fetchAll();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _focusTrip(ChoirHistoryTrip t) async {
    if (t.hasCoordinates) {
      await smoothMove(
        this,
        _ctrl,
        LatLng(t.lat!, t.lng!),
        10.0,
        duration: const Duration(milliseconds: 1500),
      );
    }
    if (!mounted) return;
    final url =
        'https://www.google.com/maps/search/${Uri.encodeComponent('${t.city}, ${t.country}')}';
    _showSheet(
      context,
      MapInfoSheet(
        color: AppColors.accentDark,
        icon: Icons.place,
        title: '${t.city}, ${t.country}',
        subtitle: t.name,
        facts: [
          MapFact(Icons.event, 'Year', '${t.startDate.year}'),
          MapFact(Icons.theater_comedy, 'Trip', t.name),
        ],
        description: t.description ?? '',
        onOpenMap: () => _open(url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pins = _trips
        .where((t) => t.hasCoordinates)
        .map(
          (t) => MapPin(
            point: LatLng(t.lat!, t.lng!),
            color: AppColors.accentDark,
            label: t.city,
            icon: Icons.place,
            onTap: () => _focusTrip(t),
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 16),
        FayhaMap(controller: _ctrl, pins: pins, center: _center, zoom: _zoom),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeader(
            eyebrow: 'On Tour',
            title: 'Villages & Cities Visited',
            subtitle: 'Every place the choir has performed.',
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_trips.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Text(
              'No trips recorded yet. Editors can add past trips in the Choir History section.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._trips.map(
            (t) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: ElegantCard(
                onTap: () => _focusTrip(t),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.place,
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
                            '${t.city}, ${t.country}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.name,
                            style: Theme.of(context).textTheme.bodySmall,
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
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.offWhite,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.cream : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.cream : AppColors.dark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
