import 'package:flutter/material.dart';
import '../data/choir_data.dart';
import '../data/mock_data.dart';
import '../services/audience_data.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';
import '../widgets/youtube_popup.dart';
import 'public_song_player_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  late Future<List<RepertoireSong>> _songs;
  late Future<List<NotablePiece>> _pieces;

  @override
  void initState() {
    super.initState();
    _songs = AudienceData.fetchSongs();
    _pieces = AudienceData.fetchNotablePieces();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const SectionHeader(
          eyebrow: 'Our Repertoire',
          title: 'Our Music',
          subtitle:
              'A diverse repertoire of Arabic classics — presented a cappella, without instrumental accompaniment.',
        ),
        const SizedBox(height: 20),
        Text(
          ChoirData.musicIntro,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
        ),
        const SizedBox(height: 40),

        const SectionHeader(
          eyebrow: 'Sample',
          title: 'Listen & Read',
          subtitle:
              'A taste of our repertoire — audio sample with full lyrics.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<RepertoireSong>>(
          future: _songs,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final songs = (snap.data ?? const <RepertoireSong>[])
                .take(4)
                .toList();
            return Column(
              children: songs
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElegantCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicSongPlayerScreen(song: s),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    s.subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.gray,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 40),

        const SectionHeader(eyebrow: 'Featured Works', title: 'Notable Pieces'),
        const SizedBox(height: 16),
        FutureBuilder<List<NotablePiece>>(
          future: _pieces,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final pieces = snap.data ?? const <NotablePiece>[];
            return Column(
              children: List.generate(
                pieces.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PieceCard(index: i + 1, piece: pieces[i]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PieceCard extends StatelessWidget {
  final int index;
  final NotablePiece piece;
  const _PieceCard({required this.index, required this.piece});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index.toString().padLeft(2, '0'),
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppColors.accent.withValues(alpha: 0.5),
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(piece.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            piece.subtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.gray,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, width: 32, color: AppColors.accent),
          const SizedBox(height: 10),
          Text(
            piece.composers,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            piece.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                showYoutubePopup(context, piece.youtubeUrl, title: piece.title),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Watch Performance'),
          ),
        ],
      ),
    );
  }
}
