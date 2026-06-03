import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/join_requests_service.dart';
import '../../services/messages_service.dart';
import 'attendance_stats_screen.dart';
import 'member_detail_screen.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'compose_event_screen.dart';
import 'compose_poll_screen.dart';
import 'compose_message_screen.dart';
import 'compose_news_screen.dart';
import 'compose_song_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _isSuper ? 6 : 5, vsync: this);
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
            if (_isSuper)
              Tab(child: _TabLabel(text: 'Approvals', badge: _pendingCount)),
            Tab(
                child: _TabLabel(
                    text: 'Join Requests', badge: _newJoinsCount)),
            const Tab(text: 'Members'),
            const Tab(text: 'Stats'),
            const Tab(text: 'Messages'),
            const Tab(text: 'Content'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [
              if (_isSuper) _approvalsTab(),
              _joinRequestsTab(),
              _membersTab(),
              const AttendanceStatsBody(),
              _messagesTab(),
              _contentTab(),
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
        title: Text('${m.name} — singer level'),
        children: [
          for (final entry in const [
            ('beginner', 'Beginner'),
            ('intermediate', 'Intermediate'),
            ('professional', 'Professional'),
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
          subtitle: 'Add songs and news that appear in the audience app.',
        ),
        const SizedBox(height: 16),
        ElegantCard(
          onTap: () async {
            final added = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => const ComposeSongScreen()));
            if (added == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Song added')),
              );
            }
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.library_music, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add a Song', style: theme.textTheme.titleMedium),
                    Text('Title, lyrics, composers, YouTube link',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElegantCard(
          onTap: () async {
            final added = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => const ComposeNewsScreen()));
            if (added == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('News published')),
              );
            }
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.newspaper, color: AppColors.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Post News', style: theme.textTheme.titleMedium),
                    Text('A headline and article for the News tab',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElegantCard(
          onTap: () async {
            final added = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => const ComposeEventScreen()));
            if (added == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event added')),
              );
            }
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_available, color: AppColors.accentDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Event', style: theme.textTheme.titleMedium),
                    Text('A concert or big rehearsal — shows under "Coming Up"',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElegantCard(
          onTap: () async {
            final added = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => const ComposePollScreen()));
            if (added == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Poll published')),
              );
            }
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.poll_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Poll', style: theme.textTheme.titleMedium),
                    Text('Ask members a question with up to 8 options',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
        ),
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
