class UserSession {
  final String username;
  final String avatarUrl;
  final bool isLoggedIn;
  final String? cookies;

  UserSession({
    required this.username,
    required this.avatarUrl,
    required this.isLoggedIn,
    this.cookies,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'avatarUrl': avatarUrl,
        'isLoggedIn': isLoggedIn,
        'cookies': cookies,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        username: json['username'] as String,
        avatarUrl: json['avatarUrl'] as String,
        isLoggedIn: json['isLoggedIn'] as bool,
        cookies: json['cookies'] as String?,
      );
}
