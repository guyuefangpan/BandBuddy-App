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
  String _updateRepo = AppConfig.defaultUpdateRepo;

  bool get useHtmlFallback => _useHtmlFallback;
  bool get useBandBbs => _useBandBbs;
  bool get useGitHub => _useGitHub;
  List<String> get githubRepos => _githubRepos
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String get updateRepo => _updateRepo.trim();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _useHtmlFallback = _prefs?.getBool('use_html_fallback') ?? true;
    _useBandBbs = _prefs?.getBool('use_bandbbs') ?? true;
    _useGitHub = _prefs?.getBool('use_github') ?? true;
    _githubRepos = _prefs?.getString('github_repos') ??
        AppConfig.defaultGitHubRepos.join(',');
    // 更新源：未设置或曾存过空值时回退到默认仓库
    final storedRepo = _prefs?.getString('update_repo') ?? '';
    _updateRepo = storedRepo.trim().isEmpty
        ? AppConfig.defaultUpdateRepo
        : storedRepo.trim();
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

  Future<void> setUpdateRepo(String repo) async {
    _updateRepo = repo.trim();
    await _prefs?.setString('update_repo', _updateRepo);
    notifyListeners();
  }
}
