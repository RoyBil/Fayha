import 'dart:async';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';

class PublicSongPlayerScreen extends StatefulWidget {
  final RepertoireSong song;
  const PublicSongPlayerScreen({super.key, required this.song});

  @override
  State<PublicSongPlayerScreen> createState() => _PublicSongPlayerScreenState();
}

class _PublicSongPlayerScreenState extends State<PublicSongPlayerScreen> {
  bool _playing = false;
  Duration _position = Duration.zero;
  final Duration _total = const Duration(minutes: 3, seconds: 48);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        setState(() {
          _position += const Duration(milliseconds: 500);
          if (_position >= _total) {
            _position = Duration.zero;
            _playing = false;
            _timer?.cancel();
          }
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _position.inMilliseconds / _total.inMilliseconds;
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.cream.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.music_note,
                      size: 80, color: AppColors.accentLight),
                ),
                const SizedBox(height: 24),
                Text(widget.song.title,
                    style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.cream)),
                const SizedBox(height: 4),
                Text(widget.song.subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.accentLight,
                      fontStyle: FontStyle.italic,
                    )),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(_fmt(_position), style: theme.textTheme.labelMedium),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: progress.clamp(0, 1),
                          onChanged: (v) => setState(() {
                            _position = Duration(
                                milliseconds: (_total.inMilliseconds * v).round());
                          }),
                          activeColor: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(_fmt(_total), style: theme.textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _position = Duration.zero),
                      icon: const Icon(Icons.replay_10),
                      iconSize: 26,
                    ),
                    const SizedBox(width: 16),
                    Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _togglePlay,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            _playing ? Icons.pause : Icons.play_arrow,
                            color: AppColors.cream,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => setState(() => _position = _total),
                      icon: const Icon(Icons.forward_10),
                      iconSize: 26,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ElegantCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lyrics',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.accentDark,
                            letterSpacing: 1.4,
                          )),
                      const SizedBox(height: 6),
                      Container(height: 2, width: 32, color: AppColors.accent),
                      const SizedBox(height: 14),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: SelectableText(
                          widget.song.lyrics,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 18,
                            height: 1.9,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(widget.song.composers,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primaryDark,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
