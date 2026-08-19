import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

/// 设置状态：数据源开关、GitHub 仓库配置
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  bool _useHtmlFallback = true;
  bool _useBandBbs = true;
  bool _useGitHub = true;
  String _githubRepos = AppConfig.defaultGitHubRepos.join(',');

  bool get useHtmlFallback => _useHtmlFallback;
  bool get useBandBbs => _useBandBbs;
  bool get useGitHub => _useGitHub;
  List<String> get githubRepos => _githubRepos
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _useHtmlFallback = _prefs?.getBool('use_html_fallback') ?? true;
    _useBandBbs = _prefs?.getBool('use_bandbbs') ?? true;
    _useGitHub = _prefs?.getBool('use_github') ?? true;
    _githubRepos = _prefs?.getString('github_repos') ??
        AppConfig.defaultGitHubRepos.join(',');
    notifyListeners();
  }

  Future<void> setUseHtmlFallback(bool v) async {
    _useHtmlFallback = v;
    await _prefs?.setBool('use_html_fallback', v);
    notifyListeners();
  }

  Future<void> setUseBandBbs(bool v) async {
    _useBandBbs = v;
    await _prefs?.setBool('use_bandbbs', v);
    notifyListeners();
  }

  Future<void> setUseGitHub(bool v) async {
    _useGitHub = v;
    await _prefs?.setBool('use_github', v);
    notifyListeners();
  }

  Future<void> setGithubRepos(String repos) async {
    _githubRepos = repos.trim();
    await _prefs?.setString('github_repos', _githubRepos);
    notifyListeners();
  }
}
