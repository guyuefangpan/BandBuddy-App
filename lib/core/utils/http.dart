import 'package:dio/dio.dart';
import '../config.dart';

/// 全局 Dio 实例：统一超时、UA、会话 Cookie 注入
class Http {
  Http._();

  static Dio? _dio;
  static String _apiKey = '';
  static Map<String, String> _sessionCookies = {};

  static Dio get dio {
    if (_dio != null) return _dio!;
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.bandbbsApiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'User-Agent': 'BandBuddyApp/1.0 (resource aggregator for mi band)',
        'Accept': 'application/json, text/html, */*',
      },
    ));
    // 统一注入 API Key（如有）与会话 Cookie
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_apiKey.isNotEmpty &&
            options.uri.host == Uri.parse(AppConfig.bandbbsApiBase).host) {
          options.headers[AppConfig.xfApiKeyHeader] = _apiKey;
        }
        if (_sessionCookies.isNotEmpty &&
            options.uri.host == Uri.parse(AppConfig.bandbbsBase).host) {
          options.headers['Cookie'] =
              _sessionCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
        }
        handler.next(options);
      },
    ));
    return _dio!;
  }

  static void setApiKey(String key) => _apiKey = key.trim();

  /// 设置全局会话 Cookie（米坛登录态）
  static void setSessionCookies(Map<String, String> cookies) {
    _sessionCookies = Map.of(cookies);
  }

  /// 是否已持有米坛登录会话
  static bool get hasSessionCookie =>
      _sessionCookies.containsKey('xf_user') &&
      (_sessionCookies['xf_user'] ?? '').isNotEmpty;

  /// 访问站内 HTML 页面（自动携带登录会话；可额外指定 cookies 覆盖）
  static Future<Response<String>> getHtml(String url,
      {Map<String, String>? cookies}) {
    final merged = {..._sessionCookies, ...?cookies};
    final opts = Options(
      responseType: ResponseType.plain,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36',
        if (merged.isNotEmpty)
          'Cookie': merged.entries.map((e) => '${e.key}=${e.value}').join('; '),
      },
    );
    return dio.get<String>(url, options: opts);
  }
}
