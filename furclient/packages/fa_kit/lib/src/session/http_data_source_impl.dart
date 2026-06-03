import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'http_data_source.dart';

/// HTTP data source implementation using the `http` package.
class HttpDataSourceImpl implements HTTPDataSource {
  final http.Client _client;
  final String userAgent;

  HttpDataSourceImpl({
    http.Client? client,
    this.userAgent = 'ceylo.FurAffinityApp/1.0',
  }) : _client = client ?? http.Client();

  @override
  Future<Uint8List> httpData({
    required Uri url,
    List<FACookie>? cookies,
    HTTPMethod method = HTTPMethod.GET,
    Map<String, String>? parameters,
  }) async {
    final headers = <String, String>{
      'User-Agent': userAgent,
    };

    // Add cookies to headers
    if (cookies != null && cookies.isNotEmpty) {
      final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      headers['Cookie'] = cookieHeader;
    }

    http.Response response;

    if (method == HTTPMethod.POST) {
      final body = parameters != null
          ? _encodeFormData(parameters)
          : <String, String>{};
      headers['Content-Type'] =
          'application/x-www-form-urlencoded; charset=utf-8';
      response = await _client.post(url, headers: headers, body: body);
    } else {
      // For GET with parameters, append to URL
      Uri requestUrl = url;
      if (parameters != null && parameters.isNotEmpty) {
        final queryParams = <String, String>{
          ...url.queryParameters,
          ...parameters,
        };
        requestUrl = url.replace(queryParameters: queryParams);
      }
      response = await _client.get(requestUrl, headers: headers);
    }

    if (response.statusCode != 200) {
      throw HttpError(
        statusCode: response.statusCode,
        description: 'HTTP ${response.statusCode} for ${url.path}',
      );
    }

    return response.bodyBytes;
  }

  /// Convenience GET with no parameters.
  Future<Uint8List> httpGet({
    required Uri url,
    List<FACookie>? cookies,
  }) {
    return httpData(url: url, cookies: cookies);
  }

  String _encodeFormData(Map<String, String> data) {
    return data.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Close the underlying HTTP client.
  void close() {
    _client.close();
  }
}

/// HTTP error with status code.
class HttpError implements Exception {
  final int statusCode;
  final String description;

  const HttpError({required this.statusCode, required this.description});

  @override
  String toString() => 'HttpError: $statusCode - $description';
}
