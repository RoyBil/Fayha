import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/bus_route_models.dart';
import '../../services/bus_route_service.dart';
import '../../services/trip_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import 'bus_route_editor_screen.dart';
import 'bus_route_live_screen.dart';
import 'bus_trip_driver_screen.dart';

/// List of bus routes for the signed-in member's branch.
/// Admins get an FAB to create new routes; members get a read-only list
/// that opens the live-tracking screen for whichever route they tap.
class BusRoutesScreen extends StatefulWidget {
  const BusRoutesScreen({super.key});

  @override
  State<BusRoutesScreen> createState() => _BusRoutesScreenState();
}

class _BusRoutesScreenState extends State<BusRoutesScreen> {
  late Future<List<_RouteRow>> _future;
  RealtimeChannel? _eventsChannel;
  Timer? _pollTimer;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _future = _load();

    // Refresh on any new trip event for this branch. ROUTE_STARTED /
    // _COMPLETED / _CANCELLED are the ones that flip the LIVE badge;
    // intermediate events (STOP_ARRIVED etc.) also fire but the
    // refetch is cheap and keeps everything in sync.
    _eventsChannel = Supabase.instance.client
        .channel('bus_routes_list_events')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'bus_trip_events',
        callback: (_) => _scheduleRefresh(),
      );
    _eventsChannel!.subscribe();

    // Polling fallback in case the realtime socket drops.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refreshDebounce?.cancel();
    if (_eventsChannel != null) {
      Supabase.instance.client.removeChannel(_eventsChannel!);
    }
    super.dispose();
  }

  /// Coalesce multiple realtime events fired in quick succession into
  /// a single list reload.
  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), _refresh);
  }

  Future<List<_RouteRow>> _load() async {
    final me = AppState.instance.currentMember!;
    final routes = await BusRouteService.listForBranch(me.branch);
    final rows = <_RouteRow>[];
    for (final r in routes) {
      final trip = await TripService.activeForRoute(r.id);
      rows.add(_RouteRow(route: r, activeTrip: trip));
    }
    return rows;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final me = AppState.instance.currentMember!;
    final canEdit = me.role == 'admin' || me.role == 'superAdmin';

    return Scaffold(
      appBar: AppBar(title: const Text('Bus Routes')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.cream,
              icon: const Icon(Icons.add),
              label: const Text('New Route'),
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BusRouteEditorScreen(),
                  ),
                );
                if (saved == true) _refresh();
              },
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<_RouteRow>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.directions_bus_outlined,
                  title: 'No routes yet',
                  message:
                      'Branch admins can create the first bus route from this screen.',
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _RouteTile(
                row: rows[i],
                canEdit: canEdit,
                onChanged: _refresh,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RouteRow {
  final BusRoute route;
  final BusTrip? activeTrip;
  const _RouteRow({required this.route, this.activeTrip});
}

class _RouteTile extends StatelessWidget {
  final _RouteRow row;
  final bool canEdit;
  final VoidCallback onChanged;
  const _RouteTile({
    required this.row,
    required this.canEdit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = row.route;
    final live = row.activeTrip != null;
    return ElegantCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusRouteLiveScreen(route: r),
          ),
        );
        onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ),
                if (live)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${r.startName}  →  ${r.endName}',
              style: TextStyle(color: AppColors.gray, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '${r.stops.length} stops · ${(r.totalDistanceM / 1000).toStringAsFixed(1)} km',
              style: TextStyle(color: AppColors.gray, fontSize: 12),
            ),
            if (canEdit) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusRouteEditorScreen(existing: r),
                        ),
                      );
                      if (saved == true) onChanged();
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                  if (!live)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusTripDriverScreen(route: r),
                          ),
                        );
                        onChanged();
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Trip'),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusTripDriverScreen(
                              route: r,
                              resumeTrip: row.activeTrip,
                            ),
                          ),
                        );
                        onChanged();
                      },
                      icon: const Icon(Icons.directions_bus),
                      label: const Text('Driver View'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
