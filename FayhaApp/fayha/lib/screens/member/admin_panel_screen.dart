import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/join_requests_service.dart';
import '../../services/messages_service.dart';
import '../../services/testimonials_service.dart';
import 'attendance_stats_screen.dart';
import 'member_detail_screen.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'compose_event_screen.dart';
import 'compose_gallery_post_screen.dart';
import 'newsletter_subscribers_screen.dart';
import 'manage_social_posts_screen.dart';
import 'compose_poll_screen.dart';
import 'compose_message_screen.dart';
import 'compose_news_screen.dart';
import 'compose_song_screen.dart';
import 'bus_routes_screen.dart';
import 'trip_groups_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<Member>> _pending;
  late Future<List<Member>> _roster;
  late Future<List<ChoirMessage>> _messages;
  late Future<List<JoinRequest>> _joinRequests;
  bool _working = false;
  int _pendingCount = 0;
  int _newJoinsCount = 0;

  bool get _isSuper =>
      AppState.instance.currentMember?.role == 'superAdmin';
  bool get _isAdmin {
    final r = AppState.instance.currentMember?.role;
    return r == 'admin' || r == 'superAdmin';
  }
  bool get _isEditor {
    final r = AppState.instance.currentMember?.role;
    return r == 'editor' || r == 'superAdmin';
  }

  /// Tabs the current user can see, in left-to-right order.
  /// Each tuple is (label, builder).
  List<(String, Widget Function())> get _availableTabs => [
        if (_isSuper) ('Approvals', _approvalsTab),
        if (_isAdmin) ('Join Requests', _joinRequestsTab),
        if (_isAdmin) ('Members', _membersTab),
        if (_isAdmin) ('Stats', () => const AttendanceStatsBody()),
        if (_isEditor) ('Messages', _messagesTab),
        if (_isEditor || _isAdmin) ('Content', _contentTab),
      ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _availableTabs.length, vsync: this);
    _reload();
  }

  void _reload() {
    setState(() {
      _pending = AdminService.fetchByStatus('pending');
      _roster = AdminService.fetchRoster();
      _messages = MessagesService.fetch();
      _joinRequests = JoinRequestsService.fetchAll();
    });
    _pending.then((list) {
      if (!mounted) return;
      setState(() => _pendingCount = list.length);
    }).catchError((_) {});
    _joinRequests.then((list) {
      if (!mounted) return;
      setState(() =>
          _newJoinsCount = list.where((r) => r.status == 'new').length);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(okMessage)),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray,
          indicatorColor: AppColors.accent,
          isScrollable: true,
          tabs: [
            for (final (label, _) in _availableTabs)
              if (label == 'Approvals')
                Tab(child: _TabLabel(text: label, badge: _pendingCount))
              else if (label == 'Join Requests')
                Tab(child: _TabLabel(text: label, badge: _newJoinsCount))
              else
                Tab(text: label),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [
              for (final (_, build) in _availableTabs) build(),
            ],
          ),
          if (_working)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ===== APPROVALS =====
  Widget _approvalsTab() {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<Member>>(
        future: _pending,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _errorView(snap.error.toString());
          }
          final pending = snap.data ?? const <Member>[];
          if (pending.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.how_to_reg,
                  title: 'No pending sign-ups',
                  message: 'New member registrations will appear here for approval.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const SectionHeader(eyebrow: 'Pending', title: 'Awaiting Approval'),
              const SizedBox(height: 14),
              ...pending.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _pendingCard(m),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _pendingCard(Member m) {
    final theme = Theme.of(context);
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: m.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: theme.textTheme.titleMedium),
                    Text('${m.voiceSection} · ${m.branch}',
                        style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.mail_outline, m.email),
          const SizedBox(height: 6),
          _infoRow(Icons.phone_outlined, m.phone.isEmpty ? '—' : m.phone),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDeny(m),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Deny'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _run(
                    () => AdminService.approve(m.id),
                    'Approved ${m.name}',
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== JOIN REQUESTS =====
  Widget _joinRequestsTab() {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<JoinRequest>>(
        future: _joinRequests,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _errorView(snap.error.toString());
          }
          final requests = snap.data ?? const <JoinRequest>[];
          if (requests.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.mail_outline,
                  title: 'No join requests yet',
                  message:
                      'When someone submits the "Join the Choir" form in the audience app, they\'ll show up here.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final r = requests[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _joinRequestCard(r),
              );
            },
          );
        },
      ),
    );
  }

  Widget _joinRequestCard(JoinRequest r) {
    final theme = Theme.of(context);
    Color statusColor;
    String statusLabel;
    switch (r.status) {
      case 'contacted':
        statusColor = AppColors.secondaryDark;
        statusLabel = 'Contacted';
        break;
      case 'dismissed':
        statusColor = AppColors.gray;
        statusLabel = 'Dismissed';
        break;
      default:
        statusColor = AppColors.accentDark;
        statusLabel = 'New';
    }
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.name, style: theme.textTheme.titleMedium),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _infoRow(Icons.mail_outline, r.email),
          const SizedBox(height: 2),
          _infoRow(Icons.phone_outlined, r.phone),
          const SizedBox(height: 2),
          _infoRow(Icons.place_outlined, r.village),
          if ((r.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.notes!, style: theme.textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: 10),
          Text(_relativeDate(r.createdAt),
              style: theme.textTheme.labelSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              if (r.status != 'contacted')
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _run(
                      () => JoinRequestsService.setStatus(r.id, 'contacted'),
                      'Marked as contacted',
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark contacted'),
                  ),
                ),
              if (r.status != 'contacted') const SizedBox(width: 8),
              if (r.status == 'new')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _run(
                      () => JoinRequestsService.setStatus(r.id, 'dismissed'),
                      'Dismissed',
                    ),
                    icon: const Icon(Icons.archive_outlined, size: 16),
                    label: const Text('Dismiss'),
                  ),
                ),
              if (r.status != 'new')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _run(
                      () => JoinRequestsService.remove(r.id),
                      'Removed',
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  // ===== MEMBERS ROSTER =====
  Widget _membersTab() {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<Member>>(
        future: _roster,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _errorView(snap.error.toString());
          }
          final roster = snap.data ?? const <Member>[];
          if (roster.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No members yet',
                  message: 'Approved members will appear here.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: roster
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _rosterCard(m),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _rosterCard(Member m) {
    final theme = Theme.of(context);
    final active = m.state == AccountState.active;
    final isSelf = m.id == AppState.instance.currentMember?.id;
    return ElegantCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MemberDetailScreen(member: m)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Avatar(name: m.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(m.name, style: theme.textTheme.titleMedium)),
                    if (m.role != 'member') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m.role == 'superAdmin' ? 'Maestro' : 'Admin',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text('${m.voiceSection} · ${m.branch}',
                    style: theme.textTheme.labelMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (active ? AppColors.secondary : AppColors.gray)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              active ? 'Active' : 'Paused',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.secondaryDark : AppColors.gray,
              ),
            ),
          ),
          if (_isAdmin && !isSelf)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.gray),
              onSelected: (action) {
                switch (action) {
                  case 'pause':
                    _run(() => AdminService.deactivate(m.id), 'Paused ${m.name}');
                  case 'reactivate':
                    _run(() => AdminService.reactivate(m.id), 'Reactivated ${m.name}');
                  case 'remove':
                    _confirmRemove(m);
                  case 'makeAdmin':
                    _run(() => AdminService.setRole(m.id, 'admin'),
                        '${m.name} is now an admin');
                  case 'removeAdmin':
                    _run(() => AdminService.setRole(m.id, 'member'),
                        '${m.name} is no longer an admin');
                  case 'makeSuper':
                    _confirmMakeSuper(m);
                  case 'demoteSuper':
                    _run(() => AdminService.setRole(m.id, 'admin'),
                        '${m.name} is no longer a super admin');
                  case 'makeEditor':
                    _run(() => AdminService.setRole(m.id, 'editor'),
                        '${m.name} is now an editor');
                  case 'removeEditor':
                    _run(() => AdminService.setRole(m.id, 'member'),
                        '${m.name} is no longer an editor');
                  case 'setLevel':
                    _pickSingerLevel(m);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'setLevel', child: Text('Set singer level')),
                if (_isSuper) const PopupMenuDivider(),
                if (_isSuper && m.role == 'member')
                  const PopupMenuItem(
                      value: 'makeAdmin', child: Text('Make admin'))
                else if (_isSuper && m.role == 'admin')
                  const PopupMenuItem(
                      value: 'removeAdmin', child: Text('Remove admin')),
                if (_isSuper && m.role != 'editor' && m.role != 'superAdmin')
                  const PopupMenuItem(
                      value: 'makeEditor', child: Text('Make editor'))
                else if (_isSuper && m.role == 'editor')
                  const PopupMenuItem(
                      value: 'removeEditor', child: Text('Remove editor')),
                if (_isSuper && m.role != 'superAdmin')
                  const PopupMenuItem(
                      value: 'makeSuper', child: Text('Make super admin'))
                else if (_isSuper)
                  const PopupMenuItem(
                      value: 'demoteSuper',
                      child: Text('Remove super admin')),
                if (_isSuper) const PopupMenuDivider(),
                if (_isSuper && active)
                  const PopupMenuItem(value: 'pause', child: Text('Pause account'))
                else if (_isSuper)
                  const PopupMenuItem(
                      value: 'reactivate', child: Text('Reactivate account')),
                if (_isSuper)
                  const PopupMenuItem(
                      value: 'remove', child: Text('Remove from choir')),
              ],
            ),
        ],
      ),
    );
  }

  // ===== Dialogs =====
  void _confirmDeny(Member m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deny this sign-up?'),
        content: Text(
            '${m.name} will not be able to access the members area. They can register again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _run(() => AdminService.deny(m.id), 'Denied ${m.name}');
            },
            child: const Text('Deny'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(Member m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from choir?'),
        content: Text(
            '${m.name} will lose access to the members area. This marks them as "left the choir".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _run(() => AdminService.remove(m.id), 'Removed ${m.name}');
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSingerLevel(Member m) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('${m.name} — choir role'),
        children: [
          for (final entry in const [
            ('not_on_stage', 'Not on Stage'),
            ('on_stage', 'On Stage'),
            ('assistant_conductor', 'Assistant Conductor'),
            ('friend', 'Friend'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.$1),
              child: Row(
                children: [
                  Icon(
                    m.singerLevel == entry.$1
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: m.singerLevel == entry.$1
                        ? AppColors.primary
                        : AppColors.gray,
                  ),
                  const SizedBox(width: 12),
                  Text(entry.$2),
                ],
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '__clear__'),
            child: const Text('Clear (not set)',
                style: TextStyle(color: AppColors.gray)),
          ),
        ],
      ),
    );
    if (picked == null) return;
    final value = picked == '__clear__' ? '' : picked;
    _run(
      () => AuthService.updateProfile(id: m.id, singerLevel: value),
      'Updated singer level for ${m.name}',
    );
  }

  void _confirmMakeSuper(Member m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Promote to super admin?'),
        content: Text(
            '${m.name} will gain full super admin permissions: approvals, role changes, live locations — everything you can do.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _run(() => AdminService.setRole(m.id, 'superAdmin'),
                  '${m.name} is now a super admin');
            },
            child: const Text('Promote'),
          ),
        ],
      ),
    );
  }

  // ===== MESSAGES =====
  Widget _messagesTab() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => _reload(),
          child: FutureBuilder<List<ChoirMessage>>(
            future: _messages,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) return _errorView(snap.error.toString());
              final msgs = snap.data ?? const <ChoirMessage>[];
              if (msgs.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No messages yet',
                      message: 'Tap "New message" to send your first announcement.',
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                children: msgs.map(_messageCard).toList(),
              );
            },
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: _compose,
            icon: const Icon(Icons.add),
            label: const Text('New message'),
          ),
        ),
      ],
    );
  }

  Widget _messageCard(ChoirMessage m) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElegantCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(m.audienceLabel,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: AppColors.primary)),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _run(
                    () => MessagesService.delete(m.id),
                    'Message deleted',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(m.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(m.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 8),
            Text(
              '${m.senderName ?? 'Admin'} · ${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _compose() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ComposeMessageScreen()),
    );
    if (sent == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent')),
      );
      _reload();
    }
  }

  // ===== CONTENT =====
  Widget _contentTab() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SectionHeader(
          eyebrow: 'Public App',
          title: 'Manage Content',
          subtitle: 'Add and edit content that appears in the audience app.',
        ),
        const SizedBox(height: 16),

        // ===== Add =====
        if (_isAdmin) ...[
          _ComposeCard(
            icon: Icons.library_music,
            color: AppColors.primary,
            title: 'Add a Song',
            subtitle: 'Title, lyrics, composers, YouTube link',
            onTap: () async {
              final added = await Navigator.push<bool>(context,
                  MaterialPageRoute(
                      builder: (_) => const ComposeSongScreen()));
              if (added == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Song added')),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _ComposeCard(
            icon: Icons.poll_outlined,
            color: AppColors.primary,
            colorAlpha: 0.12,
            title: 'New Poll',
            subtitle: 'Ask members a question with up to 8 options',
            onTap: () async {
              final added = await Navigator.push<bool>(context,
                  MaterialPageRoute(
                      builder: (_) => const ComposePollScreen()));
              if (added == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Poll published')),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _ComposeCard(
            icon: Icons.flight_takeoff,
            color: AppColors.accentDark,
            colorAlpha: 0.12,
            title: 'Trip Groups',
            subtitle: 'Create trip groups, assign members, share visa/hotel/ticket info',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripGroupsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ComposeCard(
            icon: Icons.directions_bus_outlined,
            color: AppColors.secondary,
            colorAlpha: 0.12,
            title: 'Bus Routes',
            subtitle: 'Manage bus routes, stops, and live trip tracking for your branch',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusRoutesScreen()),
            ),
          ),
          const SizedBox(height: 28),
          Text('Manage audience songs',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap any song to edit its details or replace the audio file.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const _ManageAudienceSongsList(),
        ],
        if (_isAdmin && _isEditor) const SizedBox(height: 12),
        if (_isEditor) ...[
          _ComposeCard(
            icon: Icons.newspaper,
            color: AppColors.secondary,
            title: 'Post News',
            subtitle: 'A headline and article for the News tab',
            onTap: () async {
              final added = await Navigator.push<bool>(context,
                  MaterialPageRoute(
                      builder: (_) => const ComposeNewsScreen()));
              if (added == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('News published')),
                );
                _reload();
              }
            },
          ),
          const SizedBox(height: 12),
          _ComposeCard(
            icon: Icons.event_available,
            color: AppColors.accentDark,
            colorAlpha: 0.2,
            title: 'Add Event',
            subtitle: 'A concert or big rehearsal — shows under "Coming Up"',
            onTap: () async {
              final added = await Navigator.push<bool>(context,
                  MaterialPageRoute(
                      builder: (_) => const ComposeEventScreen()));
              if (added == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event added')),
                );
                _reload();
              }
            },
          ),
          const SizedBox(height: 12),
          _ComposeCard(
            icon: Icons.photo_library_outlined,
            color: AppColors.secondaryDark,
            colorAlpha: 0.15,
            title: 'New Gallery Post',
            subtitle: 'A photo + caption for members’ gallery',
            onTap: () async {
              final added = await Navigator.push<bool>(context,
                  MaterialPageRoute(
                      builder: (_) => const ComposeGalleryPostScreen()));
              if (added == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Posted to gallery')),
                );
              }
            },
          ),

          // ===== Manage existing =====
          const SizedBox(height: 28),
          Text('Manage existing', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap any item to edit it, or swipe / long-press to delete.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _ManageNewsList(onChanged: _reload),
          const SizedBox(height: 16),
          _ManageEventsList(onChanged: _reload),
          const SizedBox(height: 16),
          const _ManageTestimonialsList(),
          const SizedBox(height: 16),
          _ComposeCard(
            icon: Icons.mail_outline,
            color: AppColors.primaryDark,
            colorAlpha: 0.12,
            title: 'Newsletter Subscribers',
            subtitle:
                'See every email submitted from the audience homepage',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NewsletterSubscribersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ComposeCard(
            icon: Icons.share_outlined,
            color: AppColors.accentDark,
            colorAlpha: 0.15,
            title: 'Social posts',
            subtitle:
                'Pick which Instagram & Facebook posts surface to the audience',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ManageSocialPostsScreen()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _errorView(String error) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
          message: error,
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: _reload,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.gray),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      );
}

/// Tab label with an optional little count pill next to the text.
class _TabLabel extends StatelessWidget {
  final String text;
  final int badge;
  const _TabLabel({required this.text, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (badge > 0) ...[
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge > 9 ? '9+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.dark,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Reusable "Add a …" tile used inside the Content tab.
class _ComposeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double colorAlpha;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ComposeCard({
    required this.icon,
    required this.color,
    this.colorAlpha = 0.1,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
              color: color.withValues(alpha: colorAlpha),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
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

/// Editor-only: list of existing news posts with tap-to-edit + delete.
class _ManageNewsList extends StatefulWidget {
  final VoidCallback onChanged;
  const _ManageNewsList({required this.onChanged});

  @override
  State<_ManageNewsList> createState() => _ManageNewsListState();
}

class _ManageNewsListState extends State<_ManageNewsList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.listNews();
  }

  void _reload() {
    final f = AdminService.listNews();
    setState(() { _future = f; });
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this news post?'),
        content: Text('"${row['title']}" will be removed permanently.'),
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
      await AdminService.deleteNews(row['id'] as String);
      _reload();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ComposeNewsScreen(existing: row)),
    );
    if (saved == true) {
      _reload();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rows = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('News',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.secondary,
                    letterSpacing: 0.8,
                  )),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('No news posts yet.',
                    style: theme.textTheme.bodySmall),
              )
            else
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElegantCard(
                      onTap: () => _openEdit(r),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          if ((r['poster_url'] as String?)?.isNotEmpty == true)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                r['poster_url'] as String,
                                width: 50, height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 50, height: 50),
                              ),
                            )
                          else
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.secondary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.newspaper,
                                  color: AppColors.secondary),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text((r['title'] as String?) ?? '',
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  (r['date_label'] as String?) ?? '',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.gray),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _confirmDelete(r),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

/// Editor-only: list of existing events with tap-to-edit + delete.
class _ManageEventsList extends StatefulWidget {
  final VoidCallback onChanged;
  const _ManageEventsList({required this.onChanged});

  @override
  State<_ManageEventsList> createState() => _ManageEventsListState();
}

class _ManageEventsListState extends State<_ManageEventsList> {
  late Future<List<Map<String, dynamic>>> _future;

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  @override
  void initState() {
    super.initState();
    _future = AdminService.listEvents();
  }

  void _reload() {
    final f = AdminService.listEvents();
    setState(() { _future = f; });
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this event?'),
        content: Text('"${row['title']}" will be removed permanently.'),
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
      await AdminService.deleteEvent(row['id'] as String);
      _reload();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ComposeEventScreen(existing: row)),
    );
    if (saved == true) {
      _reload();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rows = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Events',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accentDark,
                    letterSpacing: 0.8,
                  )),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('No events yet.',
                    style: theme.textTheme.bodySmall),
              )
            else
              ...rows.map((r) {
                final d = DateTime.parse(r['starts_at'] as String).toLocal();
                final isRehearsal = (r['kind'] as String?) == 'rehearsal';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElegantCard(
                    onTap: () => _openEdit(r),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isRehearsal
                                ? AppColors.secondaryDark
                                : AppColors.accentDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _months[d.month - 1].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                              Text('${d.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text((r['title'] as String?) ?? '',
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${isRehearsal ? "Rehearsal" : "Concert"} · ${(r['location'] as String?) ?? ''}',
                                style: theme.textTheme.labelSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.gray),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmDelete(r),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

/// Editor / super admin: see every testimonial, set importance, delete.
class _ManageTestimonialsList extends StatefulWidget {
  const _ManageTestimonialsList();

  @override
  State<_ManageTestimonialsList> createState() =>
      _ManageTestimonialsListState();
}

class _ManageTestimonialsListState extends State<_ManageTestimonialsList> {
  List<Testimonial>? _rows;
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await TestimonialsService.fetchAll();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
    }
  }

  Future<void> _setImportance(
      Testimonial t, TestimonialImportance i) async {
    if (t.id == null || t.importance == i || _busyId != null) return;
    // Optimistic update: flip the chip instantly so the UI feels snappy.
    setState(() {
      t.importance = i;
      _busyId = t.id;
    });
    try {
      await TestimonialsService.setImportance(t.id!, i);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $e')),
      );
      // Revert by re-fetching the row.
      await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmDelete(Testimonial t) async {
    if (t.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this testimonial?'),
        content: Text('"${t.author}" will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TestimonialsService.delete(t.id!);
      if (!mounted) return;
      setState(() => _rows = _rows?.where((r) => r.id != t.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _rows ?? const <Testimonial>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Testimonials',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('No testimonials yet.',
                style: theme.textTheme.bodySmall),
          )
        else
          ...rows.map((t) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TestimonialAdminCard(
                  t: t,
                  onSetImportance: (i) => _setImportance(t, i),
                  onDelete: () => _confirmDelete(t),
                ),
              )),
      ],
    );
  }
}

class _TestimonialAdminCard extends StatelessWidget {
  final Testimonial t;
  final ValueChanged<TestimonialImportance> onSetImportance;
  final VoidCallback onDelete;
  const _TestimonialAdminCard({
    required this.t,
    required this.onSetImportance,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(t.photoUrl!),
                  backgroundColor: AppColors.offWhite,
                )
              else
                Avatar(name: t.author, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.author,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if ((t.email ?? '').isNotEmpty)
                      Text(t.email!,
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.gray),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.body,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              _importanceChip(
                context,
                label: 'Most important',
                icon: Icons.star_rounded,
                value: TestimonialImportance.featured,
                color: AppColors.accentDark,
              ),
              _importanceChip(
                context,
                label: 'Normal',
                icon: Icons.check_circle_outline,
                value: TestimonialImportance.normal,
                color: AppColors.secondaryDark,
              ),
              _importanceChip(
                context,
                label: 'Not important',
                icon: Icons.visibility_off_outlined,
                value: TestimonialImportance.hidden,
                color: AppColors.gray,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _importanceChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required TestimonialImportance value,
    required Color color,
  }) {
    final selected = t.importance == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14,
              color: selected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSetImportance(value),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Admin/SuperAdmin: list of audience songs with tap-to-edit + delete.
class _ManageAudienceSongsList extends StatefulWidget {
  const _ManageAudienceSongsList();

  @override
  State<_ManageAudienceSongsList> createState() =>
      _ManageAudienceSongsListState();
}

class _ManageAudienceSongsListState extends State<_ManageAudienceSongsList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final f = AdminService.fetchAudienceSongs();
    setState(() { _future = f; });
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this song?'),
        content: Text('"${row['title']}" will be removed permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.deleteSong(row['id'] as String);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    final song = RepertoireSong(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      subtitle: (row['subtitle'] as String?) ?? '',
      composers: (row['composers'] as String?) ?? '',
      lyrics: (row['lyrics'] as String?) ?? '',
      description: row['description'] as String?,
      youtubeUrl: row['youtube_url'] as String?,
      audioUrl: row['audio_url'] as String?,
    );
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ComposeSongScreen(existingAudience: song)),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text('Error loading songs: ${snap.error}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
          );
        }
        final rows = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Audience Songs',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  )),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('No audience songs yet.',
                    style: theme.textTheme.bodySmall),
              )
            else
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElegantCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              (r['audio_url'] as String?) != null
                                  ? Icons.audiotrack
                                  : Icons.music_note_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((r['title'] as String?) ?? '',
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if ((r['subtitle'] as String?)?.isNotEmpty ==
                                    true)
                                  Text(
                                    r['subtitle'] as String,
                                    style: theme.textTheme.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.primary),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _openEdit(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.gray),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _confirmDelete(r),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
