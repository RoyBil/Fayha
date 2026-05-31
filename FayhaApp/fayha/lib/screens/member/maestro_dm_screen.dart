import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../services/admin_service.dart';
import '../../services/dm_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/fayha_map.dart' show MapInfoSheet, MapFact;

class MaestroDmScreen extends StatefulWidget {
  final String memberId;
  final String title;
  const MaestroDmScreen({
    super.key,
    required this.memberId,
    required this.title,
  });

  @override
  State<MaestroDmScreen> createState() => _MaestroDmScreenState();
}

class _MaestroDmScreenState extends State<MaestroDmScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  List<DmMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  // Voice state
  bool _recording = false;
  bool _uploadingVoice = false;
  DateTime? _recordStart;
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;

  bool get _iAmMaestro =>
      AppState.instance.currentMember?.role == 'superAdmin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await DmService.thread(widget.memberId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _jumpToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load: $e')));
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await DmService.send(
        memberId: widget.memberId,
        body: text,
        fromMaestro: _iAmMaestro,
      );
      _controller.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }
      // Web records to memory; mobile/desktop to file path.
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // Opus on web (universal browser support), AAC on native.
      final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
      await _recorder.start(
        RecordConfig(encoder: encoder, bitRate: 96000),
        path: path,
      );
      _recordStart = DateTime.now();
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _recordStart == null) return;
        setState(() => _recordDuration =
            DateTime.now().difference(_recordStart!));
        // Hard cap at 2 minutes.
        if (_recordDuration.inSeconds >= 120) _stopAndSend();
      });
      setState(() => _recording = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    _recordTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordStart = null;
      _recordDuration = Duration.zero;
    });
  }

  Future<void> _stopAndSend() async {
    _recordTimer?.cancel();
    final start = _recordStart;
    setState(() => _recording = false);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    final duration = start == null
        ? Duration.zero
        : DateTime.now().difference(start);
    _recordStart = null;
    if (path == null || duration.inMilliseconds < 500) {
      if (!mounted) return;
      setState(() => _recordDuration = Duration.zero);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too short — hold longer next time')),
      );
      return;
    }
    setState(() => _uploadingVoice = true);
    try {
      Uint8List bytes;
      String ext = 'm4a';
      if (kIsWeb) {
        // On web, record.stop() returns a blob: URL. Fetch its bytes.
        final res = await http.get(Uri.parse(path));
        bytes = res.bodyBytes;
        // Web records as WebM/Opus by default.
        ext = 'webm';
      } else {
        bytes = await File(path).readAsBytes();
      }
      final url = await DmService.uploadVoice(bytes: bytes, fileExtension: ext);
      await DmService.send(
        memberId: widget.memberId,
        fromMaestro: _iAmMaestro,
        audioUrl: url,
        audioDurationMs: duration.inMilliseconds,
      );
      if (!kIsWeb) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send voice message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingVoice = false;
          _recordDuration = Duration.zero;
        });
      }
    }
  }

  String _time(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${day.day} ${_months[day.month - 1]} ${day.year}';
  }

  List<Widget> _chatChildren() {
    final out = <Widget>[];
    DateTime? lastDay;
    for (final msg in _messages) {
      final day = DateTime(
          msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDay == null || day != lastDay) {
        out.add(_DateDivider(label: _dayLabel(day)));
        lastDay = day;
      }
      final mine = _iAmMaestro ? msg.fromMaestro : !msg.fromMaestro;
      out.add(_Bubble(
        message: msg,
        mine: mine,
        time: _time(msg.createdAt),
      ));
    }
    return out;
  }

  Future<void> _showPersonInfo() async {
    if (_iAmMaestro) {
      final m = await AdminService.fetchMember(widget.memberId);
      if (!mounted || m == null) return;
      final years = DateTime.now().year - m.joinDate.year;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => MapInfoSheet(
          color: AppColors.primary,
          icon: Icons.person,
          title: m.name,
          subtitle: m.role == 'admin'
              ? 'Admin'
              : (m.role == 'superAdmin' ? 'Maestro' : 'Member'),
          facts: [
            MapFact(Icons.location_city_outlined, 'Branch', m.branch),
            MapFact(Icons.music_note, 'Voice section', m.voiceSection),
            MapFact(Icons.event_outlined, 'Joined', '${m.joinDate.year}'),
            MapFact(Icons.timer_outlined, 'Years with choir',
                '$years ${years == 1 ? 'year' : 'years'}'),
            MapFact(Icons.theater_comedy, 'Concerts', '${m.concertsCount}'),
            MapFact(Icons.phone_outlined, 'Phone',
                m.phone.isEmpty ? '—' : m.phone),
          ],
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const MapInfoSheet(
          color: AppColors.primary,
          icon: Icons.person,
          title: 'Barkev Taslakian',
          subtitle: 'Founder & Principal Conductor',
          facts: [
            MapFact(Icons.event_outlined, 'Founded the choir', '2003'),
            MapFact(Icons.location_city_outlined, 'Branch', 'All Branches'),
            MapFact(Icons.music_note, 'Role', 'Conductor'),
          ],
          description:
              'Maestro Barkev Taslakian founded Fayha National Choir in 2003 and remains its principal conductor and artistic director.',
        ),
      );
    }
  }

  String _fmtRec(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _composer() {
    if (_recording) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.gray),
            tooltip: 'Cancel',
            onPressed: _cancelRecording,
          ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Recording  ${_fmtRec(_recordDuration)}',
                    style: const TextStyle(
                        color: AppColors.dark, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _stopAndSend,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.stop, size: 18, color: AppColors.cream),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          icon: Icon(_uploadingVoice ? Icons.cloud_upload_outlined : Icons.mic_none,
              color: AppColors.primary),
          tooltip: 'Record voice',
          onPressed: _uploadingVoice ? null : _toggleRecord,
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              hintText: 'Write a message…',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _sending ? null : _send,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _sending
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.cream))
                  : const Icon(Icons.send, size: 18, color: AppColors.cream),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _showPersonInfo,
          child: Row(
            children: [
              Avatar(name: widget.title, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(fontSize: 16)),
                    const Text('Tap for info',
                        style: TextStyle(fontSize: 11, color: AppColors.gray)),
                  ],
                ),
              ),
              const Icon(Icons.info_outline, size: 18, color: AppColors.gray),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
      body: BrandedBackground(
        child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _iAmMaestro
                                ? 'No messages yet from this member.'
                                : 'Start the conversation with the Maestro.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                        children: _chatChildren(),
                      ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.offWhite)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: SafeArea(top: false, child: _composer()),
          ),
        ],
      ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.offWhite,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.gray,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final DmMessage message;
  final bool mine;
  final String time;
  const _Bubble({required this.message, required this.mine, required this.time});

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppColors.primary : Colors.white;
    final fg = mine ? AppColors.cream : AppColors.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mine ? 14 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 14),
                ),
                border: mine ? null : Border.all(color: AppColors.offWhite),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.hasAudio)
                    _VoicePlayer(
                      url: message.audioUrl!,
                      durationMs: message.audioDurationMs ?? 0,
                      mine: mine,
                    ),
                  if ((message.body ?? '').isNotEmpty) ...[
                    if (message.hasAudio) const SizedBox(height: 6),
                    Text(message.body!,
                        style: TextStyle(color: fg, fontSize: 14, height: 1.4)),
                  ],
                  const SizedBox(height: 4),
                  Text(time,
                      style: TextStyle(
                          color: fg.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoicePlayer extends StatefulWidget {
  final String url;
  final int durationMs;
  final bool mine;
  const _VoicePlayer({
    required this.url,
    required this.durationMs,
    required this.mine,
  });

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  late final Duration _total;

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.durationMs);
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _pos = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? AppColors.cream : AppColors.primary;
    final track = fg.withValues(alpha: 0.3);
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                size: 20,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: track,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _playing ? _fmt(_pos) : _fmt(_total),
                  style: TextStyle(color: fg, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
