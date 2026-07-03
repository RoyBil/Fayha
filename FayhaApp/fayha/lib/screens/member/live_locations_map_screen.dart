import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/map_data.dart';
import '../../services/live_location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fayha_map.dart';
import 'member_detail_screen.dart';
import '../../services/admin_service.dart';

/// Maestro-only: a live map of every member currently sharing their
/// position. Auto-refreshes every 20 seconds.
class LiveLocationsMapScreen extends StatefulWidget {
  const LiveLocationsMapScreen({super.key});

  @override
  State<LiveLocationsMapScreen> createState() => _LiveLocationsMapScreenState();
}

class _LiveLocationsMapScreenState extends State<LiveLocationsMapScreen>
    with TickerProviderStateMixin {
  static const LatLng _center = LatLng(34.05, 35.7);
  static const double _zoom = 9.0;
  final MapController _ctrl = MapController();
  Timer? _refreshTimer;
  late Future<List<LiveMemberLocation>> _future;

  @override
  void initState() {
    super.initState();
    _future = LiveLocationService.fetchAll();
    // Pull fresh data every 20s so the map shows recent positions.
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _future = LiveLocationService.fetchAll());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _focus(LiveMemberLocation m) async {
    await smoothMove(
      this,
      _ctrl,
      LatLng(m.lat, m.lng),
      16.0,
      duration: const Duration(milliseconds: 1000),
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LiveMemberSheet(member: m),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Locations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                setState(() => _future = LiveLocationService.fetchAll()),
          ),
        ],
      ),
      body: FutureBuilder<List<LiveMemberLocation>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load',
                  message: '${snap.error}',
                ),
              ],
            );
          }
          final locations = snap.data ?? const <LiveMemberLocation>[];
          final pins = locations
              .map(
                (m) => MapPin(
                  point: LatLng(m.lat, m.lng),
                  color: MapData.colorFor(m.branch),
                  label: m.name.split(' ').first,
                  icon: Icons.person_pin_circle,
                  onTap: () => _focus(m),
                ),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SizedBox(height: 16),
              FayhaMap(
                controller: _ctrl,
                pins: pins,
                center: _center,
                zoom: _zoom,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${locations.length} member${locations.length == 1 ? '' : 's'} sharing right now',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              if (locations.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: EmptyState(
                    icon: Icons.location_off,
                    title: 'Nobody is sharing yet',
                    message:
                        'When a member turns on live sharing from their home screen, they\'ll appear here.',
                  ),
                )
              else
                ...locations.map((m) {
                  final color = MapData.colorFor(m.branch);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: ElegantCard(
                      onTap: () => _focus(m),
                      child: Row(
                        children: [
                          Avatar(name: m.name, size: 40, photoUrl: m.photoUrl),
                          const SizedBox(width: 12),
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
                                    Text(
                                      '${m.branch} · ${m.voiceSection}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                if (m.at != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _ago(m.at!),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
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
          );
        },
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'updated just now';
    if (d.inMinutes < 60) return 'updated ${d.inMinutes}m ago';
    if (d.inHours < 24) return 'updated ${d.inHours}h ago';
    return 'updated ${d.inDays}d ago';
  }
}

class _LiveMemberSheet extends StatelessWidget {
  final LiveMemberLocation member;
  const _LiveMemberSheet({required this.member});

  @override
  Widget build(BuildContext context) {
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
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Avatar(name: member.name, size: 56, photoUrl: member.photoUrl),
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
                      Text(
                        '${member.branch} · ${member.voiceSection}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Open full profile'),
                onPressed: () async {
                  final full = await AdminService.fetchMember(member.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (full == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberDetailScreen(member: full),
                    ),
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
