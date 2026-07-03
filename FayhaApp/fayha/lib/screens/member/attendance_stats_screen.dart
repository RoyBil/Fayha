import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../services/attendance_stats_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'week_detail_screen.dart';

/// Admin-only attendance statistics: per-day and per-week, scoped to a
/// branch. Lives both as a standalone screen and as a tab in the
/// admin panel.
class AttendanceStatsScreen extends StatefulWidget {
  const AttendanceStatsScreen({super.key});

  @override
  State<AttendanceStatsScreen> createState() => _AttendanceStatsScreenState();
}

class _AttendanceStatsScreenState extends State<AttendanceStatsScreen> {
  late String _branch;
  late Future<List<DayStats>> _future;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

  @override
  void initState() {
    super.initState();
    final me = AppState.instance.currentMember;
    _branch = (me != null && ChoirData.branches.contains(me.branch))
        ? me.branch
        : 'Tripoli';
    _future = AttendanceStatsService.dayStats(branch: _branch);
  }

  void _switchBranch(String b) {
    setState(() {
      _branch = b;
      _future = AttendanceStatsService.dayStats(branch: b);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Stats')),
      body: _StatsBody(
        branch: _branch,
        future: _future,
        onSwitchBranch: _switchBranch,
        weekdays: _weekdays,
        months: _months,
      ),
    );
  }
}

/// Same layout the admin-panel tab uses, with no Scaffold around it.
class AttendanceStatsBody extends StatefulWidget {
  const AttendanceStatsBody({super.key});

  @override
  State<AttendanceStatsBody> createState() => _AttendanceStatsBodyState();
}

class _AttendanceStatsBodyState extends State<AttendanceStatsBody> {
  late String _branch;
  late Future<List<DayStats>> _future;

  @override
  void initState() {
    super.initState();
    final me = AppState.instance.currentMember;
    _branch = (me != null && ChoirData.branches.contains(me.branch))
        ? me.branch
        : 'Tripoli';
    _future = AttendanceStatsService.dayStats(branch: _branch);
  }

