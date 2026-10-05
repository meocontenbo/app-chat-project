class User {
  final int id;
  final String username;
  final String email;
  final String displayName;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
      );
}
