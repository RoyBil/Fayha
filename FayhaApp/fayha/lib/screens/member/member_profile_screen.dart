import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/mock_data.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';
import 'house_location_picker_screen.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  bool _editing = false;
  bool _uploadingPhoto = false;
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _travels;
  late List<String> _travelLocations;

  @override
  void initState() {
    super.initState();
    final m = AppState.instance.currentMember!;
    _name = TextEditingController(text: m.name);
    _email = TextEditingController(text: m.email);
    _phone = TextEditingController(text: m.phone);
    _travels = TextEditingController(text: '${m.travelsCount}');
    _travelLocations = List<String>.from(m.travelLocations);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _travels.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final m = AppState.instance.currentMember!;
    final travels = int.tryParse(_travels.text) ?? m.travelsCount;
    AppState.instance.updateProfile(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      travelsCount: travels,
      travelLocations: _travelLocations,
    );
    setState(() => _editing = false);
    try {
      await AuthService.updateProfile(
        id: m.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        travelsCount: travels,
        travelLocations: _travelLocations,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _addTravelLocation() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add a travel location'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Doha, Istanbul, Cairo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added != null && added.isNotEmpty) {
      setState(() => _travelLocations.add(added));
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (xfile == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ext = xfile.name.contains('.')
          ? xfile.name.split('.').last.toLowerCase()
          : 'jpg';
      final m = AppState.instance.currentMember!;
      final url = await AuthService.uploadAvatar(
        memberId: m.id,
        bytes: bytes,
        fileExtension: ext,
      );
      AppState.instance.updateProfile(photoUrl: url);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final m = AppState.instance.currentMember!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Profile'),
            actions: [
              if (_editing)
                TextButton(onPressed: _save, child: const Text('Save'))
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => setState(() => _editing = true),
                ),
            ],
          ),
          body: BrandedBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Avatar(name: m.name, size: 96, photoUrl: m.photoUrl),
                      if (_uploadingPhoto)
                        const SizedBox(
                          width: 96,
                          height: 96,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      Material(
                        color: AppColors.accent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploadingPhoto ? null : _pickPhoto,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader(eyebrow: 'Personal', title: 'Account'),
                const SizedBox(height: 14),
                ElegantCard(
                  child: Column(
                    children: [
                      _Field(
                        label: 'Name',
                        controller: _name,
                        editing: _editing,
                        icon: Icons.person_outline,
                      ),
                      const Divider(height: 24),
                      _Field(
                        label: 'Email',
                        controller: _email,
                        editing: _editing,
                        icon: Icons.mail_outline,
                      ),
                      const Divider(height: 24),
                      _Field(
                        label: 'Phone',
                        controller: _phone,
                        editing: _editing,
                        icon: Icons.phone_outlined,
                      ),
                      const Divider(height: 24),
                      _ReadOnly(
                        icon: Icons.calendar_today,
                        label: 'Joined',
                        value:
                            '${_monthName(m.joinDate.month)} ${m.joinDate.year}',
                      ),
                      const Divider(height: 24),
                      _ReadOnly(
                        icon: Icons.location_city_outlined,
                        label: 'Branch',
                        value: m.branch,
                        hint: 'One branch only — cannot be changed',
                      ),
                      const Divider(height: 24),
                      _ReadOnly(
                        icon: Icons.music_note_outlined,
                        label: 'Voice Section',
                        value: m.voiceSection,
                      ),
                      const Divider(height: 24),
                      _SingerLevelRow(
                        level: m.singerLevel,
                        editing:
                            false, // members can't change it — admins assign
                        onChanged: (_) {},
                      ),
                      const Divider(height: 24),
                      _ReadOnly(
                        icon: Icons.verified_user_outlined,
                        label: 'Account State',
                        value: _stateLabel(m.state),
                        valueColor: m.state == AccountState.active
                            ? AppColors.secondaryDark
                            : AppColors.gray,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  eyebrow: 'Location',
                  title: 'My House on the Map',
                ),
                const SizedBox(height: 14),
                _HouseLocationCard(member: m),
                const SizedBox(height: 28),
                const SectionHeader(
                  eyebrow: 'Stats',
                  title: 'My Choir Activity',
                ),
                const SizedBox(height: 14),
                ElegantCard(
                  child: _NumberField(
                    label: 'Trips taken with the choir',
                    icon: Icons.flight_takeoff,
                    controller: _travels,
                    editing: _editing,
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(
                  eyebrow: 'Travels',
                  title: 'Places Visited',
                ),
                const SizedBox(height: 14),
                ElegantCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_travelLocations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'No locations yet. Tap Edit to add the places you\'ve travelled to with the choir.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _travelLocations
                              .asMap()
                              .entries
                              .map(
                                (e) => Chip(
                                  label: Text(e.value),
                                  backgroundColor: AppColors.accent.withValues(
                                    alpha: 0.15,
                                  ),
                                  side: BorderSide(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  onDeleted: _editing
                                      ? () => setState(
                                          () =>
                                              _travelLocations.removeAt(e.key),
                                        )
                                      : null,
                                ),
                              )
                              .toList(),
                        ),
                      if (_editing) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _addTravelLocation,
                          icon: const Icon(Icons.add_location_alt, size: 16),
                          label: const Text('Add location'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  eyebrow: 'Repertoire',
                  title: 'Song Preferences',
                ),
                const SizedBox(height: 14),
                ElegantCard(
                  child: Column(
                    children: [
                      _SongPicker(
                        label: 'Favorite song',
                        hint: '(after An Tuhibba — that one\'s a given)',
                        currentId: m.favoriteSongId,
                        onPick: AppState.instance.setFavorite,
                      ),
                      const Divider(height: 24),
                      _SongPicker(
                        label: 'Least favorite song',
                        hint:
                            '(besides Immi Namit — we don\'t need to discuss it)',
                        currentId: m.leastFavoriteSongId,
                        onPick: AppState.instance.setLeastFavorite,
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Songs Memorized',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                Text(
                                  '${m.memorizedSongIds.length} of ${MockData.songs.length} pieces',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  eyebrow: 'Wardrobe',
                  title: 'Clothing Inventory',
                ),
                const SizedBox(height: 14),
                ElegantCard(
                  child: Column(
                    children: [
                      ...MockData.clothing.map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.offWhite,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  _clothingIcon(c.type),
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.type,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      'Size ${c.size}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '×${c.quantity}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.offWhite,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.gray,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'View-only. Contact admin to update sizes or quantities.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  eyebrow: 'Account',
                  title: 'Sign Out & Status',
                ),
                const SizedBox(height: 14),
                ElegantCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.exit_to_app,
                          color: AppColors.gray,
                        ),
                        title: const Text('I\'ve left the choir'),
                        subtitle: const Text('Mark your account as inactive'),
                        onTap: () => _showLeaveDialog(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave the choir?'),
        content: const Text(
          'This will flag your account for review. The Maestro will reach out before any final action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Marked for review (mock)')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _stateLabel(AccountState s) {
    switch (s) {
      case AccountState.active:
        return 'Active';
      case AccountState.deactivated:
        return 'Deactivated';
      case AccountState.deleted:
        return 'Deleted';
      case AccountState.pending:
        return 'Pending approval';
    }
  }

  String _monthName(int m) {
    const names = [
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
    return names[m - 1];
  }

  IconData _clothingIcon(String type) {
    switch (type.toLowerCase()) {
      case 'suit':
        return Icons.checkroom;
      case 'shirt':
        return Icons.dry_cleaning;
      case 'cap':
        return Icons.sports_baseball;
      default:
        return Icons.style;
    }
  }
}

/// Row that shows the singer-level badge (Beginner / Intermediate /
/// Professional) and, when [editing] is true, lets the member change it.
class _SingerLevelRow extends StatelessWidget {
  final String? level;
  final bool editing;
  final ValueChanged<String?> onChanged;
  const _SingerLevelRow({
    required this.level,
    required this.editing,
    required this.onChanged,
  });

  static const _options = ['beginner', 'intermediate', 'professional'];
  static String _label(String? v) {
    switch (v) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'professional':
        return 'Professional';
      default:
        return 'Not set';
    }
  }

  static Color _color(String? v) {
    switch (v) {
      case 'beginner':
        return AppColors.gray;
      case 'intermediate':
        return AppColors.primary;
      case 'professional':
        return AppColors.accentDark;
      default:
        return AppColors.gray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.workspace_premium_outlined,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Singer Level', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              if (editing)
                DropdownButton<String?>(
                  value: level,
                  isExpanded: true,
                  hint: const Text('Not set'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not set'),
                    ),
                    for (final v in _options)
                      DropdownMenuItem<String?>(
                        value: v,
                        child: Text(_label(v)),
                      ),
                  ],
                  onChanged: onChanged,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _color(level).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _color(level).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _label(level),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _color(level),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool editing;
  const _NumberField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              if (editing)
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                  ),
                )
              else
                Text(controller.text, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _HouseLocationCard extends StatelessWidget {
  final Member member;
  const _HouseLocationCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final hasLocation = member.houseLat != null && member.houseLng != null;
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLocation ? 'Location saved' : 'No location yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocation
                          ? (member.houseAddress?.isNotEmpty == true
                                ? member.houseAddress!
                                : '${member.houseLat!.toStringAsFixed(4)}, ${member.houseLng!.toStringAsFixed(4)}')
                          : 'Drop a pin on the map so admins know where to send the bus.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HouseLocationPickerScreen(),
                ),
              ),
              icon: Icon(
                hasLocation ? Icons.edit_location_alt : Icons.add_location_alt,
                size: 18,
              ),
              label: Text(
                hasLocation ? 'Update Location' : 'Set My House Location',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool editing;
  const _Field({
    required this.label,
    required this.icon,
    required this.controller,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              if (editing)
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                  ),
                )
              else
                Text(controller.text, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadOnly extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  const _ReadOnly({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(color: valueColor),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SongPicker extends StatelessWidget {
  final String label;
  final String? hint;
  final String? currentId;
  final void Function(String?) onPick;
  const _SongPicker({
    required this.label,
    this.hint,
    required this.currentId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = MockData.songs
        .where((s) => s.id == currentId)
        .cast<RepertoireSong?>()
        .firstWhere((s) => true, orElse: () => null);
    return InkWell(
      onTap: () => _showPicker(context),
      child: Row(
        children: [
          const Icon(
            Icons.favorite_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  current?.title ?? 'Not set',
                  style: theme.textTheme.bodyLarge,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Choose a song',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('None'),
              onTap: () {
                onPick(null);
                Navigator.pop(context);
              },
            ),
            ...MockData.songs.map(
              (s) => ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(s.title),
                subtitle: Text(s.subtitle),
                selected: s.id == currentId,
                onTap: () {
                  onPick(s.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
