import 'package:flutter/material.dart';
import '../../services/dm_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import 'maestro_dm_screen.dart';

/// Routing entry point for direct messages.
///
/// Members see a list of their conversations with admins, plus a
/// button to start a new conversation with any admin.
///
/// Admins and the Maestro see an inbox of all members who have
/// messaged them specifically.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool get _isAdmin {
    final r = AppState.instance.currentMember?.role;
    return r == 'admin' || r == 'superAdmin';
  }

  late Future<List<DmThread>> _threads;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final me = AppState.instance.currentMember!;
    setState(() {
      _threads = _isAdmin
          ? DmService.inboxAndOutboxForAdmin(me.id)
          : DmService.myAdminThreads(me.id);
    });
  }

  Future<void> _openNew() async {
    final me = AppState.instance.currentMember!;
    final picked = await Navigator.push<AdminContact>(
      context,
      MaterialPageRoute(builder: (_) => const _AdminPickerScreen()),
    );
    if (picked == null) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaestroDmScreen(
          memberId: me.id,
          adminId: picked.id,
          title: picked.name,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.cream,
        icon: const Icon(Icons.edit),
        label: const Text('New Message'),
        onPressed: _openNew,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<DmThread>>(
          future: _threads,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final threads = snap.data ?? const <DmThread>[];
            if (threads.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.forum_outlined,
                    title: _isAdmin
                        ? 'No messages yet'
                        : 'Start a conversation',
                    message: _isAdmin
                        ? 'Messages from members and other admins appear here.\nTap “New Message” to contact another admin.'
                        : 'Tap “New Message” to message any admin or the Maestro.',
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: threads
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ThreadCard(
                        thread: t,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MaestroDmScreen(
                                memberId: t.memberId,
                                adminId: t.adminId,
                                title: t.iAmOnMemberSide
                                    ? t.adminName
                                    : t.memberName,
                              ),
                            ),
                          );
                          _reload();
                        },
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final DmThread thread;
  final VoidCallback onTap;
  const _ThreadCard({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = thread.iAmOnMemberSide ? thread.adminName : thread.memberName;
    return ElegantCard(
      onTap: onTap,
      child: Row(
        children: [
          Avatar(name: title, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  thread.lastBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }
}

/// Lets a member pick which admin (or the Maestro) to message.
class _AdminPickerScreen extends StatefulWidget {
  const _AdminPickerScreen();

  @override
  State<_AdminPickerScreen> createState() => _AdminPickerScreenState();
}

class _AdminPickerScreenState extends State<_AdminPickerScreen> {
  late Future<List<AdminContact>> _admins;

  @override
  void initState() {
    super.initState();
    _admins = DmService.listAdmins();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message an admin')),
      body: FutureBuilder<List<AdminContact>>(
        future: _admins,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <AdminContact>[];
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.group_outlined,
              title: 'No admins available',
              message: 'There are no active admins to message yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = list[i];
              final isMaestro = a.role == 'superAdmin';
              return ElegantCard(
                onTap: () => Navigator.pop(context, a),
                child: Row(
                  children: [
                    Avatar(name: a.name, size: 44, photoUrl: a.photoUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isMaestro ? 'Maestro' : 'Admin · ${a.branch}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isMaestro
                                      ? AppColors.accentDark
                                      : AppColors.gray,
                                  fontWeight: isMaestro
                                      ? FontWeight.w600
                                      : null,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.gray),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
