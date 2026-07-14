import 'package:flutter/material.dart';
import '../../services/choir_songs_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import 'song_detail_screen.dart';

class SongLibraryScreen extends StatefulWidget {
  const SongLibraryScreen({super.key});

  @override
  State<SongLibraryScreen> createState() => _SongLibraryScreenState();
}

class _SongLibraryScreenState extends State<SongLibraryScreen> {
  String _query = '';
  bool _onlyMemorized = false;
  late Future<List<ChoirSong>> _future;

  @override
  void initState() {
    super.initState();
    _future = ChoirSongsService.fetchAll();
  }

  Future<void> _reload() async {
    final f = ChoirSongsService.fetchAll(forceRefresh: true);
    if (!mounted) return;
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final m = AppState.instance.currentMember!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<ChoirSong>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load songs',
                      message: '${snap.error}',
                    ),
                  ],
                );
              }
              final all = snap.data ?? const <ChoirSong>[];
              final filtered = all.where((s) {
                if (_query.isNotEmpty &&
                    !s.title.toLowerCase().contains(_query.toLowerCase()) &&
                    !(s.subtitle ?? '').toLowerCase().contains(
                      _query.toLowerCase(),
                    )) {
                  return false;
                }
                if (_onlyMemorized && !m.memorizedSongIds.contains(s.id)) {
                  return false;
                }
                return true;
              }).toList();

              Future<void> openSong(ChoirSong s) async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => SongDetailScreen(song: s)),
                );
                if (changed == true) await _reload();
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search songs by title or translation…',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Only memorized'),
                        selected: _onlyMemorized,
                        onSelected: (v) => setState(() => _onlyMemorized = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (all.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: EmptyState(
                        icon: Icons.music_note_outlined,
                        title: 'No songs yet',
                        message:
                            'Admins can add choir songs (with all 8 voice parts) from the admin panel.',
                      ),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No songs match your filters.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SongTile(
                          song: s,
                          memorized: m.memorizedSongIds.contains(s.id),
                          onTap: () => openSong(s),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SongTile extends StatelessWidget {
  final ChoirSong song;
  final bool memorized;
  final VoidCallback onTap;
  const _SongTile({
    required this.song,
    required this.memorized,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: memorized
                  ? AppColors.secondary.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              memorized ? Icons.check : Icons.music_note,
              color: memorized ? AppColors.secondary : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title, style: theme.textTheme.titleMedium),
                if ((song.subtitle ?? '').isNotEmpty)
                  Text(
                    song.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
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
