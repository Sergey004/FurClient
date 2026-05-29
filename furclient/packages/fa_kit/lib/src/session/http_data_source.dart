import 'dart:io' show Cookie;
import 'dart:typed_data';

/// HTTP method enum.
enum HTTPMethod { get, post }

/// Abstract class for HTTP data fetching.
/// Аналог iOS HTTPDataSource протокола.
abstract class HTTPDataSource {
  /// Fetch data from a URL with optional cookies, method, and parameters.
  Future<Uint8List> httpData({
    required Uri url,
    List<Cookie>? cookies,
    HTTPMethod method = HTTPMethod.get,
    Map<String, String>? parameters,
  });

  /// Convenience GET — аналог iOS httpData(from:cookies:)
  Future<Uint8List> httpGet({
    required Uri url,
    List<Cookie>? cookies,
  }) =>
      httpData(url: url, cookies: cookies, method: HTTPMethod.get);
}
