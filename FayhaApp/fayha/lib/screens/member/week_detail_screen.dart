import 'package:flutter/material.dart';
import '../../services/attendance_stats_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';

/// Drill-down for one week of stats — for each rehearsal in the week,
/// shows who was present, who was late (and by how many minutes), and
/// who was absent.
class WeekDetailScreen extends StatefulWidget {
  final WeekStats week;
  final String branch;
  const WeekDetailScreen({
    super.key,
    required this.week,
    required this.branch,
  });

  @override
  State<WeekDetailScreen> createState() => _WeekDetailScreenState();
}

class _WeekDetailScreenState extends State<WeekDetailScreen> {
  static const _weekdays = [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ];
  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  late Future<List<SessionRoster>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<List<SessionRoster>> _loadAll() async {
    final rosters = await Future.wait(widget.week.days
        .where((d) => d.status == 'held')
        .map((d) => AttendanceStatsService.sessionRoster(
              branch: widget.branch,
              date: d.date,
            )));
    return rosters;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.week;
    final end = w.weekStart.add(const Duration(days: 6));
    final label =
        '${w.weekStart.day} ${_months[w.weekStart.month - 1]} — ${end.day} ${_months[end.month - 1]}';
    return Scaffold(
      appBar: AppBar(
        title: Text('Week of $label'),
      ),
      body: FutureBuilder<List<SessionRoster>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load',
                message: '${snap.error}',
              ),
            ]);
          }
          final rosters = snap.data ?? const <SessionRoster>[];
          if (rosters.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              EmptyState(
                icon: Icons.event_busy,
                title: 'No rehearsals held this week',
              ),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              for (final r in rosters) ..._sessionSection(r),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _sessionSection(SessionRoster r) {
    final d = r.date;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(_months[d.month - 1].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.accentLight, fontSize: 10)),
                  Text('${d.day}',
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_weekdays[d.weekday - 1],
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${r.present.length} present · ${r.late.length} late · ${r.absent.length} absent',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (r.present.isNotEmpty) ...[
        _sectionTitle('Present', AppColors.secondaryDark),
        ...r.present.map((m) => _memberRow(m)),
      ],
      if (r.late.isNotEmpty) ...[
        const SizedBox(height: 6),
        _sectionTitle('Late', AppColors.accentDark),
        ...r.late.map((m) => _memberRow(m)),
      ],
      if (r.absent.isNotEmpty) ...[
        const SizedBox(height: 6),
        _sectionTitle('Absent', AppColors.gray),
        ...r.absent.map((m) => _memberRow(m)),
      ],
      const Divider(height: 32),
    ];
  }

  Widget _sectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(SessionMember m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ElegantCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Avatar(name: m.name, size: 34, photoUrl: m.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(m.voiceSection,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            if (m.present && m.lateMinutes > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.accentDark.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${m.lateMinutes} min',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
