import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';
import '../core/utils/http.dart';

/// 米坛社区会话管理：账号密码登录（模拟站内登录表单），
/// 登录后保存会话 Cookie，供 App 内直接下载使用。
/// 密码仅用于登录瞬间，不持久化；仅持久化会话 Cookie。
class BandBbsSessionProvider extends ChangeNotifier {
  static const _keyCookie = 'bandbbs.session.cookie';
  static const _keyUsername = 'bandbbs.session.username';

  SharedPreferences? _prefs;
  Map<String, String> _cookies = {};
  String _username = '';
  bool _loggingIn = false;
  String? _loginError;

  Map<String, String> get cookies => Map.unmodifiable(_cookies);
  String get username => _username;
  bool get loggingIn => _loggingIn;
  String? get loginError => _loginError;
  bool get isLoggedIn => _cookies.containsKey('xf_user');

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cookies = _parseCookies(_prefs?.getString(_keyCookie) ?? '');
    _username = _prefs?.getString(_keyUsername) ?? '';
    Http.setSessionCookies(_cookies);
    notifyListeners();
  }

  /// 登录米坛：GET 登录页取 CSRF token → POST 登录表单 → 保存会话 Cookie
  Future<bool> login({required String username, required String password}) async {
    _loggingIn = true;
    _loginError = null;
    notifyListeners();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36',
        },
      ));
      // 1. GET 登录页（建立会话 + 拿 CSRF token）
      final pageResp = await dio.get<String>('${AppConfig.bandbbsBase}/login/login');
      final html = pageResp.data ?? '';
      final tokenMatch = RegExp(
              r'name="_xfToken"\s+value="([^"]+)"')
          .firstMatch(html);
      final csrfCookie =
          pageResp.headers['set-cookie'] ?? const [];
      if (tokenMatch == null) {
        _loginError = '无法获取登录凭证，请重试';
        return false;
      }
      final token = tokenMatch.group(1)!;

      // 2. POST 登录
      final resp = await dio.post<dynamic>(
        '${AppConfig.bandbbsBase}/login/login',
        data: {
          'login': username,
          'password': password,
          '_xfToken': token,
          'remember': '1',
          '_xfRedirect': '${AppConfig.bandbbsBase}/',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': '${AppConfig.bandbbsBase}/login/login',
          },
        ),
      );

      // 3. 汇总 cookie（登录响应 set-cookie 中应含 xf_user/xf_session）
      final allCookies = <String, String>{};
      for (final h in [
        ...csrfCookie,
        ...(resp.headers['set-cookie'] ?? const []),
      ]) {
        final kv = h.split(';').first.trim();
        final idx = kv.indexOf('=');
        if (idx > 0) {
          allCookies[kv.substring(0, idx).trim()] =
              kv.substring(idx + 1).trim();
        }
      }
      // 登录成功判定：xf_user 存在且非空
      final user = allCookies['xf_user'];
      if (user == null || user.isEmpty || user == 'deleted') {
        _loginError = '登录失败：账号或密码错误';
        return false;
      }
      _cookies = allCookies;
      _username = username;
      await _persist();
      Http.setSessionCookies(_cookies);
      _loginError = null;
      return true;
    } on DioException catch (e) {
      debugPrint('bandbbs login error: ${e.message}');
      _loginError = '网络错误：${e.message}';
      return false;
    } catch (e) {
      debugPrint('bandbbs login unexpected: $e');
      _loginError = '登录失败：$e';
      return false;
    } finally {
      _loggingIn = false;
      notifyListeners();
    }
  }

  /// 保存从 WebView 抓取的登录会话（网页方式登录）
  Future<void> saveWebSession(Map<String, String> cookies,
      {String? username}) async {
    _cookies = cookies;
    if (username != null && username.isNotEmpty) {
      _username = username;
    }
    _loginError = null;
    await _persist();
    Http.setSessionCookies(_cookies);
    notifyListeners();
  }

  Future<void> signOut() async {
    _cookies = {};
    _username = '';
    _loginError = null;
    await _prefs?.remove(_keyCookie);
    await _prefs?.remove(_keyUsername);
    Http.setSessionCookies({});
    notifyListeners();
  }

  Future<void> _persist() async {
    final buf = StringBuffer();
    _cookies.forEach((k, v) => buf.write('$k=$v; '));
    await _prefs?.setString(_keyCookie, buf.toString().trim());
    await _prefs?.setString(_keyUsername, _username);
  }

  static Map<String, String> _parseCookies(String raw) {
    final map = <String, String>{};
    if (raw.isEmpty) return map;
    for (final part in raw.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final k = part.substring(0, idx).trim();
      final v = part.substring(idx + 1).trim();
      if (k.isNotEmpty && v.isNotEmpty) map[k] = v;
    }
    return map;
  }

  /// 登录状态描述（供 UI 展示）
  String get statusText {
    if (isLoggedIn) {
      return _username.isNotEmpty ? '已登录：$_username' : '已登录米坛';
    }
    return '未登录（登录后可在应用内直接下载资源）';
  }

  /// 序列化调试用（不含密码）
  Map<String, Object?> debugInfo() => {
        'loggedIn': isLoggedIn,
        'username': _username,
        'cookieKeys': _cookies.keys.toList(),
      };
}
