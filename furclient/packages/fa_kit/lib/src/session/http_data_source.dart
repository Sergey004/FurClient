import 'dart:typed_data';

/// HTTP method enum.
enum HTTPMethod { GET, POST }

/// Simple cookie representation for cross-platform compatibility.
class FACookie {
  final String name;
  final String value;

  const FACookie({required this.name, required this.value});

  @override
  String toString() => '$name=$value';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FACookie && name == other.name && value == other.value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// Abstract interface for HTTP data fetching.
///
/// Implementations handle the actual network requests with cookie management.
abstract class HTTPDataSource {
  /// Fetch data from a URL with optional cookies, method, and parameters.
  Future<Uint8List> httpData({
    required Uri url,
    List<FACookie>? cookies,
    HTTPMethod method = HTTPMethod.GET,
    Map<String, String>? parameters,
  });
}
