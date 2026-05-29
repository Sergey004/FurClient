import 'dart:io' show Cookie;
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
    List<Cookie>? cookies,
    HTTPMethod method = HTTPMethod.get,
    Map<String, String>? parameters,
  }) async {
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Referer': 'https://www.furaffinity.net',
    };

    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
    }

    http.Response response;

    if (method == HTTPMethod.post) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=utf-8';
      response = await _client.post(
        url,
        headers: headers,
        body: parameters != null ? _encodeFormData(parameters) : '',
      );
    } else {
      Uri requestUrl = url;
      if (parameters != null && parameters.isNotEmpty) {
        requestUrl = url.replace(queryParameters: {
          ...url.queryParameters,
          ...parameters,
        });
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

  String _encodeFormData(Map<String, String> data) {
    return data.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void close() => _client.close();

  @override
  Future<Uint8List> httpGet({
    required Uri url,
    List<Cookie>? cookies,
  }) =>
      httpData(url: url, cookies: cookies, method: HTTPMethod.get);
}

/// HTTP error with status code.
class HttpError implements Exception {
  final int statusCode;
  final String description;

  const HttpError({required this.statusCode, required this.description});

  @override
  String toString() => 'HttpError: $statusCode - $description';
}
