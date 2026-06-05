import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/qr_attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';

/// Admin / superAdmin: open or revisit a QR attendance session for a
/// rehearsal day OR a concert / big rehearsal event.
class QrAttendanceAdminScreen extends StatefulWidget {
  // Rehearsal target
  final String? branch;
  final DateTime? date;
  // Concert / big-rehearsal target
  final String? concertId;
  final String? concertTitle;
  final DateTime? concertStart;
  final bool isBigRehearsal;

  const QrAttendanceAdminScreen.rehearsal({
    super.key,
    required String this.branch,
    required DateTime this.date,
  })  : concertId = null,
        concertTitle = null,
        concertStart = null,
        isBigRehearsal = false;

  const QrAttendanceAdminScreen.event({
    super.key,
    required String this.concertId,
    required String this.concertTitle,
    required DateTime this.concertStart,
    required this.isBigRehearsal,
  })  : branch = null,
        date = null;

  bool get isConcertTarget => concertId != null;

  @override
  State<QrAttendanceAdminScreen> createState() =>
      _QrAttendanceAdminScreenState();
}

class _QrAttendanceAdminScreenState extends State<QrAttendanceAdminScreen> {
  QrSession? _session;
  bool _loading = true;
  bool _starting = false;
  String? _error;
  Timer? _ticker;
  Stream<List<QrCheckin>>? _liveStream;
  Future<List<QrCheckin>>? _staticFuture;

  DateTime get _targetDate {
    if (widget.isConcertTarget) return widget.concertStart!.toLocal();
    return widget.date!;
  }

