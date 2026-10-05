import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

import '../config.dart';
import '../models/room_info.dart';
import '../services/api_client.dart';
import '../services/room_api.dart';

class ChatMessage {
  final String senderName;
  final bool isLocal;
  final String text;
  final DateTime time;

  const ChatMessage({required this.senderName, required this.isLocal, required this.text, required this.time});
}

/// Owns the LiveKit [Room] for one meeting: connection, media toggles, devices and in-call chat.
/// Chat is sent over the LiveKit data channel and lives only for the session (no history).
class RoomController extends ChangeNotifier {
  static const chatTopic = 'chat';
  static const maxChatLength = 2000;

  final RoomApi _api;
  final String code;

  RoomController(this._api, this.code);

  Room? room;
  RoomInfo? info;
  String? error;
  bool _leaving = false;
  bool _disposed = false;

  /// Guest is in the lobby waiting for the owner to let them in.
  bool waitingApproval = false;
  String? _requestId;

  /// Owner only: guests currently knocking.
  bool isOwner = false;
  List<JoinRequestInfo> joinRequests = [];

  final List<ChatMessage> messages = [];
  int unread = 0;
  bool _chatVisible = false;

  List<MediaDevice> audioInputs = [];
  List<MediaDevice> audioOutputs = [];
  List<MediaDevice> videoInputs = [];

  EventsListener<RoomEvent>? _listener;
  StreamSubscription<List<MediaDevice>>? _deviceSub;

  LocalParticipant? get local => room?.localParticipant;
  bool get connected => room?.connectionState == ConnectionState.connected;
  bool get reconnecting => room?.connectionState == ConnectionState.reconnecting;
  bool get micOn => local?.isMicrophoneEnabled() ?? false;
  bool get cameraOn => local?.isCameraEnabled() ?? false;
  bool get screenShareOn => local?.isScreenShareEnabled() ?? false;

  /// Mobile browsers can't share the screen; iOS needs the Broadcast Extension build.
  bool get canScreenShare {
    if (lkPlatformIsWebMobile()) return false;
    if (lkPlatformIs(PlatformType.iOS)) return AppConfig.iosBroadcastExtension;
    return true;
  }

  List<Participant> get participants => [
        if (local != null) local!,
        ...?room?.remoteParticipants.values,
      ];

  set chatVisible(bool v) {
    _chatVisible = v;
    if (v) unread = 0;
    _notify();
  }

  bool get chatVisible => _chatVisible;

