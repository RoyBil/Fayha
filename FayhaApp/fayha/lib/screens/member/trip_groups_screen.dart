import 'package:flutter/material.dart';
import '../../services/trip_groups_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'trip_group_detail_screen.dart';

class TripGroupsScreen extends StatefulWidget {
  const TripGroupsScreen({super.key});

  @override
  State<TripGroupsScreen> createState() => _TripGroupsScreenState();
}

class _TripGroupsScreenState extends State<TripGroupsScreen> {
  late Future<List<TripGroup>> _groups;
  final bool _isAdmin = AppState.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _groups = _isAdmin
          ? TripGroupsService.fetchAll()
          : TripGroupsService.fetchMine();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Groups'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New trip group',
              onPressed: _createGroup,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: FutureBuilder<List<TripGroup>>(
          future: _groups,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final list = snap.data ?? const <TripGroup>[];
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.flight_outlined,
                title: _isAdmin ? 'No trip groups yet' : 'No trips assigned',
                message: _isAdmin
                    ? 'Tap + to create a new trip group.'
                    : 'You have not been added to any trip group yet.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                SectionHeader(
                  eyebrow: _isAdmin ? 'Manage' : 'Your Trips',
                  title: 'Trip Groups',
                  subtitle: _isAdmin
                      ? 'Create groups, assign members, and share trip details.'
                      : 'Access documents and trip information for each trip.',
                ),
                const SizedBox(height: 20),
                ...list.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupCard(
                      group: g,
                      isAdmin: _isAdmin,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TripGroupDetailScreen(group: g),
                          ),
                        );
                        _load();
                      },
                      onDelete: _isAdmin ? () => _confirmDelete(g) : null,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _GroupFormDialog(),
    );
    if (result == null) return;
    try {
      await TripGroupsService.create(
        name: result['name'] as String,
        description: result['description'] as String?,
        destination: result['destination'] as String?,
        departureDate: result['departure_date'] as DateTime?,
        returnDate: result['return_date'] as DateTime?,
        requiredDocTypes:
            result['required_doc_types'] as List<TripDocumentType>?,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create group: $e')));
    }
  }

  Future<void> _confirmDelete(TripGroup g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('Delete "${g.name}" and all its data?'),
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
    if (confirmed != true) return;
    try {
      await TripGroupsService.delete(g.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }
}

class _GroupCard extends StatelessWidget {
  final TripGroup group;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _GroupCard({
    required this.group,
    required this.isAdmin,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.flight_takeoff,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: theme.textTheme.titleMedium),
                if (group.destination != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: AppColors.gray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        group.destination!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                if (group.departureDate != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: AppColors.gray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _dateRange(group.departureDate!, group.returnDate),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (group.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    group.description!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.gray,
                size: 20,
              ),
              onPressed: onDelete,
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }

  String _dateRange(DateTime from, DateTime? to) {
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    return to != null ? '${fmt(from)} – ${fmt(to)}' : fmt(from);
  }
}

// ── Group creation dialog ──────────────────────────────────────────────────────

class _GroupFormDialog extends StatefulWidget {
  const _GroupFormDialog();

  @override
  State<_GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<_GroupFormDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _dest = TextEditingController();
  DateTime? _departure;
  DateTime? _returnDate;
  final Set<TripDocumentType> _requiredTypes = {
    TripDocumentType.passport,
    TripDocumentType.profilePhoto,
  };

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _dest.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDeparture) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDeparture ? (_departure ?? now) : (_returnDate ?? now),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isDeparture) {
        _departure = picked;
      } else {
        _returnDate = picked;
      }
    });
  }

  String _fmt(DateTime? d) =>
      d == null ? 'Pick date' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New Trip Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Group name *'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dest,
              decoration: const InputDecoration(labelText: 'Destination'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 14),
            Text('Travel dates', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.flight_takeoff, size: 16),
                    label: Text(_fmt(_departure)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.flight_land, size: 16),
                    label: Text(_fmt(_returnDate)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Required documents', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: TripDocumentType.values
                  .where((t) => t != TripDocumentType.other)
                  .map(
                    (t) => FilterChip(
                      label: Text(t.label),
                      selected: _requiredTypes.contains(t),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _requiredTypes.add(t);
                        } else {
                          _requiredTypes.remove(t);
                        }
                      }),
                    ),
                  )
                  .toList(),
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
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, {
              'name': name,
              'description': _desc.text.trim().isEmpty
                  ? null
                  : _desc.text.trim(),
              'destination': _dest.text.trim().isEmpty
                  ? null
                  : _dest.text.trim(),
              'departure_date': _departure,
              'return_date': _returnDate,
              'required_doc_types': _requiredTypes.toList(),
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
