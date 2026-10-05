import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'participant_tile.dart' show displayName;

/// A participant's active screen share track, if any.
class ScreenShare {
  final Participant participant;
  final VideoTrack track;
  const ScreenShare(this.participant, this.track);

  static ScreenShare? find(List<Participant> participants) {
    for (final p in participants) {
      final track = p.videoTrackPublications
          .where((pub) => pub.isScreenShare && !pub.muted)
          .firstOrNull
          ?.track as VideoTrack?;
      if (track != null) return ScreenShare(p, track);
    }
    return null;
  }
}

class ScreenShareStage extends StatelessWidget {
  final ScreenShare share;
  final bool isLocal;
  final VoidCallback onStopLocal;

  const ScreenShareStage({super.key, required this.share, required this.isLocal, required this.onStopLocal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Rendering your own share produces a hall-of-mirrors effect, so show a notice instead.
          if (isLocal)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_share, size: 48, color: Colors.white70),
                  const SizedBox(height: 12),
                  const Text('Bạn đang chia sẻ màn hình',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: scheme.error),
                    onPressed: onStopLocal,
                    icon: const Icon(Icons.stop_screen_share),
                    label: const Text('Dừng chia sẻ'),
                  ),
                ],
              ),
            )
          else
            VideoTrackRenderer(share.track, fit: VideoViewFit.contain, mirrorMode: VideoViewMirrorMode.off),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text('${isLocal ? 'Bạn' : displayName(share.participant)} đang chia sẻ màn hình',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
