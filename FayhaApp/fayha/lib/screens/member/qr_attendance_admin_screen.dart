import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/qr_attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';

/// Admin / superAdmin: open or revisit a QR attendance session for a
/// specific branch + day. Active session shows the QR + live list.
/// Closed (or past) session shows just the attendee history.
class QrAttendanceAdminScreen extends StatefulWidget {
  final String branch;
  final DateTime date;
  const QrAttendanceAdminScreen({
    super.key,
    required this.branch,
    required this.date,
  });

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

  bool get _isToday {
    final n = DateTime.now();
    return widget.date.year == n.year &&
        widget.date.month == n.month &&
        widget.date.day == n.day;
  }

  bool get _hasLiveQr =>
      _session != null && !_session!.isExpired;

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
      final s = await QrAttendanceService.latestSession(
        branch: widget.branch,
        date: widget.date,
      );
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
        _liveStream =
            s != null && !s.isExpired ? QrAttendanceService.watchCheckins(s) : null;
        _staticFuture = s == null || s.isExpired
            ? QrAttendanceService.checkinsForDay(
                branch: widget.branch, date: widget.date)
            : null;
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
    if (_hasLiveQr) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final s = await QrAttendanceService.startSession(
        branch: widget.branch,
        date: widget.date,
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
                '${widget.branch} · ${_fmtDate(widget.date)}'
                '${_isToday ? ' · Today' : ''}',
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
                    eyebrow: _hasLiveQr ? 'Live' : 'History',
                    title: 'Attendees',
                    subtitle: _hasLiveQr
                        ? 'Updates as members scan.'
                        : 'All members who scanned on this day.',
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
    // Live QR.
    if (s != null && !s.isExpired) {
      return _qrCard(s);
    }
    // Today, no live session → offer to start one.
    if (_isToday) {
      return _startCard();
    }
    // Past day with closed session, or no session ever.
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
                'Valid 3 hours from start. Members scan to check in; '
                'late after 15 min.',
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
            label: const Text('Start QR session'),
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
                  ? 'No QR session was opened on this day.'
                  : 'QR session ended at ${_fmtTime(s.expiresAt)}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrCard(QrSession s) {
    return ElegantCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.offWhite),
            ),
            child: QrImageView(
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
              Text('Started ${_fmtTime(s.startedAt)}',
                  style: Theme.of(context).textTheme.bodySmall),
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
