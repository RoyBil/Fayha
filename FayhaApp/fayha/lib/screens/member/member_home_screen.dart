import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../services/alert_counts_service.dart';
import '../../services/concerts_service.dart';
import '../../services/live_location_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';
import 'attendance_history_screen.dart';
import 'attendance_screen.dart';
import 'messages_screen.dart';
import 'polls_screen.dart';
import 'testimonials_member_screen.dart';
import 'member_profile_screen.dart';
import 'admin_panel_screen.dart';
import 'house_location_picker_screen.dart';
import 'members_directory_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  late Future<List<Concert>> _upcoming;
  int _unvotedPolls = 0;
  int _unreadDms = 0;
  int _adminInbox = 0;
  int _lastStatsVersion = -1;

  @override
  void initState() {
    super.initState();
    _upcoming = ConcertsService.fetchUpcoming();
    _lastStatsVersion = AppState.instance.statsVersion;
    _reloadAlertCounts();
    AppState.instance.addListener(_onAppStateChange);
  }

  Future<void> _reloadAlertCounts() async {
    final results = await Future.wait([
      AlertCountsService.unvotedPolls(),
      AlertCountsService.unreadDms(),
      AlertCountsService.adminInbox(),
    ]);
    if (!mounted) return;
    setState(() {
      _unvotedPolls = results[0];
      _unreadDms = results[1];
      _adminInbox = results[2];
    });
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChange);
    super.dispose();
  }

  void _onAppStateChange() {
    final v = AppState.instance.statsVersion;
    if (v != _lastStatsVersion) {
      _lastStatsVersion = v;
      _reloadAlertCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final m = AppState.instance.currentMember!;
        final theme = Theme.of(context);
        final years = DateTime.now().year - m.joinDate.year;
        final memorized = m.memorizedSongIds.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _ProfileHeader(member: m, years: years),
            if (!m.isMaestro) ...[
            const SizedBox(height: 14),
            _LiveLocationCard(
              enabled: m.liveLocationEnabled,
              onEnable: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await LiveLocationService.instance.enable();
                  if (!mounted) return;
                  setState(() {});
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Your live location is now shared with Maestro')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Could not enable: $e')),
                  );
                }
              },
              onDisable: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await LiveLocationService.instance.disable();
                  if (!mounted) return;
                  setState(() {});
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Live location sharing turned off')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Could not turn off: $e')),
                  );
                }
              },
            ),
            ],
            if (m.houseLat == null || m.houseLng == null) ...[
              const SizedBox(height: 14),
              _HouseLocationPrompt(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HouseLocationPickerScreen()),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Trips', value: '${m.travelsCount}')),
                const SizedBox(width: 10),
                Expanded(child: _Stat(label: 'Songs', value: '$memorized')),
                const SizedBox(width: 10),
                Expanded(child: _Stat(label: 'Years', value: '$years')),
                const SizedBox(width: 10),
                Expanded(child: _LevelStat(level: m.singerLevel)),
              ],
            ),
            const SizedBox(height: 28),
            const SectionHeader(eyebrow: 'Member Area', title: 'Quick Access'),
            const SizedBox(height: 16),
            _QuickGrid(
              tiles: [
                _Tile(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MemberProfileScreen())),
                ),
                _Tile(
                  icon: Icons.checklist_rtl,
                  label: 'Attendance',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => m.isAdmin
                          ? const AttendanceScreen()
                          : const AttendanceHistoryScreen(),
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.poll_outlined,
                  label: 'Polls',
                  badge: _unvotedPolls,
                  onTap: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PollsScreen()));
                    _reloadAlertCounts();
                  },
                ),
                _Tile(
                  icon: Icons.forum_outlined,
                  label: m.isMaestro ? 'Messages' : 'Message Maestro',
                  badge: _unreadDms,
                  onTap: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const MessagesScreen()));
                    await AlertCountsService.markDmsSeen();
                    _reloadAlertCounts();
                  },
                ),
                _Tile(
                  icon: Icons.format_quote,
                  label: 'Testimonials',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TestimonialsMemberScreen())),
                ),
                _Tile(
                  icon: Icons.groups_outlined,
                  label: 'Members',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MembersDirectoryScreen()),
                  ),
                ),
                if (m.isAdmin)
                  _Tile(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Admin',
                    badge: _adminInbox,
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminPanelScreen()));
                      _reloadAlertCounts();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 32),
            const SectionHeader(
                eyebrow: 'Coming Up', title: 'Concerts & Rehearsals'),
            const SizedBox(height: 12),
            FutureBuilder<List<Concert>>(
              future: _upcoming,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final events = snap.data ?? const <Concert>[];
                if (events.isEmpty) {
                  return ElegantCard(
                    background: AppColors.offWhite,
                    child: Text('No upcoming events yet.',
                        style: theme.textTheme.bodyMedium),
                  );
                }
                return Column(
                  children: events
                      .take(4)
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _eventCard(theme, e),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _eventCard(ThemeData theme, Concert e) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final h = e.date.hour > 12 ? e.date.hour - 12 : (e.date.hour == 0 ? 12 : e.date.hour);
    final time = '$h:${e.date.minute.toString().padLeft(2, '0')} ${e.date.hour >= 12 ? 'PM' : 'AM'}';
    return ElegantCard(
      background: AppColors.offWhite,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(months[e.date.month - 1],
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.accentLight, letterSpacing: 1)),
                Text('${e.date.day}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: AppColors.cream, height: 1)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (e.isRehearsal ? AppColors.secondary : AppColors.accentDark)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    e.isRehearsal ? 'BIG REHEARSAL' : 'CONCERT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: e.isRehearsal
                          ? AppColors.secondaryDark
                          : AppColors.accentDark,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(e.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('${e.location} · $time',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Member member;
  final int years;
  const _ProfileHeader({required this.member, required this.years});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Avatar(
            name: member.name,
            size: 64,
            background: AppColors.cream,
            foreground: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accentLight,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${member.voiceSection} · ${member.branch} branch',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.cream.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$years ${years == 1 ? 'year' : 'years'} with the choir',
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.offWhite),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.gray,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat box that shows the singer-level badge in the same place
/// the other stats live. Coloured by level (grey / burgundy / gold).
class _LevelStat extends StatelessWidget {
  final String? level;
  const _LevelStat({required this.level});

  static String _label(String? v) {
    switch (v) {
      case 'beginner': return 'Beginner';
      case 'intermediate': return 'Inter.';
      case 'professional': return 'Pro';
      default: return 'Not set';
    }
  }

  static Color _color(String? v) {
    switch (v) {
      case 'beginner': return AppColors.gray;
      case 'intermediate': return AppColors.primary;
      case 'professional': return AppColors.accentDark;
      default: return AppColors.gray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _color(level);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.offWhite),
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, size: 12, color: c),
                const SizedBox(width: 4),
                Text(
                  _label(level),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'LEVEL',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.gray,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });
}

class _QuickGrid extends StatelessWidget {
  final List<_Tile> tiles;
  const _QuickGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1,
      children: tiles.map((t) => _TileCard(tile: t)).toList(),
    );
  }
}

class _TileCard extends StatelessWidget {
  final _Tile tile;
  const _TileCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tile.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.offWhite),
          ),
          padding: const EdgeInsets.all(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tile.icon, color: AppColors.primary, size: 26),
                  const SizedBox(height: 8),
                  Text(
                    tile.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.dark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              if (tile.badge > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cream, width: 1.5),
                    ),
                    child: Text(
                      tile.badge > 9 ? '9+' : '${tile.badge}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.dark,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveLocationCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  const _LiveLocationCard({
    required this.enabled,
    required this.onEnable,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (enabled) {
      // Already on — show a calm "sharing" pill with a small off button.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.secondaryDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sharing your location with Maestro',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('Updates every 30 seconds while the app is open.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onDisable,
              icon: const Icon(Icons.power_settings_new, size: 16),
              label: const Text('Turn off'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryDark,
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: AppColors.accent.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEnable,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.accentDark.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share_location,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Share my live location with Maestro',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Only the Maestro can see it. Cannot be turned off later.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseLocationPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _HouseLocationPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.accentDark.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_location_alt,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your house location',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Help admins plan bus pickups and rehearsal logistics.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
        ),
      ),
    );
  }
}
