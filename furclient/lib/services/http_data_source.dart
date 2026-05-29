import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';

/// HTTP методы для запросов
enum HttpMethod {
  get('GET'),
  post('POST');

  final String value;
  const HttpMethod(this.value);
}

/// Абстрактный интерфейс для HTTP запросов (аналог iOS HTTPDataSource)
/// Позволяет отделить логику получения данных от реализации сети.
abstract interface class HttpDataSource {
  /// Выполняет HTTP запрос и возвращает данные
  ///
  /// [url] - URL для запроса
  /// [method] - HTTP метод (GET/POST)
  /// [parameters] - Query параметры или POST параметры
  /// [cookies] - Cookies для запроса (опционально)
  Future<String> httpData({
    required Uri url,
    required HttpMethod method,
    List<MapEntry<String, String>> parameters = const [],
    List<Cookie>? cookies,
  });
}

/// Реализация HttpDataSource на основе Dio
class DioHttpDataSource implements HttpDataSource {
  final Dio _dio;

  DioHttpDataSource(this._dio);

  Future<String> getData({
    required Uri url,
    List<Cookie>? cookies,
  }) =>
      httpData(
        url: url,
        method: HttpMethod.get,
        cookies: cookies,
      );

  @override
  Future<String> httpData({
    required Uri url,
    required HttpMethod method,
    List<MapEntry<String, String>> parameters = const [],
    List<Cookie>? cookies,
  }) async {
    try {
      final requestUrl = _buildUrl(url, method, parameters);

      final response = await _dio.request(
        requestUrl.toString(),
        options: Options(
          method: method.value,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == null ||
          (response.statusCode! >= 300 && response.statusCode != 400)) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'HTTP ${response.statusCode}: Failed to fetch data',
        );
      }

      final data = response.data;
      if (data is String) return data;
      if (data is List<int>) return String.fromCharCodes(data);

      return data.toString();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 503) {
        throw CloudflareException(
          'Cloudflare protection is active. Please re-login.',
        );
      }
      rethrow;
    }
  }

  /// Строит URL с параметрами
  Uri _buildUrl(
    Uri url,
    HttpMethod method,
    List<MapEntry<String, String>> parameters,
  ) {
    if (method == HttpMethod.get) {
      if (parameters.isEmpty) return url;
      final queryParams = Map<String, String>.fromEntries(parameters);
      return url.replace(queryParameters: queryParams);
    }
    return url;
  }
}

/// Исключение для Cloudflare challenge
class CloudflareException implements Exception {
  final String message;
  CloudflareException(this.message);

  @override
  String toString() => 'CloudflareException: $message';
}
