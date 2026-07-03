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
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  bool _loading = true;
  bool _saving = false;
  bool _cancelled = false;
  List<Member> _members = [];
  final Map<String, bool> _present = {};
  final Map<String, int> _lateMinutes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await AttendanceService.branchMembers(widget.branch);
      final sheet = await AttendanceService.loadSheet(
        widget.branch,
        widget.date,
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _cancelled = sheet.status == 'cancelled';
        for (final m in members) {
          _present[m.id] = sheet.present[m.id] ?? true;
          _lateMinutes[m.id] = sheet.lateMinutes[m.id] ?? 0;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load: $e')));
    }
  }

  Future<void> _editLateMinutes(Member m) async {
    final controller = TextEditingController(
      text: (_lateMinutes[m.id] ?? 0).toString(),
    );
    final mins = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${m.name} — minutes late'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Minutes late',
            suffixText: 'min',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (mins == null) return;
    setState(() {
      _present[m.id] = true;
      _lateMinutes[m.id] = mins < 0 ? 0 : mins;
    });
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
        lateMinutes: _lateMinutes,
      );
      // Tell stat-watching screens (member home) to refetch.
      AppState.instance.bumpStats();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.date;
    final presentCount = _present.values.where((v) => v).length;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.branch} Attendance')),
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
                      Text(
                        AttendanceService.sessionTime,
                        style: theme.textTheme.bodySmall,
                      ),
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
                              child: Text(
                                'No active members in this branch yet.',
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                            children: [
                              Text(
                                '$presentCount of ${_members.length} present',
                                style: theme.textTheme.labelMedium,
                              ),
                              const SizedBox(height: 10),
                              ..._members.map((m) {
                                final here = _present[m.id] ?? true;
                                final late = (_lateMinutes[m.id] ?? 0) > 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ElegantCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Avatar(
                                          name: m.name,
                                          size: 38,
                                          photoUrl: m.photoUrl,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.name,
                                                style:
                                                    theme.textTheme.titleSmall,
                                              ),
                                              Text(
                                                here && late
                                                    ? '${m.voiceSection} · late ${_lateMinutes[m.id]} min'
                                                    : m.voiceSection,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: here && late
                                                          ? AppColors.accentDark
                                                          : null,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _StateChip(
                                          label: 'Absent',
                                          selected: !here,
                                          color: AppColors.gray,
                                          onTap: () => setState(() {
                                            _present[m.id] = false;
                                            _lateMinutes[m.id] = 0;
                                          }),
                                        ),
                                        const SizedBox(width: 4),
                                        _StateChip(
                                          label: late
                                              ? 'Late ${_lateMinutes[m.id]}m'
                                              : 'Late',
                                          selected: here && late,
                                          color: AppColors.accentDark,
                                          onTap: () => _editLateMinutes(m),
                                        ),
                                        const SizedBox(width: 4),
                                        _StateChip(
                                          label: 'Present',
                                          selected: here && !late,
                                          color: AppColors.secondaryDark,
                                          onTap: () => setState(() {
                                            _present[m.id] = true;
                                            _lateMinutes[m.id] = 0;
                                          }),
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
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cream,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text('Save Attendance'),
              ),
            ),
    );
  }
}

/// Small selectable pill used as a 3-way Absent / Late / Present picker.
class _StateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StateChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
