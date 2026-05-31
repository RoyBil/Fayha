import 'package:flutter/material.dart';
import '../../services/dm_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import 'maestro_dm_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool get _isMaestro =>
      AppState.instance.currentMember?.role == 'superAdmin';

  late Future<List<DmThread>> _inbox;

  @override
  void initState() {
    super.initState();
    if (_isMaestro) _inbox = DmService.inbox();
  }

  @override
  Widget build(BuildContext context) {
    final me = AppState.instance.currentMember!;

    // A member / admin: their own private chat with the Maestro.
    if (!_isMaestro) {
      return MaestroDmScreen(
        memberId: me.id,
        title: 'Maestro Barkev',
      );
    }

    // The Maestro: an inbox of every member's thread.
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _inbox = DmService.inbox()),
        child: FutureBuilder<List<DmThread>>(
          future: _inbox,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final threads = snap.data ?? const <DmThread>[];
            if (threads.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No messages yet',
                    message: 'Members\' private messages to you appear here.',
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: threads
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElegantCard(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaestroDmScreen(
                                  memberId: t.memberId,
                                  title: t.memberName,
                                ),
                              ),
                            );
                            setState(() => _inbox = DmService.inbox());
                          },
                          child: Row(
                            children: [
                              Avatar(name: t.memberName, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.memberName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 2),
                                    Text(t.lastBody,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.gray),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}
