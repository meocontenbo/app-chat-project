import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Camera video (or avatar when the camera is off) with name, mic state and a speaking highlight.
class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isLocal;

  const ParticipantTile(this.participant, {super.key, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = participant;
    final name = displayName(p);
    final muted = p is LocalParticipant ? !p.isMicrophoneEnabled() : p.isMuted;
    final speaking = p.isSpeaking && !muted;
    final camera = p.videoTrackPublications
        .where((pub) => pub.source == TrackSource.camera && !pub.muted)
        .firstOrNull
        ?.track as VideoTrack?;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: speaking ? Colors.green : Colors.transparent, width: 3),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null)
            VideoTrackRenderer(camera, fit: VideoViewFit.cover)
          else
            Center(
              child: LayoutBuilder(
                builder: (_, c) => CircleAvatar(
                  radius: (c.biggest.shortestSide * 0.22).clamp(18, 56),
                  backgroundColor: scheme.primaryContainer,
                  child: Text(name.characters.first.toUpperCase(),
                      style: TextStyle(
                          fontSize: (c.biggest.shortestSide * 0.18).clamp(14, 44),
                          color: scheme.onPrimaryContainer)),
                ),
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(muted ? Icons.mic_off : Icons.mic,
                        size: 14, color: muted ? Colors.redAccent : Colors.white),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(isLocal ? '$name (Bạn)' : name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String displayName(Participant p) => p.name.isNotEmpty ? p.name : p.identity;
