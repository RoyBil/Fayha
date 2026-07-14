import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Opens a YouTube video inside the app (no browser hand-off).
/// Returns nothing — the dialog manages its own controller lifecycle.
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
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _YoutubePopup(videoId: videoId, title: title),
  );
}

/// Opens the YouTube app if installed, otherwise falls back to the browser.
Future<void> _openExternal(String videoId) async {
  // iOS + Android: custom-scheme deep-link into the YouTube app.
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
    // Largest 16:9 rectangle that fits the screen with margins.
    final maxW = mq.size.width - inset * 2;
    final maxH = mq.size.height - inset * 4 - 80; // leave room for header
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
                  // Always-visible fallback: opens native YouTube app or browser.
                  // This is the primary path on physical phones where the
                  // in-app WebView player may be blocked by YouTube's policy.
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
            // Persistent fallback row — tapping takes the user to the YouTube
            // app/browser, which is 100% reliable on physical devices.
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
