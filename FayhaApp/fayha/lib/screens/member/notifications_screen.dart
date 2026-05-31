import 'package:flutter/material.dart';
import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<FeedItem>> _feed;
  String _filter = 'All';

  static const _filters = [
    'All', 'Messages', 'Announcements', 'News', 'Concerts', 'Polls'
  ];

  @override
  void initState() {
    super.initState();
    _feed = NotificationsService.feed();
  }

  void _reload() => setState(() => _feed = NotificationsService.feed());

  bool _matches(FeedItem i) {
    switch (_filter) {
      case 'Messages':
        return i.kind == 'message';
      case 'Announcements':
        return i.kind == 'announcement';
      case 'News':
        return i.kind == 'news';
      case 'Concerts':
        return i.kind == 'concert';
      case 'Polls':
        return i.kind == 'poll';
      default:
        return true;
    }
  }

  ({IconData icon, Color color, String label}) _meta(String kind) {
    switch (kind) {
      case 'message':
        return (icon: Icons.chat_bubble_outline, color: AppColors.primaryLight, label: 'Message');
      case 'news':
        return (icon: Icons.newspaper, color: AppColors.secondary, label: 'News');
      case 'concert':
        return (icon: Icons.music_note, color: AppColors.accentDark, label: 'Concert');
      case 'poll':
        return (icon: Icons.poll_outlined, color: AppColors.primary, label: 'Poll');
      default:
        return (icon: Icons.campaign, color: AppColors.primary, label: 'Announcement');
    }
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.isNegative) {
      final d = t.difference(DateTime.now());
      if (d.inDays > 0) return 'in ${d.inDays}d';
      return 'soon';
    }
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: BrandedBackground(
        child: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _filters
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<FeedItem>>(
                future: _feed,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data ?? const <FeedItem>[];
                  final items = all.where(_matches).toList();
                  if (items.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.notifications_none,
                          title: 'Nothing here yet',
                          message: 'Announcements, news and concerts will show up here.',
                        ),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: items.map((i) {
                      final m = _meta(i.kind);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElegantCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: m.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(m.icon, size: 18, color: m.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(i.title,
                                              style: theme.textTheme.titleSmall),
                                        ),
                                        Text(_ago(i.date),
                                            style: theme.textTheme.labelSmall),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(i.body,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
