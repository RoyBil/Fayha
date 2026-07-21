import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Opens a YouTube video.
/// • On mobile (iOS/Android): YouTube blocks WebView playback, so we show a
///   thumbnail card with a button that opens the YouTube app or browser.
/// • On web: the in-app iframe player is embedded directly.
Future<void> showYoutubePopup(
  BuildContext context,
  String url, {
  String? title,
}) {
  final videoId = YoutubePlayerController.convertUrlToId(url);
  if (videoId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sorry — that YouTube link is not valid.')),
    );
    return Future.value();
  }

  // Mobile: YouTube's iframe API blocks embedded WebView playback.
  // Show a thumbnail preview and open externally instead.
  if (!kIsWeb) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _YoutubeMobileCard(videoId: videoId, title: title),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _YoutubePopup(videoId: videoId, title: title),
  );
}

/// Opens the YouTube app if installed, otherwise falls back to the browser.
Future<void> _openExternal(String videoId) async {
  final appUri = Uri.parse('youtube://watch?v=$videoId');
  final webUri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
  try {
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }
  } catch (_) {}
  await launchUrl(webUri, mode: LaunchMode.externalApplication);
}

// ── Mobile card (thumbnail + external launch) ─────────────────────────────────

class _YoutubeMobileCard extends StatelessWidget {
  final String videoId;
  final String? title;
  const _YoutubeMobileCard({required this.videoId, this.title});

  @override
  Widget build(BuildContext context) {
    // YouTube provides free thumbnail images at predictable URLs.
    final thumbUrl =
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? 'YouTube',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Thumbnail
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      thumbUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1a1a1a),
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                    // Play overlay
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Open button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _openExternal(videoId);
                },
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text(
                  'Watch on YouTube',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Web in-app player ─────────────────────────────────────────────────────────

class _YoutubePopup extends StatefulWidget {
  final String videoId;
  final String? title;
  const _YoutubePopup({required this.videoId, this.title});

  @override
  State<_YoutubePopup> createState() => _YoutubePopupState();
}

class _YoutubePopupState extends State<_YoutubePopup> {
  late final YoutubePlayerController _ctrl;
  bool _playerReady = false;

  @override
  void initState() {
    super.initState();
    _ctrl = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        enableCaption: true,
        strictRelatedVideos: true,
      ),
    )..loadVideoById(videoId: widget.videoId);

    _ctrl.listen((state) {
      if (!_playerReady &&
          state.playerState != PlayerState.unknown &&
          state.playerState != PlayerState.unStarted) {
        if (mounted) setState(() => _playerReady = true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const inset = 12.0;
    final mq = MediaQuery.of(context);
    final maxW = mq.size.width - inset * 2;
    final maxH = mq.size.height - inset * 4 - 80;
    final byW = (maxW * 9 / 16);
    final playerW = byW <= maxH ? maxW : maxH * 16 / 9;
    final playerH = playerW * 9 / 16;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: inset,
        vertical: inset * 2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: playerW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? 'YouTube',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white70),
                    tooltip: 'Watch in YouTube',
                    onPressed: () => _openExternal(widget.videoId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: playerW,
                height: playerH,
                child: YoutubePlayer(controller: _ctrl),
              ),
            ),
            if (!_playerReady)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: TextButton.icon(
                  onPressed: () => _openExternal(widget.videoId),
                  icon: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    'Watch in YouTube app',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