  /// Screen share: captured and sent at 1080p30. Two lower simulcast layers let the SFU hand
  /// 720p or 360p to viewers whose connection can't keep up, and switch back up when it recovers.
  static const _screenShareParams = VideoParametersPresets.screenShareH1080FPS30;
  static const _roomOptions = RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultAudioCaptureOptions: AudioCaptureOptions(
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    ),
    defaultCameraCaptureOptions: CameraCaptureOptions(params: VideoParametersPresets.h720_169),
    // useiOSBroadcastExtension only affects iOS: capture the whole device via the extension.
    defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
      params: _screenShareParams,
      useiOSBroadcastExtension: true,
    ),
    defaultVideoPublishOptions: VideoPublishOptions(
      simulcast: true,
      screenShareEncoding: VideoEncoding(maxBitrate: 5000 * 1000, maxFramerate: 30),
      screenShareSimulcastLayers: [
        VideoParameters(
          dimensions: VideoDimensionsPresets.h360_169,
          encoding: VideoEncoding(maxBitrate: 400 * 1000, maxFramerate: 15),
        ),
        VideoParameters(
          dimensions: VideoDimensionsPresets.h720_169,
          encoding: VideoEncoding(maxBitrate: 1800 * 1000, maxFramerate: 30),
        ),
      ],
    ),
  );

  Future<void> connect() async {
    try {
      final join = await _admit();
      if (join == null) return;
      info = join.room;
      isOwner = join.isOwner;

      final r = Room(roomOptions: _roomOptions);
      room = r;
      r.addListener(_notify);
      _listener = r.createListener()
        ..on<DataReceivedEvent>(_onData)
        ..on<RoomDisconnectedEvent>((e) {
          if (!_leaving) error = 'Mất kết nối với phòng (${e.reason?.name ?? 'unknown'})';
        })
        ..listen((_) => _notify());

      await r.connect(join.livekitUrl, join.token);
      try {
        await r.localParticipant?.setMicrophoneEnabled(true);
      } catch (e) {
        _notice('Không bật được micro: $e');
      }
      await _loadDevices();
      _deviceSub = Hardware.instance.onDeviceChange.stream.listen((_) => _loadDevices());
      if (isOwner) unawaited(_watchJoinRequests());
    } catch (e) {
      error = e.toString();
    }
    _notify();
  }

  // ---- lobby ---------------------------------------------------------------

  /// Gets a LiveKit token: immediately for the owner, otherwise after the owner approves.
  /// Returns null if the controller was disposed or the request was denied.
  Future<JoinInfo?> _admit() async {
    var result = await _api.join(code);
    while (result.join == null) {
      if (_disposed) return null;
      if (result.denied) {
        waitingApproval = false;
        _requestId = null;
        error = 'Chủ phòng đã từ chối yêu cầu tham gia của bạn.';
        _notify();
        return null;
      }
      info ??= result.room;
      _requestId = result.requestId;
      waitingApproval = true;
      _notify();
      try {
        result = await _api.waitForApproval(code, _requestId!);
      } on ApiException catch (e) {
        if (_disposed) return null;
        // Request vanished (e.g. server restarted): knock again.
        if (e.statusCode == 404) {
          result = await _api.join(code);
        } else {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
    waitingApproval = false;
    _requestId = null;
    return _disposed ? null : result.join;
  }

  Future<void> _watchJoinRequests() async {
    int? version;
    while (!_disposed) {
      try {
        final (v, list) = await _api.pendingRequests(code, version: version);
        if (_disposed) return;
        version = v;
        joinRequests = list;
        _notify();
      } catch (_) {
        if (_disposed) return;
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
  }

  Future<void> decideJoinRequest(JoinRequestInfo req, {required bool approve}) async {
    joinRequests = joinRequests.where((r) => r.id != req.id).toList();
    _notify();
    try {
      await _api.decide(code, req.id, approve: approve);
    } catch (e) {
      _notice('Không xử lý được yêu cầu của ${req.name}: $e');
    }
  }

  // ---- media toggles -------------------------------------------------------

  Future<void> toggleMic() => _guard('micro', () => local!.setMicrophoneEnabled(!micOn));

  Future<void> toggleCamera() async {
    await _guard('camera', () => local!.setCameraEnabled(!cameraOn));
    // Device labels are only exposed after the first camera permission grant.
    await _loadDevices();
  }

  /// [pickDesktopSource] shows the screen/window picker on desktop and returns the source id.
  Future<void> toggleScreenShare(Future<String?> Function() pickDesktopSource) async {
    final lp = local;
    if (lp == null) return;
    if (screenShareOn) {
      await _guard('chia sẻ màn hình', () => lp.setScreenShareEnabled(false));
      if (lkPlatformIs(PlatformType.android) && FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      return;
    }
    if (!canScreenShare) {
      _notice('Trình duyệt trên điện thoại không hỗ trợ chia sẻ màn hình');
      return;
    }

    await _guard('chia sẻ màn hình', () async {
      if (lkPlatformIsDesktop()) {
        final sourceId = await pickDesktopSource();
        if (sourceId == null) return;
        final track = await LocalVideoTrack.createScreenShareTrack(
          ScreenShareCaptureOptions(sourceId: sourceId, maxFrameRate: 30, params: _screenShareParams),
        );
        await lp.publishVideoTrack(track);
        return;
      }
      if (lkPlatformIs(PlatformType.iOS)) {
        // Opens the system broadcast picker; LiveKit publishes the track once the user taps
        // "Start Broadcast" and unpublishes it when the broadcast stops.
        await lp.setScreenShareEnabled(true);
        return;
      }
      if (lkPlatformIs(PlatformType.android)) {
        // Android needs MediaProjection consent plus a foreground service while capturing.
        if (!await rtc.Helper.requestCapturePermission()) return;
        await _startAndroidForegroundService();
      }
      await lp.setScreenShareEnabled(true, captureScreenAudio: true);
    });
  }

  Future<void> _startAndroidForegroundService() async {
    const config = FlutterBackgroundAndroidConfig(
      notificationTitle: 'App Chat',
      notificationText: 'Đang chia sẻ màn hình',
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    if (await FlutterBackground.initialize(androidConfig: config) &&
        !FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.enableBackgroundExecution();
    }
  }

  // ---- devices -------------------------------------------------------------

  Future<void> _loadDevices() async {
    final all = await Hardware.instance.enumerateDevices();
    audioInputs = all.where((d) => d.kind == 'audioinput').toList();
    audioOutputs = all.where((d) => d.kind == 'audiooutput').toList();
    videoInputs = all.where((d) => d.kind == 'videoinput').toList();
    _notify();
  }

  MediaDevice? get selectedAudioInput => Hardware.instance.selectedAudioInput;
  MediaDevice? get selectedAudioOutput => Hardware.instance.selectedAudioOutput;
  MediaDevice? get selectedVideoInput => Hardware.instance.selectedVideoInput;

  Future<void> selectAudioInput(MediaDevice d) => _guard('micro', () => room!.setAudioInputDevice(d));
  Future<void> selectAudioOutput(MediaDevice d) => _guard('loa', () => room!.setAudioOutputDevice(d));
  Future<void> selectVideoInput(MediaDevice d) async {
    Hardware.instance.selectedVideoInput = d;
    await _guard('camera', () => room!.setVideoInputDevice(d));
  }

  // ---- chat ----------------------------------------------------------------

  Future<void> sendChat(String text) async {
    text = text.trim();
    if (text.isEmpty || local == null) return;
    if (text.length > maxChatLength) text = text.substring(0, maxChatLength);
    final payload = utf8.encode(jsonEncode({'text': text}));
    await _guard('gửi tin nhắn', () async {
      await local!.publishData(payload, reliable: true, topic: chatTopic);
      messages.add(ChatMessage(senderName: local!.name, isLocal: true, text: text, time: DateTime.now()));
    });
  }

  void _onData(DataReceivedEvent e) {
    if (e.topic != chatTopic) return;
    try {
      final text = (jsonDecode(utf8.decode(e.data)) as Map<String, dynamic>)['text'] as String;
      final sender = e.participant;
      messages.add(ChatMessage(
        senderName: sender == null ? 'Hệ thống' : (sender.name.isNotEmpty ? sender.name : sender.identity),
        isLocal: false,
        text: text,
        time: DateTime.now(),
      ));
      if (!_chatVisible) unread++;
      _notify();
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  // ---- helpers -------------------------------------------------------------

  /// Last transient error for the UI to show as a snackbar; cleared once read.
  String? takeNotice() {
    final n = _pendingNotice;
    _pendingNotice = null;
    return n;
  }

  String? _pendingNotice;

  void _notice(String msg) {
    _pendingNotice = msg;
    _notify();
  }

  Future<void> _guard(String what, Future<void> Function() action) async {
    if (room == null) return;
    try {
      await action();
    } catch (e) {
      _notice('Lỗi $what: $e');
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _leaving = true;
    final pending = _requestId;
    if (pending != null) _api.cancelRequest(code, pending).ignore();
    _deviceSub?.cancel();
    _listener?.dispose();
    final r = room;
    if (r != null) {
      r.removeListener(_notify);
      r.disconnect().whenComplete(r.dispose);
    }
    if (lkPlatformIs(PlatformType.android) && FlutterBackground.isBackgroundExecutionEnabled) {
      FlutterBackground.disableBackgroundExecution();
    }
    super.dispose();
  }
}
