import 'dart:io';
import 'dart:typed_data';

/// HTTP method enum.
enum HTTPMethod { get, post }

/// Abstract interface for HTTP data fetching.
///
/// Implementations handle the actual network requests with cookie management.
abstract class HTTPDataSource {
  /// Fetch data from a URL with optional cookies, method, and parameters.
  Future<Uint8List> httpData({
    required Uri url,
    List<Cookie>? cookies,
    HTTPMethod method = HTTPMethod.get,
    Map<String, String>? parameters,
  });

  /// Convenience GET with no parameters.
  Future<Uint8List> httpGet({
    required Uri url,
    List<Cookie>? cookies,
  }) {
    return httpData(url: url, cookies: cookies);
  }
}
