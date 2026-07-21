import 'package:flutter/material.dart';
import '../../services/choir_history_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'choir_history_trip_detail_screen.dart';
import 'compose_choir_history_trip_screen.dart';

class ChoirHistoryScreen extends StatefulWidget {
  const ChoirHistoryScreen({super.key});

  @override
  State<ChoirHistoryScreen> createState() => _ChoirHistoryScreenState();
}

class _ChoirHistoryScreenState extends State<ChoirHistoryScreen> {
  late Future<List<ChoirHistoryTrip>> _trips;
  late Future<Set<String>> _myParticipations;

  bool get _canEdit => AppState.instance.isEditor || AppState.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _trips = ChoirHistoryService.fetchAll();
      _myParticipations = ChoirHistoryService.fetchMyParticipations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choir History'),
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add historical trip',
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ComposeChoirHistoryTripScreen(),
                  ),
                );
                if (added == true) _load();
              },
            ),
        ],
      ),
      body: BrandedBackground(
        child: RefreshIndicator(
          onRefresh: () async => _load(),
          child: FutureBuilder<List<ChoirHistoryTrip>>(
            future: _trips,
            builder: (context, tripSnap) {
              if (tripSnap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (tripSnap.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load history',
                      message: '${tripSnap.error}',
                    ),
                  ],
                );
              }
              final trips = tripSnap.data ?? [];
              if (trips.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.history_outlined,
                      title: 'No history yet',
                      message: _canEdit
                          ? 'Tap + to document the first choir trip.'
                          : 'The choir\'s travel history will appear here.',
                    ),
                  ],
                );
              }

              return FutureBuilder<Set<String>>(
                future: _myParticipations,
                builder: (context, partSnap) {
                  final myTrips = partSnap.data ?? {};
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: trips.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: SectionHeader(
                            eyebrow: 'Archive',
                            title: 'Choir History',
                            subtitle:
                                '${trips.length} trip${trips.length == 1 ? '' : 's'} documented',
                          ),
                        );
                      }
                      final trip = trips[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TripCard(
                          trip: trip,
                          participated: myTrips.contains(trip.id),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChoirHistoryTripDetailScreen(trip: trip),
                              ),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Trip list card ────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final ChoirHistoryTrip trip;
  final bool participated;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.participated,
    required this.onTap,
  });

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: onTap,
      child: Row(
        children: [
          // Date badge
          Container(
            width: 52,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${trip.startDate.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
                Text(
                  _months[trip.startDate.month - 1],
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (participated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'I was there',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: AppColors.gray,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        trip.location,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (trip.activities.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${trip.activities.length} activit${trip.activities.length == 1 ? 'y' : 'ies'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }
}
