import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/config.dart';
import '../providers/bandbbs_session_provider.dart';

/// 米坛账号登录页（网页方式）
/// 在应用内网页（WebView，使用桌面 Chrome UA 规避站点检测）打开米坛登录页，
/// 用户登录完成后点击「已完成登录」，软件自动抓取会话 Cookie 保存，
/// 之后即可在 App 内直接下载资源。密码不经过本应用。
class BandBbsLoginPage extends StatefulWidget {
  const BandBbsLoginPage({super.key});

  @override
  State<BandBbsLoginPage> createState() => _BandBbsLoginPageState();
}

class _BandBbsLoginPageState extends State<BandBbsLoginPage> {
  static const _chromeUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // 关键：使用桌面 Chrome UA，避免米坛识别 WebView（wv 特征）后拦截
      ..setUserAgent(_chromeUA)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            // 页面加载完成后自动尝试提取登录态
            _tryExtract(auto: true);
          },
        ),
      )
      ..loadRequest(Uri.parse('${AppConfig.bandbbsBase}/login/login'));
    // 若本地已保存会话（此前登录过），直接提示并返回
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<BandBbsSessionProvider>();
      if (session.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已登录米坛，可直接在应用内下载资源')),
        );
        Navigator.of(context).pop(true);
      }
    });
  }

  /// 从 WebView 抓取会话 Cookie
  Future<void> _tryExtract({bool auto = false}) async {
    if (_extracting) return;
    _extracting = true;
    final session = context.read<BandBbsSessionProvider>();
    try {
      final cookieManager = WebViewCookieManager();
      final cookies = await cookieManager.getCookies(
          domain: Uri.parse(AppConfig.bandbbsBase));
      final map = <String, String>{};
      for (final c in cookies) {
        map[c.name] = c.value;
      }
      final loggedIn = map.containsKey('xf_user') && map['xf_user']!.isNotEmpty;
      if (loggedIn) {
        String? username;
        try {
          final title = await _controller
              .runJavaScriptReturningResult('document.title');
          if (title is String && title.isNotEmpty) {
            username = title.split('|').first.trim();
          }
        } catch (_) {}
        await session.saveWebSession(map, username: username);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '检测到米坛已登录${username != null ? '：$username' : ''}，'
                    '会话已同步，可直接下载资源')),
          );
          Navigator.of(context).pop(true);
        }
      } else if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('尚未检测到登录状态，请先在页面中登录米坛')),
        );
      }
    } catch (e) {
      debugPrint('extract cookie failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('抓取会话失败：$e')),
        );
      }
    } finally {
      _extracting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录米坛社区'),
        actions: [
          TextButton(
            onPressed: _extracting ? null : () => _tryExtract(),
            child: const Text('已完成登录', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Text(
              '在下方网页中登录米坛账号（或注册）。登录完成后点击右上角「已完成登录」，'
              '软件会自动抓取会话，之后资源可直接下载到本机。密码不会经过本应用。',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