  bool get _isTodayOrFuture {
    final n = DateTime.now();
    final d = _targetDate;
    final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);
    return endOfDay.isAfter(n) ||
        (d.year == n.year && d.month == n.month && d.day == n.day);
  }

  bool get _hasLiveQr => _session != null && _session!.isActive;
  bool get _pendingQr => _session != null && _session!.isPending;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadLatest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = widget.isConcertTarget
          ? await QrAttendanceService.latestSessionForConcert(widget.concertId!)
          : await QrAttendanceService.latestSession(
              branch: widget.branch!, date: widget.date!);
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
        if (s != null && !s.isExpired) {
          _liveStream = QrAttendanceService.watchCheckins(s);
          _staticFuture = null;
        } else {
          _liveStream = null;
          _staticFuture = widget.isConcertTarget
              ? QrAttendanceService.checkinsForConcert(widget.concertId!)
              : QrAttendanceService.checkinsForDay(
                  branch: widget.branch!, date: widget.date!);
        }
      });
      _refreshTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _refreshTicker() {
    _ticker?.cancel();
    if (_hasLiveQr || _pendingQr) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _start() async {
    final config = await showModalBottomSheet<_QrConfig>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _QrConfigSheet(targetDate: _targetDate),
    );
    if (config == null) return;
    await _runStart(config);
  }

  Future<void> _runStart(_QrConfig config) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final s = widget.isConcertTarget
          ? await QrAttendanceService.startSessionForConcert(
              concertId: widget.concertId!,
              validFrom: config.validFrom,
              validFor: config.duration,
              lateAfter: config.lateAfter,
            )
          : await QrAttendanceService.startSession(
              branch: widget.branch!,
              date: widget.date!,
              validFrom: config.validFrom,
              validFor: config.duration,
              lateAfter: config.lateAfter,
            );
      if (!mounted) return;
      setState(() {
        _session = s;
        _starting = false;
        _liveStream = QrAttendanceService.watchCheckins(s);
        _staticFuture = null;
      });
      _refreshTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = '$e';
      });
    }
  }

  Future<void> _edit() async {
    final s = _session;
    if (s == null) return;
    final config = await showModalBottomSheet<_QrConfig>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _QrConfigSheet(targetDate: _targetDate, existing: s),
    );
    if (config == null) return;
    setState(() => _starting = true);
    try {
      final updated = await QrAttendanceService.updateSession(
        id: s.id,
        validFrom: config.validFrom,
        expiresAt: config.validFrom.add(config.duration),
        lateAfter: config.lateAfter,
      );
      if (!mounted) return;
      setState(() {
        _session = updated;
        _starting = false;
        _liveStream = updated.isActive
            ? QrAttendanceService.watchCheckins(updated)
            : null;
        _staticFuture = updated.isActive
            ? null
            : (widget.isConcertTarget
                ? QrAttendanceService.checkinsForConcert(widget.concertId!)
                : QrAttendanceService.checkinsForDay(
                    branch: widget.branch!, date: widget.date!));
      });
      _refreshTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = '$e';
      });
    }
  }

  Future<void> _delete() async {
    final s = _session;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this QR session?'),
        content: const Text(
            'The QR will stop working immediately. Existing check-ins '
            'are kept in the attendance record.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await QrAttendanceService.deleteSession(s.id);
      if (!mounted) return;
      _ticker?.cancel();
      setState(() {
        _session = null;
        _liveStream = null;
        _staticFuture = widget.isConcertTarget
            ? QrAttendanceService.checkinsForConcert(widget.concertId!)
            : QrAttendanceService.checkinsForDay(
                branch: widget.branch!, date: widget.date!);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  String _fmtRemaining(Duration d) {
    if (d.isNegative) return 'Expired';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m left';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s left';
    return '${s}s left';
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  Future<void> _openOnMap(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open map: $lat, $lng')),
      );
    }
  }

  String get _targetLabel {
    if (widget.isConcertTarget) {
      final kind = widget.isBigRehearsal ? 'Big Rehearsal' : 'Concert';
      return '$kind · ${widget.concertTitle} · ${_fmtDate(_targetDate)}';
    }
    return '${widget.branch} · ${_fmtDate(_targetDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Attendance'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _targetLabel,
                style: const TextStyle(
                    color: AppColors.cream, fontSize: 12, letterSpacing: 0.6),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLatest,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _topSection(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(color: Colors.red.shade700)),
                  ],
                  const SizedBox(height: 28),
                  SectionHeader(
                    eyebrow: _hasLiveQr || _pendingQr ? 'Live' : 'History',
                    title: 'Attendees',
                    subtitle: _hasLiveQr
                        ? 'Updates as members scan.'
                        : (_pendingQr
                            ? 'Will go live when the start time arrives.'
                            : 'All members who scanned.'),
                  ),
                  const SizedBox(height: 8),
                  _attendeesList(),
                ],
              ),
            ),
    );
  }

  Widget _topSection() {
    final s = _session;
    if (s != null && (s.isActive || s.isPending)) return _qrCard(s);
    if (_isTodayOrFuture) return _startCard();
    return _expiredOrAbsentCard(s);
  }

  Widget _startCard() {
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'Start',
            title: 'Open a QR session',
            subtitle:
                'Configure when it goes live, how long it stays open, '
                'and when scans count as late.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: _starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.cream),
                  )
                : const Icon(Icons.qr_code_2),
            label: const Text('Configure & start'),
          ),
        ],
      ),
    );
  }

  Widget _expiredOrAbsentCard(QrSession? s) {
    return ElegantCard(
      background: AppColors.offWhite,
      child: Row(
        children: [
          const Icon(Icons.timer_off_outlined,
              size: 28, color: AppColors.gray),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s == null
                  ? 'No QR session was opened.'
                  : 'QR session ended at ${_fmtTime(s.expiresAt)}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrCard(QrSession s) {
    final pending = s.isPending;
    return ElegantCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pending ? AppColors.offWhite : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.offWhite),
            ),
            child: pending
                ? Column(
                    children: [
                      const Icon(Icons.hourglass_top,
                          size: 64, color: AppColors.gray),
                      const SizedBox(height: 8),
                      Text(
                        'QR goes live at ${_fmtTime(s.validFrom)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'In ${_fmtRemaining(s.validFrom.difference(DateTime.now()))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : QrImageView(
                    data: s.token,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primaryDark,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.dark,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 16, color: AppColors.secondaryDark),
              const SizedBox(width: 6),
              Text(_fmtRemaining(s.remaining),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.secondaryDark,
                      )),
              const Spacer(),
              Text('${_fmtTime(s.validFrom)} → ${_fmtTime(s.expiresAt)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (s.lateAfter != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Late after ${_fmtTime(s.lateAfter!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _starting ? null : _edit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  onPressed: _starting ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attendeesList() {
    if (_hasLiveQr) {
      return StreamBuilder<List<QrCheckin>>(
        stream: _liveStream,
        builder: (context, snap) => _renderList(snap.data),
      );
    }
    return FutureBuilder<List<QrCheckin>>(
      future: _staticFuture,
      builder: (context, snap) => _renderList(snap.data),
    );
  }

  Widget _renderList(List<QrCheckin>? list) {
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No check-ins yet.',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    final onTime = list.where((c) => c.lateMinutes == 0).length;
    final late = list.length - onTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${list.length} checked in · $onTime on time · $late late',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.gray,
                  letterSpacing: 0.6,
                ),
          ),
        ),
        ...list.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _checkinTile(c),
            )),
      ],
    );
  }

  Widget _checkinTile(QrCheckin c) {
    final isLate = c.lateMinutes > 0;
    return ElegantCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isLate
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.secondary.withValues(alpha: 0.15),
            child: Icon(
              isLate ? Icons.schedule : Icons.check,
              color: isLate ? AppColors.accentDark : AppColors.secondaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.memberName,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  isLate
                      ? '${_fmtTime(c.checkedInAt)} · ${c.lateMinutes} min late'
                      : '${_fmtTime(c.checkedInAt)} · on time',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isLate ? AppColors.accentDark : AppColors.gray,
                      ),
                ),
                if (c.lat != null && c.lng != null)
                  InkWell(
                    onTap: () => _openOnMap(c.lat!, c.lng!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(
                          'View location',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrConfig {
  final DateTime validFrom;
  final Duration duration;
  final DateTime? lateAfter;
  _QrConfig({
    required this.validFrom,
    required this.duration,
    this.lateAfter,
  });
}

class _QrConfigSheet extends StatefulWidget {
  final DateTime targetDate;
  /// When non-null, edit an existing session.
  final QrSession? existing;
  const _QrConfigSheet({required this.targetDate, this.existing});

  @override
  State<_QrConfigSheet> createState() => _QrConfigSheetState();
}

class _QrConfigSheetState extends State<_QrConfigSheet> {
  late DateTime _validFrom;
  Duration _duration = const Duration(hours: 3);
  Duration _graceBeforeLate = const Duration(minutes: 15);

  bool get _isEdit => widget.existing != null;

  static const _durationOptions = <(String, Duration)>[
    ('30 min', Duration(minutes: 30)),
    ('1 h', Duration(hours: 1)),
    ('2 h', Duration(hours: 2)),
    ('3 h', Duration(hours: 3)),
    ('5 h', Duration(hours: 5)),
    ('8 h', Duration(hours: 8)),
  ];
  static const _graceOptions = <(String, Duration)>[
    ('No grace', Duration.zero),
    ('5 min', Duration(minutes: 5)),
    ('10 min', Duration(minutes: 10)),
    ('15 min', Duration(minutes: 15)),
    ('30 min', Duration(minutes: 30)),
    ('1 h', Duration(hours: 1)),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _validFrom = e.validFrom;
      _duration = e.expiresAt.difference(e.validFrom);
      if (e.lateAfter != null) {
        final grace = e.lateAfter!.difference(e.validFrom);
        _graceBeforeLate = grace.isNegative ? Duration.zero : grace;
      } else {
        _graceBeforeLate = Duration.zero;
      }
      return;
    }
    final now = DateTime.now();
    // Default the start time to "now, rounded up to next 5 minutes",
    // anchored to the target day so the admin can schedule for later.
    final base = widget.targetDate.year == now.year &&
            widget.targetDate.month == now.month &&
            widget.targetDate.day == now.day
        ? now
        : DateTime(widget.targetDate.year, widget.targetDate.month,
            widget.targetDate.day, 18, 0);
    final mins = base.minute + (5 - base.minute % 5) % 5;
    _validFrom = DateTime(
        base.year, base.month, base.day, base.hour, mins);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _validFrom,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d == null) return;
    setState(() {
      _validFrom = DateTime(
          d.year, d.month, d.day, _validFrom.hour, _validFrom.minute);
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_validFrom),
    );
    if (t == null) return;
    setState(() {
      _validFrom = DateTime(_validFrom.year, _validFrom.month,
          _validFrom.day, t.hour, t.minute);
    });
  }

  String _fmt(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)} · ${pad(d.hour)}:${pad(d.minute)}';
  }

  String _humanDuration(Duration d) {
    if (d.inHours > 0 && d.inMinutes % 60 == 0) return '${d.inHours} h';
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final lateAt = _graceBeforeLate == Duration.zero
        ? _validFrom
        : _validFrom.add(_graceBeforeLate);
    final endAt = _validFrom.add(_duration);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit QR session' : 'Configure QR session',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            // Start time
            Text('Goes live at',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                        '${_validFrom.day}/${_validFrom.month}/${_validFrom.year}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(
                        '${_validFrom.hour.toString().padLeft(2, '0')}:'
                        '${_validFrom.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Duration
            Text('Stays open for',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durationOptions
                  .map((o) => ChoiceChip(
                        label: Text(o.$1),
                        selected: _duration == o.$2,
                        onSelected: (_) =>
                            setState(() => _duration = o.$2),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),

            // Late grace
            Text('Mark late after',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _graceOptions
                  .map((o) => ChoiceChip(
                        label: Text(o.$1),
                        selected: _graceBeforeLate == o.$2,
                        onSelected: (_) =>
                            setState(() => _graceBeforeLate = o.$2),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live: ${_fmt(_validFrom)} → ${_fmt(endAt)}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    'Duration: ${_humanDuration(_duration)} · '
                    'Late after ${_fmt(lateAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(_isEdit ? Icons.save : Icons.check),
              label: Text(_isEdit ? 'Save changes' : 'Create QR'),
              onPressed: () => Navigator.pop(
                context,
                _QrConfig(
                  validFrom: _validFrom,
                  duration: _duration,
                  lateAfter: lateAt,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
