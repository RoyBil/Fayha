import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../services/attendance_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'attendance_screen.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late Future<List<HistoryItem>> _future;
  int _lastStatsVersion = -1;
  RealtimeChannel? _attendanceChannel;

  bool get _isAdmin {
    final r = AppState.instance.currentMember?.role;
    return r == 'admin' || r == 'superAdmin';
  }

  @override
  void initState() {
    super.initState();
    _future = AttendanceService.myHistory();
    _lastStatsVersion = AppState.instance.statsVersion;
    AppState.instance.addListener(_onAppStateChange);
    _attendanceChannel = AttendanceService.subscribeToMyAttendance(_reload);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChange);
    AttendanceService.unsubscribe(_attendanceChannel);
    super.dispose();
  }

  void _onAppStateChange() {
    final v = AppState.instance.statsVersion;
    if (v != _lastStatsVersion) {
      _lastStatsVersion = v;
      _reload();
    }
  }

  Future<void> _reload() async {
    final f = AttendanceService.myHistory();
    if (!mounted) return;
    setState(() => _future = f);
    await f;
  }

  Future<void> _openTakeAttendance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openTakeAttendance,
              icon: const Icon(Icons.checklist_rtl),
              label: const Text('Take attendance'),
            )
          : null,
      body: BrandedBackground(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<HistoryItem>>(
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
                      title: 'Could not load history',
                      message: '${snap.error}',
                    ),
                  ],
                );
              }
              final items = snap.data ?? const <HistoryItem>[];
              if (items.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.history,
                      title: 'No history yet',
                      message:
                          'Rehearsals you attend and choir events you sing in will show up here.',
                    ),
                  ],
                );
              }

              final rehearsals = items
                  .where((i) => i.kind == 'rehearsal')
                  .length;
              final concerts = items.where((i) => i.kind == 'concert').length;
              final bigRehearsals = items
                  .where((i) => i.kind == 'big_rehearsal')
                  .length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Rehearsals',
                          value: '$rehearsals',
                          icon: Icons.event_available,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Concerts',
                          value: '$concerts',
                          icon: Icons.music_note,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Big rehearsals',
                          value: '$bigRehearsals',
                          icon: Icons.groups,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(
                    eyebrow: 'History',
                    title: 'Practices & events',
                    subtitle: 'Everything you took part in, newest first.',
                  ),
                  const SizedBox(height: 12),
                  ...items.map(
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HistoryTile(item: i),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.offWhite),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryItem item;
  const _HistoryTile({required this.item});

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  ({IconData icon, Color color, String label}) _meta() {
    switch (item.kind) {
      case 'concert':
        return (
          icon: Icons.music_note,
          color: AppColors.accentDark,
          label: 'Concert',
        );
      case 'big_rehearsal':
        return (
          icon: Icons.groups,
          color: AppColors.secondaryDark,
          label: 'Big rehearsal',
        );
      default:
        return (
          icon: Icons.event_available,
          color: AppColors.primary,
          label: 'Rehearsal',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = item.date;
    final m = _meta();
    return ElegantCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: m.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _months[d.month - 1].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${d.day}',
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${d.year}',
                  style: const TextStyle(color: AppColors.cream, fontSize: 9),
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
                    Icon(m.icon, size: 14, color: m.color),
                    const SizedBox(width: 6),
                    Text(
                      m.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: m.color,
                      ),
                    ),
                    if (item.lateMinutes > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.accentDark.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          'Late ${item.lateMinutes} min',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_weekdays[d.weekday - 1]} · ${item.subtitle}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
