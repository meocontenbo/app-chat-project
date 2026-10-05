import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show DesktopCapturerSource;
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import '../room/room_controller.dart';
import '../room/widgets/chat_panel.dart';
import '../room/widgets/control_bar.dart';
import '../room/widgets/join_requests_panel.dart';
import '../room/widgets/participant_tile.dart';
import '../room/widgets/screen_share_stage.dart';
import '../services/room_api.dart';

/// Meeting room: video grid / screen share stage, chat panel and controls.
class RoomScreen extends StatelessWidget {
  final String code;
  const RoomScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => RoomController(ctx.read<RoomApi>(), code)..connect(),
      child: const _RoomView(),
    );
  }
}

class _RoomView extends StatefulWidget {
  const _RoomView();

  @override
  State<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<_RoomView> {
  static const _wideBreakpoint = 900.0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final RoomController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = context.read<RoomController>();
    _ctrl.addListener(_onControllerChanged);
    _setBrowserUrl('/join/${_ctrl.code}');
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _setBrowserUrl('/');
    super.dispose();
  }

  void _onControllerChanged() {
    final notice = _ctrl.takeNotice();
    if (notice != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
    }
  }

  /// Keeps the browser address bar in sync so the URL can be shared or refreshed.
  void _setBrowserUrl(String path) {
    SystemNavigator.routeInformationUpdated(uri: Uri.parse(path), replace: true);
  }

  void _copyLink() {
    final link = _ctrl.info?.joinUrl;
    if (link == null) return;
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã copy link: $link')));
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  void _toggleChat() {
    if (_isWide) {
      _ctrl.chatVisible = !_ctrl.chatVisible;
    } else {
      _scaffoldKey.currentState?.openEndDrawer();
    }
  }

  void _toggleScreenShare() {
    _ctrl.toggleScreenShare(() async {
      final source = await showDialog<DesktopCapturerSource>(
        context: context,
        builder: (_) => ScreenSelectDialog(),
      );
      return source?.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RoomController>();
    final wide = _isWide;
    final showSidePanel = wide && ctrl.chatVisible;

    Widget body;
    if (ctrl.error != null) {
      body = _Message(
        text: ctrl.error!,
        action: () => Navigator.of(context).pop(),
        actionLabel: 'Quay lại',
      );
    } else if (ctrl.waitingApproval) {
      body = _Message(
        text: 'Đang chờ chủ phòng cho bạn vào...\n'
            'Chủ phòng sẽ thấy yêu cầu của bạn khi đang ở trong phòng.',
        loading: true,
        action: () => Navigator.of(context).pop(),
        actionLabel: 'Huỷ',
      );
    } else if (!ctrl.connected) {
      body = _Message(text: ctrl.reconnecting ? 'Đang kết nối lại...' : 'Đang vào phòng...', loading: true);
    } else {
      body = Column(
        children: [
          if (!(ctrl.room?.canPlaybackAudio ?? true))
            MaterialBanner(
              content: const Text('Trình duyệt đang chặn âm thanh.'),
              actions: [TextButton(onPressed: ctrl.room!.startAudio, child: const Text('Bật âm thanh'))],
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _Stage(onStopShare: _toggleScreenShare)),
                      if (ctrl.isOwner)
                        const Positioned(
                            top: 12,
                            right: 12,
                            left: 12,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: JoinRequestsPanel(),
                            )),
                    ],
                  ),
                ),
                if (showSidePanel)
                  SizedBox(
                    width: 340,
                    child: ChatPanel(onClose: () => ctrl.chatVisible = false),
                  ),
              ],
            ),
          ),
          ControlBar(
            onToggleScreenShare: _toggleScreenShare,
            onToggleChat: _toggleChat,
            onLeave: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctrl.info?.name ?? 'Phòng họp'),
            Text(ctrl.code, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          if (ctrl.info != null)
            TextButton.icon(onPressed: _copyLink, icon: const Icon(Icons.link), label: const Text('Copy link')),
          const SizedBox(width: 8),
        ],
      ),
      // Narrow screens show chat as a drawer instead of a side panel.
      endDrawer: wide
          ? null
          : Drawer(
              width: MediaQuery.sizeOf(context).width.clamp(0, 400).toDouble(),
              child: ChatPanel(onClose: () => Navigator.of(context).pop()),
            ),
      onEndDrawerChanged: (open) => ctrl.chatVisible = open,
      body: body,
    );
  }
}

/// Screen share (if any) as the main stage with a participant strip, otherwise a participant grid.
class _Stage extends StatelessWidget {
  final VoidCallback onStopShare;
  const _Stage({required this.onStopShare});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RoomController>();
    final participants = ctrl.participants;
    final local = ctrl.local;
    final share = ScreenShare.find(participants);

    Widget tile(Participant p) => ParticipantTile(p, key: ValueKey(p.identity), isLocal: p == local);

    return LayoutBuilder(builder: (context, c) {
      const pad = 12.0;
      if (share != null) {
        final stage = ScreenShareStage(share: share, isLocal: share.participant == local, onStopLocal: onStopShare);
        final wide = c.maxWidth > c.maxHeight;
        final strip = ListView.separated(
          scrollDirection: wide ? Axis.vertical : Axis.horizontal,
          itemCount: participants.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8, height: 8),
          itemBuilder: (_, i) => AspectRatio(aspectRatio: 16 / 9, child: tile(participants[i])),
        );
        return Padding(
          padding: const EdgeInsets.all(pad),
          child: wide
              ? Row(children: [
                  Expanded(child: stage),
                  const SizedBox(width: 8),
                  SizedBox(width: 220, child: strip),
                ])
              : Column(children: [
                  Expanded(child: stage),
                  const SizedBox(height: 8),
                  SizedBox(height: 110, child: strip),
                ]),
        );
      }

      // Pick the column count that gives the largest 16:9 tiles for the available space.
      final n = participants.length.clamp(1, 100);
      var bestWidth = 0.0;
      for (var cols = 1; cols <= n; cols++) {
        final rows = (n / cols).ceil();
        final w = (c.maxWidth - pad * 2 - (cols - 1) * 8) / cols;
        final h = (c.maxHeight - pad * 2 - (rows - 1) * 8) / rows;
        final tileW = w < h * 16 / 9 ? w : h * 16 / 9;
        if (tileW > bestWidth) bestWidth = tileW;
      }
      // Floor down a hair so rounding never pushes the last tile onto an extra row.
      bestWidth = (bestWidth - 1).clamp(120, double.infinity);
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(pad),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in participants) SizedBox(width: bestWidth, height: bestWidth * 9 / 16, child: tile(p)),
            ],
          ),
        ),
      );
    });
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? action;
  final String? actionLabel;

  const _Message({required this.text, this.loading = false, this.action, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading ? const CircularProgressIndicator() : const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: action, child: Text(actionLabel ?? 'OK')),
            ],
          ],
        ),
      ),
    );
  }
}
