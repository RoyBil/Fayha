import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/choir_history_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';
import 'compose_choir_history_trip_screen.dart';

class ChoirHistoryTripDetailScreen extends StatefulWidget {
  final ChoirHistoryTrip trip;
  const ChoirHistoryTripDetailScreen({super.key, required this.trip});

  @override
  State<ChoirHistoryTripDetailScreen> createState() =>
      _ChoirHistoryTripDetailScreenState();
}

class _ChoirHistoryTripDetailScreenState
    extends State<ChoirHistoryTripDetailScreen> {
  late ChoirHistoryTrip _trip;
  bool _participated = false;
  bool _togglingParticipation = false;
  int _participantCount = 0;

  bool get _canEdit => AppState.instance.isEditor || AppState.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final parts = await ChoirHistoryService.fetchMyParticipations();
    final count = await ChoirHistoryService.fetchParticipantCount(_trip.id);
    if (!mounted) return;
    setState(() {
      _participated = parts.contains(_trip.id);
      _participantCount = count;
    });
  }

  Future<void> _reloadTrip() async {
    final trips = await ChoirHistoryService.fetchAll();
    final fresh = trips.where((t) => t.id == _trip.id).firstOrNull;
    if (fresh != null && mounted) setState(() => _trip = fresh);
  }

  Future<void> _toggleParticipation() async {
    if (_togglingParticipation) return;
    setState(() => _togglingParticipation = true);
    try {
      if (_participated) {
        await ChoirHistoryService.leaveTrip(_trip.id);
        if (mounted) {
          setState(() {
            _participated = false;
            _participantCount = (_participantCount - 1).clamp(0, 9999);
          });
        }
      } else {
        await ChoirHistoryService.joinTrip(_trip.id);
        if (mounted) {
          setState(() {
            _participated = true;
            _participantCount++;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    } finally {
      if (mounted) setState(() => _togglingParticipation = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'Delete "${_trip.name}" and all its activities and photos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ChoirHistoryService.delete(_trip.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _deleteActivity(ChoirHistoryActivity a) async {
    try {
      await ChoirHistoryService.deleteActivity(a.id);
      await _reloadTrip();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _addActivity() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddActivityDialog(),
    );
    if (result == null) return;
    try {
      await ChoirHistoryService.addActivity(
        tripId: _trip.id,
        type: result['type'] as HistoryActivityType,
        title: result['title'] as String,
        description: result['description'] as String?,
        activityDate: result['date'] as DateTime?,
      );
      await _reloadTrip();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add activity: $e')));
      }
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Color _activityColor(HistoryActivityType t) => switch (t) {
    HistoryActivityType.concert => AppColors.primary,
    HistoryActivityType.festival => AppColors.accentDark,
    HistoryActivityType.competition => AppColors.secondary,
    HistoryActivityType.rehearsal => AppColors.secondaryDark,
    HistoryActivityType.workshop => AppColors.gray,
    HistoryActivityType.other => AppColors.gray,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_trip.name),
        actions: [
          if (_canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit trip',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ComposeChoirHistoryTripScreen(existing: _trip),
                  ),
                );
                if (updated == true) await _reloadTrip();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete trip',
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: BrandedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // ── Info card ────────────────────────────────────────────────────
            ElegantCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.flight_takeoff,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_trip.name, style: theme.textTheme.titleLarge),
                            Text(
                              _trip.location,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: _trip.endDate != null
                        ? '${_fmt(_trip.startDate)} – ${_fmt(_trip.endDate!)}'
                        : _fmt(_trip.startDate),
                  ),
                  if (_participantCount > 0) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.people_outline,
                      text:
                          '$_participantCount choir member${_participantCount == 1 ? '' : 's'} on this trip',
                    ),
                  ],
                  if (_trip.description != null &&
                      _trip.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _trip.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Participation card ───────────────────────────────────────────
            ElegantCard(
              child: Row(
                children: [
                  Icon(
                    _participated
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _participated ? AppColors.secondary : AppColors.gray,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _participated
                              ? 'You were on this trip'
                              : 'Were you on this trip?',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          _participated
                              ? 'Saved to your personal choir history.'
                              : 'Tap to add it to your personal history.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (_togglingParticipation)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(
                      onPressed: _toggleParticipation,
                      child: Text(_participated ? 'Remove' : 'Add'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Activities ───────────────────────────────────────────────────
            SectionHeader(
              eyebrow: 'Programme',
              title: 'Activities',
              subtitle: _trip.activities.isEmpty
                  ? 'No activities added yet.'
                  : null,
            ),
            const SizedBox(height: 12),
            ..._trip.activities.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElegantCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _activityColor(a.type).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          a.type.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _activityColor(a.type),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: theme.textTheme.bodyMedium),
                            if (a.description != null &&
                                a.description!.isNotEmpty)
                              Text(
                                a.description!,
                                style: theme.textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (a.activityDate != null)
                        Text(
                          _fmt(a.activityDate!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.gray,
                          ),
                        ),
                      if (_canEdit)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.gray,
                          ),
                          onPressed: () => _deleteActivity(a),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_canEdit)
              OutlinedButton.icon(
                onPressed: _addActivity,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add activity'),
              ),

            // ── Photos ───────────────────────────────────────────────────────
            if (_trip.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionHeader(eyebrow: 'Media', title: 'Photos'),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: _trip.photoUrls.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(_trip.photoUrls[i]),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _trip.photoUrls[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.offWhite,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.gray,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Info row helper ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: AppColors.gray),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
    ],
  );
}

// ── Add activity dialog ───────────────────────────────────────────────────────

class _AddActivityDialog extends StatefulWidget {
  const _AddActivityDialog();

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  HistoryActivityType _type = HistoryActivityType.concert;
  DateTime? _date;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<HistoryActivityType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: HistoryActivityType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now(),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                _date != null
                    ? '${_date!.day}/${_date!.month}/${_date!.year}'
                    : 'Pick date (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, {
              'type': _type,
              'title': title,
              'description': _desc.text.trim().isEmpty
                  ? null
                  : _desc.text.trim(),
              'date': _date,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
