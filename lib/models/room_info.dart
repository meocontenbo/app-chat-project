class RoomInfo {
  final String code;
  final String name;
  final String joinUrl;

  const RoomInfo({required this.code, required this.name, required this.joinUrl});

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
        code: json['code'] as String,
        name: json['name'] as String,
        joinUrl: json['join_url'] as String,
      );

  static final _codeRe = RegExp(r'[a-z]{3}-[a-z]{4}-[a-z]{3}');

  /// Extracts a room code from either a bare code or a full join link.
  static String? parseCode(String input) =>
      _codeRe.firstMatch(input.trim().toLowerCase())?.group(0);
}

class JoinInfo {
  final RoomInfo room;
  final String livekitUrl;
  final String token;
  final bool isOwner;

  const JoinInfo({required this.room, required this.livekitUrl, required this.token, required this.isOwner});

  factory JoinInfo.fromJson(Map<String, dynamic> json) => JoinInfo(
        room: RoomInfo.fromJson(json['room'] as Map<String, dynamic>),
        livekitUrl: json['livekit_url'] as String,
        token: json['token'] as String,
        isOwner: json['is_owner'] as bool? ?? false,
      );
}
