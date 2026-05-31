import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../services/audience_data.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class PrivateNewsScreen extends StatefulWidget {
  const PrivateNewsScreen({super.key});

  @override
  State<PrivateNewsScreen> createState() => _PrivateNewsScreenState();
}

class _PrivateNewsScreenState extends State<PrivateNewsScreen> {
  late Future<List<NewsItem>> _news;

  @override
  void initState() {
    super.initState();
    _news = AudienceData.fetchNews();
  }

  void _reload() => setState(() => _news = AudienceData.fetchNews());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<NewsItem>>(
        future: _news,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final news = snap.data ?? const <NewsItem>[];
          if (news.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.newspaper,
                  title: 'No news yet',
                  message: 'Official choir news will appear here.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const SectionHeader(
                eyebrow: 'Official',
                title: 'Choir News',
              ),
              const SizedBox(height: 16),
              ...news.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElegantCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.date.toUpperCase(),
                              style: theme.textTheme.labelSmall),
                          const SizedBox(height: 6),
                          Text(n.title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(n.body,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.55)),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
