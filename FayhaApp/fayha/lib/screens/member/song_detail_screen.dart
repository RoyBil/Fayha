import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../services/choir_songs_service.dart';
import '../../services/member_songs_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/youtube_popup.dart';
import 'compose_song_screen.dart';

class SongDetailScreen extends StatefulWidget {
  final ChoirSong song;
  const SongDetailScreen({super.key, required this.song});

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  /// One player per voice section (S1, S2, A1, A2, T1, T2, B1, B2).
  late final List<AudioPlayer> _players;
  late final List<double> _volumes; // current volume 0..1
  late final List<bool> _muted; // per-section mute

  bool _ready = false; // sources loaded
  bool _loading = true;
  String? _loadError;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Allow all tracks to play simultaneously on Android by not requesting
    // exclusive audio focus — without this only one player wins focus and the
    // rest are silenced.
    AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioMode: AndroidAudioMode.normal,
          isSpeakerphoneOn: false,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    _players = List.generate(choirVoiceParts.length, (_) => AudioPlayer());
    _volumes = List<double>.filled(choirVoiceParts.length, 0.8);
    _muted = List<bool>.filled(choirVoiceParts.length, false);
    // Boost your own section by default.
    final mine = _myIndex();
    if (mine >= 0) _volumes[mine] = 1.0;
    _initPlayers();
  }

  Future<void> _initPlayers() async {
    try {
      int? masterIdx;
      for (var i = 0; i < _players.length; i++) {
        final p = _players[i];
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(_muted[i] ? 0.0 : _volumes[i]);
        final url = widget.song.urlForPart(i);
        if (url != null && url.isNotEmpty) {
          await p.setSource(UrlSource(url));
          masterIdx ??= i;
        }
      }
      if (masterIdx == null) {
        if (!mounted) return;
        setState(() {
          _loadError = 'No audio uploaded for this song yet.';
          _loading = false;
        });
        return;
      }
      // Use the first available part as the position/duration master.
      final master = _players[masterIdx];
      _posSub = master.onPositionChanged.listen((p) {
        if (!mounted) return;
        setState(() => _pos = p);
      });
      _durSub = master.onDurationChanged.listen((d) {
        if (!mounted) return;
        setState(() => _total = d);
      });
      _completeSub = master.onPlayerComplete.listen((_) async {
        // Stop the rest too, reset position to 0.
        for (final p in _players) {
          await p.stop();
          await p.seek(Duration.zero);
        }
        if (!mounted) return;
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      });
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    for (final p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!_ready) return;
    if (_playing) {
      for (final p in _players) {
        await p.pause();
      }
      setState(() => _playing = false);
    } else {
      // Fire resume on all in parallel for closest sync.
      await Future.wait(_players.map((p) => p.resume()));
      setState(() => _playing = true);
    }
  }

  Future<void> _stop() async {
    for (final p in _players) {
      await p.stop();
      await p.seek(Duration.zero);
    }
    if (!mounted) return;
    setState(() {
      _playing = false;
      _pos = Duration.zero;
    });
  }

  Future<void> _seekAll(double value) async {
    if (_total.inMilliseconds == 0) return;
    final target = Duration(
      milliseconds: (value * _total.inMilliseconds).round(),
    );
    await Future.wait(_players.map((p) => p.seek(target)));
    if (mounted) setState(() => _pos = target);
  }

  Future<void> _setVolume(int i, double v) async {
    setState(() => _volumes[i] = v);
    if (!_muted[i]) await _players[i].setVolume(v);
  }

  Future<void> _toggleMute(int i) async {
    setState(() => _muted[i] = !_muted[i]);
    await _players[i].setVolume(_muted[i] ? 0.0 : _volumes[i]);
  }

  Future<void> _soloMine() async {
    final mine = _myIndex();
    if (mine < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set your voice section in your profile first'),
        ),
      );
      return;
    }
    for (var i = 0; i < _players.length; i++) {
      final shouldMute = i != mine;
      _muted[i] = shouldMute;
      await _players[i].setVolume(shouldMute ? 0.0 : _volumes[i]);
    }
    if (mounted) setState(() {});
  }

  Future<void> _unmuteAll() async {
    for (var i = 0; i < _players.length; i++) {
      _muted[i] = false;
      await _players[i].setVolume(_volumes[i]);
    }
    if (mounted) setState(() {});
  }

  /// Short 2–3 char chip label for the mixer row, derived from the
  /// SQL key (e.g. `mezzo_soprano` -> `MS`, `tenor_i` -> `TI`).
  String _shortLabel(String key) {
    final parts = key.split('_');
    if (parts.length == 1) {
      // Single word — first 2 letters in upper case.
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    // Multi-word — first letter of each part.
    return parts.map((p) => p[0]).join().toUpperCase();
  }

  int _myIndex() {
    final voice = (AppState.instance.currentMember?.voiceSection ?? '')
        .toLowerCase()
        .trim();
    // Match the new vocabulary by lower-casing both sides.
    for (var i = 0; i < choirVoiceParts.length; i++) {
      if (choirVoiceParts[i].toLowerCase() == voice) return i;
    }
    // Loose fallbacks for older saved values.
    switch (voice) {
      case 'mezzo-soprano':
        return choirVoiceParts.indexOf('Mezzo Soprano');
      case 'contralto':
        return choirVoiceParts.indexOf('Contrary Alto');
      case 'soprano 1':
      case 'soprano1':
        return choirVoiceParts.indexOf('Soprano');
      case 'soprano 2':
      case 'soprano2':
        return choirVoiceParts.indexOf('Mezzo Soprano');
      case 'alto 1':
      case 'alto1':
        return choirVoiceParts.indexOf('Alto');
      case 'alto 2':
      case 'alto2':
        return choirVoiceParts.indexOf('Contrary Alto');
      case 'tenor 1':
      case 'tenor1':
        return choirVoiceParts.indexOf('Tenor I');
      case 'tenor 2':
      case 'tenor2':
        return choirVoiceParts.indexOf('Tenor II');
      case 'bass 1':
      case 'bass1':
        return choirVoiceParts.indexOf('Baritone');
      case 'bass 2':
      case 'bass2':
        return choirVoiceParts.indexOf('Bass');
    }
    return -1;
  }

  Future<void> _openYoutube() async {
    final url = widget.song.youtubeUrl;
    if (url == null || url.isEmpty) return;
    // Pause any audio that's currently playing so two players don't
    // overlap.
    for (final p in _players) {
      await p.pause();
    }
    if (!mounted) return;
    await showYoutubePopup(context, url, title: widget.song.title);
  }

  Future<void> _openEdit() async {
    // Pause any playing audio before navigating away.
    for (final p in _players) {
      await p.pause();
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeSongScreen(existing: widget.song),
      ),
    );
    if (saved == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete song?'),
        content: Text(
          '"${widget.song.title}" and all 8 audio parts will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      for (final p in _players) {
        await p.stop();
      }
      await ChoirSongsService.delete(widget.song.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Future<void> _toggleMemorized(bool currentlyMemorized) async {
    final me = AppState.instance.currentMember;
    if (me == null) return;
    AppState.instance.toggleMemorized(widget.song.id);
    setState(() {}); // refresh this screen's icon immediately
    try {
      if (currentlyMemorized) {
        await MemberSongsService.remove(
          memberId: me.id,
          songId: widget.song.id,
        );
      } else {
        await MemberSongsService.add(memberId: me.id, songId: widget.song.id);
      }
    } catch (e) {
      AppState.instance.toggleMemorized(widget.song.id);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = AppState.instance.currentMember;
    final memorized = m?.memorizedSongIds.contains(widget.song.id) ?? false;
    final mine = _myIndex();
    final canManage = (m?.role == 'admin' || m?.role == 'superAdmin');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title, style: const TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            tooltip: memorized ? 'Memorized' : 'Mark as memorized',
            icon: Icon(
              memorized ? Icons.check_circle : Icons.check_circle_outline,
              color: memorized ? AppColors.secondary : AppColors.gray,
            ),
            onPressed: () => _toggleMemorized(memorized),
          ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Manage song',
              onSelected: (v) {
                if (v == 'edit') _openEdit();
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit song'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18),
                      SizedBox(width: 10),
                      Text('Delete song'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Mixer'),
            Tab(text: 'Lyrics'),
            Tab(text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildMixerTab(theme, mine),
          _buildLyricsTab(theme),
          _buildAboutTab(theme),
        ],
      ),
    );
  }

  Widget _buildMixerTab(ThemeData theme, int mine) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Could not load audio: $_loadError',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final allMuted = _muted.every((e) => e);
    final onlyMineUnmuted =
        mine >= 0 &&
        !_muted[mine] &&
        _muted
            .asMap()
            .entries
            .where((e) => e.key != mine)
            .every((e) => e.value);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        ElegantCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined, size: 32),
                    color: AppColors.gray,
                    onPressed: _stop,
                    tooltip: 'Stop',
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _togglePlay,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          color: AppColors.cream,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _total.inMilliseconds == 0
                    ? 0
                    : (_pos.inMilliseconds / _total.inMilliseconds).clamp(
                        0.0,
                        1.0,
                      ),
                onChanged: _seekAll,
                activeColor: AppColors.primary,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(_pos), style: theme.textTheme.labelSmall),
                  Text(_fmt(_total), style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onlyMineUnmuted ? _unmuteAll : _soloMine,
                icon: Icon(
                  onlyMineUnmuted ? Icons.public : Icons.headphones,
                  size: 16,
                ),
                label: Text(
                  onlyMineUnmuted ? 'Listen to all' : 'Solo my voice',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: allMuted ? null : _unmuteAll,
                icon: const Icon(Icons.volume_up, size: 16),
                label: const Text('Unmute all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Voice sections', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'All parts play together. Mute or boost individual sections.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < choirVoiceParts.length; i++)
          if (widget.song.hasPart(i))
            _PartMixerRow(
              label: choirVoiceParts[i],
              shortLabel: _shortLabel(choirVoicePartKeys[i]),
              isMine: i == mine,
              muted: _muted[i],
              volume: _volumes[i],
              onToggleMute: () => _toggleMute(i),
              onVolume: (v) => _setVolume(i, v),
            ),
      ],
    );
  }

  Widget _buildLyricsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if ((widget.song.lyrics ?? '').isEmpty)
          Text(
            'No lyrics added for this song yet.',
            style: theme.textTheme.bodyMedium,
          )
        else
          ElegantCard(
            child: SelectableText(
              widget.song.lyrics!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }

  Widget _buildAboutTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if ((widget.song.subtitle ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.song.subtitle!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if ((widget.song.composers ?? '').isNotEmpty)
          _AboutRow(
            icon: Icons.edit_note,
            label: 'Composers / arrangement',
            value: widget.song.composers!,
          ),
        if ((widget.song.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          ElegantCard(
            child: Text(
              widget.song.description!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        ],
        if ((widget.song.youtubeUrl ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openYoutube,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Watch on YouTube'),
          ),
        ],
      ],
    );
  }
}

class _PartMixerRow extends StatelessWidget {
  final String label;
  final String shortLabel;
  final bool isMine;
  final bool muted;
  final double volume;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  const _PartMixerRow({
    required this.label,
    required this.shortLabel,
    required this.isMine,
    required this.muted,
    required this.volume,
    required this.onToggleMute,
    required this.onVolume,
  });

  @override
  Widget build(BuildContext context) {
    final fg = muted ? AppColors.gray : AppColors.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMine ? AppColors.accent : AppColors.offWhite,
            width: isMine ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: muted
                        ? AppColors.offWhite
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    shortLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: muted ? AppColors.gray : AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: fg,
                          fontSize: 14,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    muted ? Icons.volume_off : Icons.volume_up,
                    size: 20,
                    color: muted ? AppColors.gray : AppColors.primary,
                  ),
                  onPressed: onToggleMute,
                  tooltip: muted ? 'Unmute' : 'Mute',
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: volume,
                onChanged: muted ? null : onVolume,
                activeColor: muted ? AppColors.gray : AppColors.primary,
                inactiveColor: AppColors.offWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
