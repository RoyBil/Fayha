import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/newsletter_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';

class NewsletterSubscribersScreen extends StatefulWidget {
  const NewsletterSubscribersScreen({super.key});

  @override
  State<NewsletterSubscribersScreen> createState() =>
      _NewsletterSubscribersScreenState();
}

class _NewsletterSubscribersScreenState
    extends State<NewsletterSubscribersScreen> {
  late Future<List<NewsletterSubscriber>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = NewsletterService.list();
  }

  void _reload() {
    setState(() => _future = NewsletterService.list());
  }

  Future<void> _copyAll(List<NewsletterSubscriber> list) async {
    final joined = list.map((s) => s.email).join(', ');
    await Clipboard.setData(ClipboardData(text: joined));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${list.length} email(s) copied')),
    );
  }

  Future<void> _confirmDelete(NewsletterSubscriber s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove subscriber?'),
        content: Text('${s.email} will be removed from the newsletter list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await NewsletterService.remove(s.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Newsletter Subscribers'),
        actions: [
          FutureBuilder<List<NewsletterSubscriber>>(
            future: _future,
            builder: (context, snap) {
              final list = snap.data ?? const <NewsletterSubscriber>[];
              if (list.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Copy all emails',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () => _copyAll(list),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<NewsletterSubscriber>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 60),
                  Text('Could not load: ${snap.error}',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                ],
              );
            }
            final all = snap.data ?? const <NewsletterSubscriber>[];
            final list = _query.isEmpty
                ? all
                : all
                    .where((s) => s.email
                        .toLowerCase()
                        .contains(_query.toLowerCase()))
                    .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                SectionHeader(
                  eyebrow: 'Audience',
                  title: '${all.length} subscriber${all.length == 1 ? '' : 's'}',
                  subtitle:
                      'Emails submitted from the public homepage. Tap copy in the app bar to grab them all.',
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search email',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        all.isEmpty
                            ? 'No newsletter subscribers yet.'
                            : 'No emails match "$_query".',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...list.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ElegantCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.mail_outline,
                                  color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s.email,
                                        style: theme.textTheme.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        'Subscribed ${_fmtDate(s.subscribedAt)}',
                                        style: theme.textTheme.labelSmall),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy email',
                                icon: const Icon(Icons.copy,
                                    size: 18, color: AppColors.gray),
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  await Clipboard.setData(
                                      ClipboardData(text: s.email));
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                        content: Text('${s.email} copied')),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.gray),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _confirmDelete(s),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