  void _switchBranch(String b) {
    setState(() {
      _branch = b;
      _future = AttendanceStatsService.dayStats(branch: b);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _StatsBody(
      branch: _branch,
      future: _future,
      onSwitchBranch: _switchBranch,
      weekdays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      months: const [
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
      ],
    );
  }
}

class _StatsBody extends StatelessWidget {
  final String branch;
  final Future<List<DayStats>> future;
  final ValueChanged<String> onSwitchBranch;
  final List<String> weekdays;
  final List<String> months;

  const _StatsBody({
    required this.branch,
    required this.future,
    required this.onSwitchBranch,
    required this.weekdays,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: DropdownButtonFormField<String>(
            value: branch,
            decoration: const InputDecoration(
              labelText: 'Branch',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: ChoirData.branches
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) {
              if (v != null) onSwitchBranch(v);
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<DayStats>>(
            future: future,
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
                      title: 'Could not load stats',
                      message: '${snap.error}',
                    ),
                  ],
                );
              }
              final days = snap.data ?? const <DayStats>[];
              if (days.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.bar_chart,
                      title: 'No data yet',
                      message:
                          'Once attendance is recorded for this branch, stats will appear here.',
                    ),
                  ],
                );
              }
              final weeks = AttendanceStatsService.rollupWeeks(days);
              final summary = _summary(days);

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // === Summary ===
                  Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          label: 'Sessions',
                          value: '${days.length}',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatPill(
                          label: 'Avg present',
                          value: '${(summary.avgPresentRate * 100).round()}%',
                          color: AppColors.secondaryDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatPill(
                          label: 'Avg late',
                          value: '${summary.avgLateMinutes}m',
                          color: AppColors.accentDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // === Per week ===
                  const SectionHeader(eyebrow: 'Weekly', title: 'By week'),
                  const SizedBox(height: 10),
                  ...weeks.map(
                    (w) => _WeekRow(
                      week: w,
                      months: months,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WeekDetailScreen(week: w, branch: branch),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // === Per day ===
                  const SectionHeader(
                    eyebrow: 'Daily',
                    title: 'Every recorded session',
                  ),
                  const SizedBox(height: 10),
                  ...days.map(
                    (d) => _DayRow(day: d, weekdays: weekdays, months: months),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  _Summary _summary(List<DayStats> days) {
    final held = days.where((d) => d.status == 'held').toList();
    if (held.isEmpty) {
      return const _Summary(avgPresentRate: 0, avgLateMinutes: 0);
    }
    final presentRate =
        held
            .map((d) => d.presentRate + (d.late > 0 ? d.late / d.total : 0))
            .reduce((a, b) => a + b) /
        held.length;
    final lateMins = held
        .where((d) => d.late > 0)
        .map((d) => d.avgLateMinutes)
        .toList();
    final avgLate = lateMins.isEmpty
        ? 0
        : (lateMins.reduce((a, b) => a + b) / lateMins.length).round();
    return _Summary(
      avgPresentRate: presentRate.clamp(0, 1).toDouble(),
      avgLateMinutes: avgLate,
    );
  }
}

class _Summary {
  final double avgPresentRate;
  final int avgLateMinutes;
  const _Summary({required this.avgPresentRate, required this.avgLateMinutes});
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final WeekStats week;
  final List<String> months;
  final VoidCallback? onTap;
  const _WeekRow({required this.week, required this.months, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = week.weekStart.add(const Duration(days: 6));
    final label =
        'Week of ${week.weekStart.day} ${months[week.weekStart.month - 1]} — '
        '${end.day} ${months[end.month - 1]}';
    final total = week.presentTotal + week.lateTotal + week.absentTotal;
    final attendRate = total == 0
        ? 0.0
        : (week.presentTotal + week.lateTotal) / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElegantCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: AppColors.gray),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${week.sessions} session${week.sessions == 1 ? "" : "s"} · ${(attendRate * 100).round()}% attended',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _StackedBar(
              present: week.presentTotal,
              late: week.lateTotal,
              absent: week.absentTotal,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Legend(
                  color: AppColors.secondaryDark,
                  label: 'Present ${week.presentTotal}',
                ),
                const SizedBox(width: 10),
                _Legend(
                  color: AppColors.accentDark,
                  label: 'Late ${week.lateTotal}',
                ),
                const SizedBox(width: 10),
                _Legend(
                  color: AppColors.gray,
                  label: 'Absent ${week.absentTotal}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DayStats day;
  final List<String> weekdays;
  final List<String> months;
  const _DayRow({
    required this.day,
    required this.weekdays,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = day.date;
    if (day.status == 'cancelled') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ElegantCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _DateBox(date: d, weekdays: weekdays, months: months),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'No rehearsal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.gray,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElegantCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateBox(date: d, weekdays: weekdays, months: months),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniStat(
                        color: AppColors.secondaryDark,
                        label: 'P',
                        value: '${day.present}',
                      ),
                      const SizedBox(width: 8),
                      _MiniStat(
                        color: AppColors.accentDark,
                        label: 'L',
                        value: '${day.late}',
                      ),
                      const SizedBox(width: 8),
                      _MiniStat(
                        color: AppColors.gray,
                        label: 'A',
                        value: '${day.absent}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StackedBar(
                    present: day.present,
                    late: day.late,
                    absent: day.absent,
                  ),
                  if (day.avgLateMinutes > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Avg late ${day.avgLateMinutes} min',
                      style: theme.textTheme.labelSmall,
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

class _DateBox extends StatelessWidget {
  final DateTime date;
  final List<String> weekdays;
  final List<String> months;
  const _DateBox({
    required this.date,
    required this.weekdays,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            months[date.month - 1].toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.accentLight,
            ),
          ),
          Text(
            '${date.day}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.cream,
              height: 1,
            ),
          ),
          Text(
            weekdays[date.weekday - 1],
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.accentLight,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final int present;
  final int late;
  final int absent;
  const _StackedBar({
    required this.present,
    required this.late,
    required this.absent,
  });

  @override
  Widget build(BuildContext context) {
    final total = (present + late + absent).clamp(1, 1 << 30);
    return SizedBox(
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            if (present > 0)
              Expanded(
                flex: present,
                child: Container(color: AppColors.secondaryDark),
              ),
            if (late > 0)
              Expanded(
                flex: late,
                child: Container(color: AppColors.accentDark),
              ),
            if (absent > 0)
              Expanded(
                flex: absent,
                child: Container(color: AppColors.gray.withValues(alpha: 0.5)),
              ),
            // Force a minimum width so the bar always shows something.
            if (present + late + absent == 0)
              Expanded(
                flex: total,
                child: Container(color: AppColors.offWhite),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _MiniStat({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
