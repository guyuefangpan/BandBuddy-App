import 'package:flutter/foundation.dart';
import '../core/models/band_resource.dart';
import '../data/adapters/bandbbs_html_adapter.dart';
import '../data/adapters/base_adapter.dart';
import '../data/adapters/github_adapter.dart';
import 'settings_provider.dart';

/// 资源流聚合 Provider：多数据源合并、分类/类型筛选、分页加载
class ResourceProvider extends ChangeNotifier {
  final SettingsProvider settings;

  ResourceProvider(this.settings);

  final List<BandResource> _resources = [];
  bool _loading = false;
  String? _error;
  String _categoryId = 'all';
  String _typeTag = '全部';
  String _keyword = '';
  String _order = 'rating_weighted'; // 米坛排序：rating_weighted 推荐 / latest 最新
  int _page = 1;
  bool _hasMore = true;

  List<BandResource> get resources => _resources;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String get categoryId => _categoryId;
  String get typeTag => _typeTag;
  String get keyword => _keyword;
  String get order => _order;

  /// 构建当前启用的适配器列表
  List<ResourceAdapter> _buildAdapters() {
    final list = <ResourceAdapter>[];
    if (settings.useBandBbs) {
      // 米坛统一走页面兜底（自动携带登录会话；API Key 模式已移除）
      if (settings.useHtmlFallback) {
        list.add(BandBbsHtmlAdapter()..order = _order);
      }
    }
    if (settings.useGitHub) {
      list.add(GitHubAdapter(repos: settings.githubRepos));
    }
    return list;
  }

  Future<void> refresh({
    String? categoryId,
    String? typeTag,
    String? keyword,
    String? order,
  }) async {
    if (categoryId != null) _categoryId = categoryId;
    if (typeTag != null) _typeTag = typeTag;
    if (keyword != null) _keyword = keyword;
    if (order != null) _order = order;
    _page = 1;
    _hasMore = true;
    _resources.clear();
    await _loadPage();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    await _loadPage();
  }

  /// 聚合搜索：按关键词 + 型号 + 类型筛选
  /// 米坛站内搜索需登录（游客不可用），改用列表多页抓取 + 本地过滤；
  /// GitHub 源客户端过滤
  Future<void> search({
    String? keyword,
    String? categoryId,
    String? typeTag,
  }) async {
    if (keyword != null) _keyword = keyword;
    if (categoryId != null) _categoryId = categoryId;
    if (typeTag != null) _typeTag = typeTag;
    _loading = true;
    _error = null;
    _resources.clear();
    notifyListeners();

    final adapters = _buildAdapters();
    if (adapters.isEmpty) {
      _error = '未启用任何数据源，请到「我的 → 数据源管理」开启';
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait(adapters.map((a) async {
        if (a is BandBbsHtmlAdapter) {
          return a.fetchSearch(
            keyword: _keyword,
            categoryId: _categoryId,
            typeTag: _typeTag,
          );
        }
        if (a is GitHubAdapter) {
          final items = await a
              .fetchResources(page: 1, categoryId: 'all');
          final kw = _keyword.trim().toLowerCase();
          final wantType = _typeTag;
          return items.where((r) {
            if (kw.isNotEmpty &&
                !'${r.title} ${r.author} ${r.description}'
                    .toLowerCase()
                    .contains(kw)) {
              return false;
            }
            if (wantType != '全部' && !r.category.contains(wantType)) {
              return false;
            }
            return true;
          }).toList();
        }
        return <BandResource>[];
      }));

      final seen = <String>{};
      for (final list in results) {
        for (final r in list) {
          if (seen.add(r.uniqueKey)) _resources.add(r);
        }
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadPage() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final adapters = _buildAdapters();
    if (adapters.isEmpty) {
      _error = '未启用任何数据源，请到「我的 → 数据源管理」开启';
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait(adapters.map((a) async {
        // GitHub 源只在「全部」或指定 github 分类时参与
        if (a is GitHubAdapter &&
            _categoryId != 'all' &&
            _categoryId != 'github') {
          return <BandResource>[];
        }
        if (a is BandBbsHtmlAdapter && _categoryId == 'github') {
          return <BandResource>[];
        }
        return a.fetchResources(
          page: _page,
          categoryId: _categoryId,
          typeTag: _typeTag,
          keyword: _keyword,
        );
      }));

      final merged = <BandResource>[];
      for (final r in results) {
        merged.addAll(r);
      }
      // 类型标签筛选（HTML/API 模式下列表已含分类标签）
      final filtered = _typeTag == '全部'
          ? merged
          : merged
              .where((r) => r.category.contains(_typeTag))
              .toList();

      if (_page == 1) {
        _resources.clear();
      }
      // 去重
      final seen = <String>{};
      for (final r in filtered) {
        if (seen.add(r.uniqueKey)) {
          _resources.add(r);
        }
      }
      _hasMore = filtered.length >= 20;
      _page++;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _loading = false;
    notifyListeners();
  }

  /// 详情页增强：拉取完整描述/下载链接
  Future<BandResource> fetchDetail(BandResource r) async {
    final adapters = _buildAdapters();
    for (final a in adapters) {
      if (a.sourceName == r.source) {
        return a.fetchDetail(r);
      }
    }
    return r;
  }
}
