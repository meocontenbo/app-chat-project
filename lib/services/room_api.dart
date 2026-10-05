import '../models/room_info.dart';
import 'api_client.dart';

/// Outcome of asking to join: either let in right away ([join] set) or put in the lobby ([requestId] set).
class JoinResult {
  final JoinInfo? join;
  final String? requestId;
  final RoomInfo? room;
  final bool denied;
  const JoinResult({this.join, this.requestId, this.room, this.denied = false});
}

class JoinRequestInfo {
  final String id;
  final String name;
  final String username;

  const JoinRequestInfo({required this.id, required this.name, required this.username});

  factory JoinRequestInfo.fromJson(Map<String, dynamic> json) => JoinRequestInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        username: json['username'] as String,
      );
}

class RoomApi {
  /// Server holds lobby long-polls for 25s; allow a margin on top.
  static const _longPoll = Duration(seconds: 35);

  final ApiClient api;
  RoomApi(this.api);

  Future<RoomInfo> create(String name) async =>
      RoomInfo.fromJson(await api.post('/rooms', {'name': name}));

  Future<JoinResult> join(String code) async {
    final (status, data) = await api.postWithStatus('/rooms/$code/join', const {});
    if (status == 202) {
      return JoinResult(
        requestId: data['request_id'] as String,
        room: RoomInfo.fromJson(data['room'] as Map<String, dynamic>),
      );
    }
    return JoinResult(join: JoinInfo.fromJson(data));
  }

  /// Waits (long-poll) for the owner's decision on our join request.
  Future<JoinResult> waitForApproval(String code, String requestId) async {
    final data = await api.get('/rooms/$code/join-requests/$requestId?wait=1', timeout: _longPoll);
    return switch (data['status']) {
      'approved' => JoinResult(join: JoinInfo.fromJson(data)),
      'denied' => const JoinResult(denied: true),
      _ => JoinResult(requestId: requestId),
    };
  }

  Future<void> cancelRequest(String code, String requestId) =>
      api.delete('/rooms/$code/join-requests/$requestId');

  /// Owner: pending requests. Passing the last [version] long-polls until the list changes.
  Future<(int, List<JoinRequestInfo>)> pendingRequests(String code, {int? version}) async {
    final q = version == null ? '' : '?version=$version';
    final data = await api.get('/rooms/$code/join-requests$q', timeout: _longPoll);
    final list = (data['requests'] as List)
        .map((e) => JoinRequestInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    return (data['version'] as int, list);
  }

  Future<void> decide(String code, String requestId, {required bool approve}) =>
      api.post('/rooms/$code/join-requests/$requestId/${approve ? 'approve' : 'deny'}', const {});
}
