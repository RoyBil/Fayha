import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Opens a YouTube video inside the app (no browser hand-off).
/// Returns nothing — the dialog manages its own controller lifecycle.
Future<void> showYoutubePopup(BuildContext context, String url,
    {String? title}) {
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

class _YoutubePopup extends StatefulWidget {
  final String videoId;
  final String? title;
  const _YoutubePopup({required this.videoId, this.title});

  @override
  State<_YoutubePopup> createState() => _YoutubePopupState();
}

class _YoutubePopupState extends State<_YoutubePopup> {
  late final YoutubePlayerController _ctrl;

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
          horizontal: inset, vertical: inset * 2),
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
                          fontSize: 14),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: playerW,
                height: playerH,
                child: YoutubePlayer(controller: _ctrl),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
