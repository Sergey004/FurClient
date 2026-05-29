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

class CookieData {
  final String name;
  final String value;
  final String domain;
  final String path;
  final bool isHttpOnly;
  final bool isSecure;

  const CookieData({
    required this.name,
    required this.value,
    this.domain = '.furaffinity.net',
    this.path = '/',
    this.isHttpOnly = false,
    this.isSecure = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'domain': domain,
        'path': path,
        'isHttpOnly': isHttpOnly,
        'isSecure': isSecure,
      };

  factory CookieData.fromJson(Map<String, dynamic> json) => CookieData(
        name: json['name'] as String,
        value: json['value'] as String,
        domain: json['domain'] as String? ?? '.furaffinity.net',
        path: json['path'] as String? ?? '/',
        isHttpOnly: json['isHttpOnly'] as bool? ?? false,
        isSecure: json['isSecure'] as bool? ?? true,
      );
}
