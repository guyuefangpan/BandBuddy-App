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
  double _fontScale = 1.0;
  List<String> _searchHistory = [];
  String _bandAuthKey = '';

  bool get useHtmlFallback => _useHtmlFallback;
  bool get useBandBbs => _useBandBbs;
  bool get useGitHub => _useGitHub;
  List<String> get githubRepos => _githubRepos
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String get updateRepo => _updateRepo.trim();
  double get fontScale => _fontScale;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  String get bandAuthKey => _bandAuthKey;

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
    _fontScale = _prefs?.getDouble('font_scale') ?? 1.0;
    _searchHistory =
        (_prefs?.getStringList('search_history') ?? const []).toList();
    _bandAuthKey = _prefs?.getString('band_auth_key') ?? '';
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

  // ===== 字体大小 =====
  Future<void> setFontScale(double v) async {
    _fontScale = v;
    await _prefs?.setDouble('font_scale', v);
    notifyListeners();
  }

  // ===== 搜索历史 =====
  Future<void> addSearchHistory(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    _searchHistory.remove(kw);
    _searchHistory.insert(0, kw);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    await _prefs?.setStringList('search_history', _searchHistory);
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    _searchHistory = [];
    await _prefs?.setStringList('search_history', []);
    notifyListeners();
  }

  // ===== 手环 AuthKey（蓝牙直装第一期用） =====
  Future<void> saveBandAuthKey(String key) async {
    _bandAuthKey = key.trim();
    await _prefs?.setString('band_auth_key', _bandAuthKey);
    notifyListeners();
  }
}
