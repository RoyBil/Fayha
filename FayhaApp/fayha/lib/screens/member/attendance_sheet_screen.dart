import 'package:flutter/material.dart';
import '../../services/attendance_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';

class AttendanceSheetScreen extends StatefulWidget {
  final String branch;
  final DateTime date;
  const AttendanceSheetScreen({
    super.key,
    required this.branch,
    required this.date,
  });

  @override
  State<AttendanceSheetScreen> createState() => _AttendanceSheetScreenState();
}

class _AttendanceSheetScreenState extends State<AttendanceSheetScreen> {
  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  static const _weekdays = [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ];

  bool _loading = true;
  bool _saving = false;
  bool _cancelled = false;
  List<Member> _members = [];
  final Map<String, bool> _present = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await AttendanceService.branchMembers(widget.branch);
      final sheet = await AttendanceService.loadSheet(widget.branch, widget.date);
      if (!mounted) return;
      setState(() {
        _members = members;
        _cancelled = sheet.status == 'cancelled';
        for (final m in members) {
          // default present; use saved value if the sheet exists
          _present[m.id] = sheet.present[m.id] ?? true;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Whoever is recording the attendance was clearly at the rehearsal,
      // so always mark them present (overrides any accidental untick).
      final me = AppState.instance.currentMember;
      final present = Map<String, bool>.from(_present);
      if (me != null && _members.any((m) => m.id == me.id)) {
        present[me.id] = true;
      }
      await AttendanceService.save(
        branch: widget.branch,
        date: widget.date,
        cancelled: _cancelled,
        present: present,
      );
      // Tell stat-watching screens (member home) to refetch.
      AppState.instance.bumpStats();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.date;
    final presentCount = _present.values.where((v) => v).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.branch} Attendance'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.offWhite,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(AttendanceService.sessionTime,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('No rehearsal this day'),
                  subtitle: const Text('The branch did not gather'),
                  value: _cancelled,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _cancelled = v),
                ),
                const Divider(height: 1),
                if (_cancelled)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'This day is marked as no rehearsal.\nAttendance is not recorded.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: _members.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No active members in this branch yet.'),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                            children: [
                              Text('$presentCount of ${_members.length} present',
                                  style: theme.textTheme.labelMedium),
                              const SizedBox(height: 10),
                              ..._members.map((m) {
                                final here = _present[m.id] ?? true;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ElegantCard(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Row(
                                      children: [
                                        Avatar(name: m.name, size: 38,
                                            photoUrl: m.photoUrl),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(m.name,
                                                  style: theme.textTheme.titleSmall),
                                              Text(m.voiceSection,
                                                  style: theme.textTheme.labelSmall),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          here ? 'Present' : 'Absent',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: here
                                                ? AppColors.secondaryDark
                                                : AppColors.gray,
                                          ),
                                        ),
                                        Switch(
                                          value: here,
                                          activeColor: AppColors.secondary,
                                          onChanged: (v) =>
                                              setState(() => _present[m.id] = v),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream))
                    : const Icon(Icons.save, size: 18),
                label: const Text('Save Attendance'),
              ),
            ),
    );
  }
}
