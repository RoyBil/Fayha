import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../data/map_data.dart';
import '../../services/admin_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import 'member_detail_screen.dart';

class MembersDirectoryScreen extends StatefulWidget {
  const MembersDirectoryScreen({super.key});

  @override
  State<MembersDirectoryScreen> createState() => _MembersDirectoryScreenState();
}

class _MembersDirectoryScreenState extends State<MembersDirectoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<Member>> _future;

  @override
  void initState() {
    super.initState();
    // 1 "All" tab + one per branch.
    _tabs = TabController(length: ChoirData.branches.length + 1, vsync: this);
    _future = AdminService.fetchRoster();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final f = AdminService.fetchRoster();
    if (!mounted) return;
    setState(() => _future = f);
    await f;
  }

  void _showMember(Member m) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray,
          indicatorColor: AppColors.accent,
          tabs: [
            const Tab(text: 'All'),
            ...ChoirData.branches.map((b) => Tab(text: b)),
          ],
        ),
      ),
      body: BrandedBackground(
        child: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Member>>(
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
                  title: 'Could not load members',
                  message: '${snap.error}',
                ),
              ]);
            }
            final roster = snap.data ?? const <Member>[];
            return TabBarView(
              controller: _tabs,
              children: [
                _MembersList(members: roster, onTap: _showMember),
                ...ChoirData.branches.map(
                  (b) => _MembersList(
                    members: roster.where((m) => m.branch == b).toList(),
                    onTap: _showMember,
                    branchName: b,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  final List<Member> members;
  final void Function(Member) onTap;
  final String? branchName;
  const _MembersList({
    required this.members,
    required this.onTap,
    this.branchName,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        EmptyState(
          icon: Icons.group_outlined,
          title: branchName == null
              ? 'No members yet'
              : 'No $branchName members yet',
          message: 'Once members join, they\'ll show up here.',
        ),
      ]);
    }
    // Sort: Maestro first, then admins, then alphabetical.
    final sorted = [...members]
      ..sort((a, b) {
        int rank(Member m) {
          if (m.role == 'superAdmin') return 0;
          if (m.role == 'admin') return 1;
          return 2;
        }
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final m = sorted[i];
        final color = MapData.colorFor(m.branch);
        final roleLabel = m.role == 'superAdmin'
            ? 'Maestro'
            : (m.role == 'admin' ? 'Admin' : 'Member');
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElegantCard(
            onTap: () => onTap(m),
            child: Row(
              children: [
                Avatar(name: m.name, size: 44, photoUrl: m.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(m.name,
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                          if (m.singerLevel != null) ...[
                            _LevelChip(level: m.singerLevel!),
                            const SizedBox(width: 4),
                          ],
                          if (m.role != 'member')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: AppColors.accentDark
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Text(roleLabel,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentDark)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('${m.branch} · ${m.voiceSection}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.gray),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact singer-level pill: Beginner (grey) / Intermediate (burgundy) /
/// Professional (gold). Used on the directory tiles.
class _LevelChip extends StatelessWidget {
  final String level;
  const _LevelChip({required this.level});

  static String _label(String v) {
    switch (v) {
      case 'beginner': return 'Beginner';
      case 'intermediate': return 'Intermediate';
      case 'professional': return 'Pro';
      default: return v;
    }
  }

  static Color _color(String v) {
    switch (v) {
      case 'beginner': return AppColors.gray;
      case 'intermediate': return AppColors.primary;
      case 'professional': return AppColors.accentDark;
      default: return AppColors.gray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        _label(level),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}
