import 'package:audioplayers/audioplayers.dart';
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
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _loaded = false;

  bool get _hasAudio => widget.song.audioUrl != null;

  @override
  void initState() {
    super.initState();
    if (_hasAudio) {
      _player.onPlayerStateChanged.listen((s) {
        if (!mounted) return;
        setState(() => _playing = s == PlayerState.playing);
      });
      _player.onPositionChanged.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
      _player.onDurationChanged.listen((d) {
        if (!mounted) return;
        setState(() {
          _total = d;
          _loaded = true;
        });
      });
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      });
      _player.setSourceUrl(widget.song.audioUrl!);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.song.audioUrl!));
    }
  }

  Future<void> _seek(double value) async {
    final ms = (_total.inMilliseconds * value).round();
    await _player.seek(Duration(milliseconds: ms));
  }

  Future<void> _rewind() async {
    final next = _position - const Duration(seconds: 10);
    await _player.seek(next < Duration.zero ? Duration.zero : next);
  }

  Future<void> _forward() async {
    final next = _position + const Duration(seconds: 10);
    await _player.seek(next > _total ? _total : next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

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
                  child: const Icon(
                    Icons.music_note,
                    size: 80,
                    color: AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.song.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.song.subtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.accentLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: _hasAudio
                ? Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            _fmt(_position),
                            style: theme.textTheme.labelMedium,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: progress,
                                onChanged: _loaded ? _seek : null,
                                activeColor: AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            _fmt(_total),
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _loaded ? _rewind : null,
                            icon: const Icon(Icons.replay_10),
                            iconSize: 26,
                          ),
                          const SizedBox(width: 16),
                          Material(
                            color: AppColors.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _loaded ? _togglePlay : null,
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
                            onPressed: _loaded ? _forward : null,
                            icon: const Icon(Icons.forward_10),
                            iconSize: 26,
                          ),
                        ],
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.volume_off_outlined,
                          color: AppColors.gray,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No audio available for this song.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.gray,
                          ),
                        ),
                      ],
                    ),
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
                      Text(
                        'Lyrics',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accentDark,
                          letterSpacing: 1.4,
                        ),
                      ),
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
                      Text(
                        widget.song.composers,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
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
