import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../services/attendance_service.dart';
import '../../services/concerts_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'attendance_history_screen.dart';
import 'attendance_sheet_screen.dart';
import 'qr_attendance_admin_screen.dart';
import 'qr_check_in_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _weekdays = [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ];
  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  late String _branch;
  List<SessionInfo> _sessions = [];
  List<Concert> _events = const [];
  bool _loading = true;
  String? _error;

  bool get _isSuper =>
      AppState.instance.currentMember?.role == 'superAdmin';
  bool get _isAdmin {
    final r = AppState.instance.currentMember?.role;
    return r == 'admin' || r == 'superAdmin';
  }

  @override
  void initState() {
    super.initState();
    final me = AppState.instance.currentMember;
    _branch = _isSuper ? 'Tripoli' : (me?.branch ?? 'Tripoli');
    if (_isAdmin) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AttendanceService.displaySessions(_branch),
        ConcertsService.fetchRecentAndUpcoming(),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<SessionInfo>;
        _events = results[1] as List<Concert>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// Same chooser as a rehearsal date, but the target is an event
  /// (concert or big rehearsal).
  Future<void> _openEvent(Concert e) async {
    if (e.id == null) return;
    final isFuture = e.date.isAfter(DateTime.now());
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(e.isRehearsal ? 'Big rehearsal' : 'Concert',
                  style: Theme.of(ctx).textTheme.labelMedium),
              Text(e.title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${e.location} · ${e.date.day}/${e.date.month}/${e.date.year}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ModeTile(
                icon: Icons.qr_code_2,
                title: 'Show QR code',
                subtitle: isFuture || _isToday(e.date)
                    ? 'Open a QR session for this event.'
                    : 'View who scanned (no new QR after the event).',
                onTap: () => Navigator.pop(ctx, 'qr_show'),
              ),
              if (_isToday(e.date) || isFuture) ...[
                const SizedBox(height: 10),
                _ModeTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Scan a QR',
                  subtitle:
                      'Another admin is hosting — scan their QR to count yourself in.',
                  onTap: () => Navigator.pop(ctx, 'qr_scan'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'qr_show') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrAttendanceAdminScreen.event(
            concertId: e.id!,
            concertTitle: e.title,
            concertStart: e.date,
            isBigRehearsal: e.isRehearsal,
          ),
        ),
      );
      _load();
    } else if (choice == 'qr_scan') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrCheckInScreen()),
      );
      _load();
    }
  }

  Future<void> _openSession(DateTime date) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Take attendance',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${_weekdays[date.weekday - 1]} · ${date.day}/${date.month}/${date.year}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ModeTile(
                icon: Icons.checklist,
                title: 'Manual sheet',
                subtitle:
                    'Tick members one by one. Best when you have the roster in front of you.',
                onTap: () => Navigator.pop(ctx, 'manual'),
              ),
              const SizedBox(height: 10),
              _ModeTile(
                icon: Icons.qr_code_2,
                title: 'Show QR code',
                subtitle: _isToday(date)
                    ? 'Display a QR code for members to scan. Valid 3 hours.'
                    : 'View who scanned (the QR window only opens on the day).',
                onTap: () => Navigator.pop(ctx, 'qr_show'),
              ),
              if (_isToday(date)) ...[
                const SizedBox(height: 10),
                _ModeTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Scan a QR',
                  subtitle:
                      'Another admin is hosting — scan their QR to count yourself in.',
                  onTap: () => Navigator.pop(ctx, 'qr_scan'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'manual') {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AttendanceSheetScreen(branch: _branch, date: date),
        ),
      );
      if (saved == true) _load();
    } else if (choice == 'qr_show') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrAttendanceAdminScreen.rehearsal(
              branch: _branch, date: date),
        ),
      );
      _load();
    } else if (choice == 'qr_scan') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrCheckInScreen()),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.checklist_rtl,
          title: 'Attendance',
          message: 'Attendance is recorded by your branch admin and the Maestro.',
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.offWhite,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.person_outline, size: 16),
              label: const Text('Your attendance'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AttendanceHistoryScreen()),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: _isAdmin
                ? DropdownButtonFormField<String>(
                    value: _branch,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    items: ChoirData.branches
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _branch = v);
                      _load();
                    },
                  )
                : Row(
                    children: [
                      const Icon(Icons.location_city_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text('$_branch branch',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Rehearsals · ${AttendanceService.sessionTime}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _error != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.error_outline,
                                title: 'Could not load sessions',
                                message: _error!,
                              ),
                            ],
                          )
                        : _sessions.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState(
                                    icon: Icons.event_available,
                                    title: 'All caught up',
                                    message:
                                        'No rehearsal dates to record right now.',
                                  ),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 12, 20, 32),
                                children: [
                                  const SectionHeader(
                                      eyebrow: 'Sessions',
                                      title: 'Pick a date'),
                                  const SizedBox(height: 12),
                                  ..._sessions.map((s) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: _sessionCard(theme, s),
                                      )),
                                  if (_events.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    const SectionHeader(
                                      eyebrow: 'Events',
                                      title: 'Concerts & big rehearsals',
                                      subtitle:
                                          'Open a QR session for an event with attendance.',
                                    ),
                                    const SizedBox(height: 12),
                                    ..._events.map((e) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: _eventCard(theme, e),
                                        )),
                                  ],
                                ],
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(ThemeData theme, Concert e) {
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'
    ];
    final d = e.date;
    final today = _isToday(d);
    final past = d.isBefore(DateTime.now()) && !today;
    final tone = e.isRehearsal ? AppColors.secondaryDark : AppColors.accentDark;
    return ElegantCard(
      onTap: () => _openEvent(e),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: today ? AppColors.accent : tone,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(months[d.month - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: today ? AppColors.dark : AppColors.accentLight,
                    )),
                Text('${d.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: today ? AppColors.dark : AppColors.cream,
                      height: 1,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: theme.textTheme.titleMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${e.isRehearsal ? "Big rehearsal" : "Concert"} · ${e.location}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (past)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text('Past',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.gray,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }

  Widget _sessionCard(ThemeData theme, SessionInfo s) {
    final d = s.date;
    final today = _isToday(d);

    Color badgeColor;
    String badgeText;
    if (s.status == 'held') {
      badgeColor = AppColors.secondary;
      badgeText = 'Recorded';
    } else if (s.status == 'cancelled') {
      badgeColor = AppColors.gray;
      badgeText = 'No rehearsal';
    } else {
      badgeColor = AppColors.accentDark;
      badgeText = today ? 'Today' : 'To record';
    }

    return ElegantCard(
      onTap: () => _openSession(d),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: today ? AppColors.accent : AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(_months[d.month - 1].toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: today
                            ? AppColors.dark
                            : AppColors.accentLight)),
                Text('${d.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: today ? AppColors.dark : AppColors.cream,
                        height: 1)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_weekdays[d.weekday - 1],
                    style: theme.textTheme.titleMedium),
                Text('${d.day}/${d.month}/${d.year}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                )),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }
}
