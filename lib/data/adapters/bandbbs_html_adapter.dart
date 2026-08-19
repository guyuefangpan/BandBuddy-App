import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as hp;
import '../../core/config.dart';
import '../../core/models/band_resource.dart';
import '../../core/utils/http.dart';
import 'base_adapter.dart';

/// 米坛社区 HTML 兜底适配器
/// 未配置 API Key 时使用，解析站内页面（浏览模式，下载需跳转站内）
///
/// 解析策略（2026-08-19 实测米坛新版模板）：
/// - 主列表条目为 `div.structItem.structItem--resource`（含 data-author、
///   structItem-title、structItem-resourceTagLine、资源图标、更新时间）
/// - 兼容旧模板 `li.block-row`（侧边推荐区块）
class BandBbsHtmlAdapter implements ResourceAdapter {
  @override
  String get sourceName => 'bandbbs';

  @override
  bool get enabled => true; // 始终可用（浏览模式）

  /// 排序方式（rating_weighted 推荐 / latest 最新），实例化时指定
  String? order;

  /// 列表页 URL（按型号分类过滤，支持排序）
  String _listUrl({
    String? categoryId,
    int page = 1,
    String? keyword,
    String? order,
  }) {
    final cat = AppConfig.categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => AppConfig.categories.first,
    );
    final buf = StringBuffer(AppConfig.bandbbsBase);
    if (cat.bandbbsCategoryId != null) {
      buf.write('/resources/categories/${cat.bandbbsCategoryId}/');
      buf.write('?page=$page');
    } else {
      buf.write('/resources/?page=$page');
    }
    final effectiveOrder = order ?? this.order;
    if (effectiveOrder != null && effectiveOrder.isNotEmpty) {
      buf.write('&order=$effectiveOrder');
    }
    if (keyword != null && keyword.isNotEmpty) {
      buf.write('&q=${Uri.encodeQueryComponent(keyword)}');
    }
    return buf.toString();
  }

  @override
  Future<List<BandResource>> fetchResources({
    required int page,
    String? categoryId,
    String? typeTag,
    String? keyword,
  }) async {
    final url = _listUrl(categoryId: categoryId, page: page, keyword: keyword);
    final resp = await Http.getHtml(url);
    return parseList(resp.data ?? '');
  }

  /// 客户端聚合搜索（学习 OronBox 服务端搜索思路，无服务器下的近似实现）
  /// - 覆盖范围：跨多个分类 + 多个排序并发抓取列表（最新/推荐），去重后客户端匹配
  /// - 匹配字段：标题 / 作者 / 描述 / 设备型号 / 分类标签
  /// - 米坛站内搜索需登录且 API Key 拿不到，无服务器下只能这样覆盖大部分资源
  Future<List<BandResource>> fetchSearch({
    String? keyword,
    String? categoryId,
    String? typeTag,
    int pagesPerSource = 4,
  }) async {
    // 默认覆盖的型号分类（当用户选"全部"时）：覆盖大部分资源
    const defaultCats = ['all', 'band10', 'band9', 'band8', 'band7', 'band6'];
    final catIds = (categoryId == null ||
            categoryId.isEmpty ||
            categoryId == 'all')
        ? defaultCats
        : [categoryId];
    // 排序：最新 + 推荐（两个排序都抓，覆盖不同维度的资源）
    const orders = ['latest', 'rating_weighted'];

    // 构造所有 (分类 × 排序 × 页) 的抓取任务
    final tasks = <({String catId, int page, String order})>[];
    for (final c in catIds) {
      for (final o in orders) {
        for (var p = 1; p <= pagesPerSource; p++) {
          tasks.add((catId: c, page: p, order: o));
        }
      }
    }

    // 分批并发抓取（限制并发数避免被站点限流）
    final all = <BandResource>[];
    final seen = <String>{};
    const concurrency = 4;
    for (var i = 0; i < tasks.length; i += concurrency) {
      final batch = tasks.skip(i).take(concurrency);
      final results = await Future.wait(batch.map(_fetchOne));
      for (final list in results) {
        for (final r in list) {
          if (seen.add(r.uniqueKey)) all.add(r);
        }
      }
    }

    // 本地过滤：关键词匹配（标题/作者/描述/分类/型号），类型筛选
    final kw = (keyword ?? '').trim().toLowerCase();
    final wantType = (typeTag ?? '全部').trim();
    return all.where((r) {
      if (kw.isNotEmpty) {
        final hay = '${r.title} ${r.author} ${r.description} '
                '${r.category} ${r.deviceModel ?? ''}'
            .toLowerCase();
        if (!hay.contains(kw)) return false;
      }
      if (wantType.isNotEmpty &&
          wantType != '全部' &&
          !r.category.contains(wantType)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<List<BandResource>> _fetchOne(
      ({String catId, int page, String order}) t) async {
    try {
      final url = _listUrl(categoryId: t.catId, page: t.page, order: t.order);
      final resp = await Http.getHtml(url);
      return parseList(resp.data ?? '');
    } catch (_) {
      return <BandResource>[];
    }
  }

  /// 解析资源列表页 HTML（公开以便测试）
  List<BandResource> parseList(String html) {
    final doc = hp.parse(html);
    final result = <BandResource>[];

    // ===== 主解析：structItem 条目（当前模板） =====
    for (final item in doc.querySelectorAll('div.structItem--resource')) {
      // 标题在 .structItem-title 里（第一个 /resources/ a 实际是顶部时间链接，
      // 选中会拿不到真实标题 → 显示发布时间）
      final link = item.querySelector(
          'div.structItem-title a[href*="/resources/"]');
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final idMatch = RegExp(r'/resources/(\d+)/').firstMatch(href);
      if (idMatch == null) continue;
      final rid = idMatch.group(1)!;

      // 标题
      String title = link.text.trim();
      if (title.isEmpty) {
        final img = item.querySelector('img[src*="resource_icons"]');
        title = img?.attributes['alt'] ?? '未知资源';
      }

      // 作者（data-author 或 avatar alt）
      String author = item.attributes['data-author'] ?? '';
      if (author.isEmpty) {
        final avatar = item.querySelector('img.avatar-u');
        author = avatar?.attributes['alt'] ?? '';
      }

      // 描述
      String desc = '';
      final tagline = item.querySelector('div.structItem-resourceTagLine');
      if (tagline != null) desc = tagline.text.trim();

      // 图标
      String? cover;
      final img = item.querySelector('img[src*="resource_icons"]');
      if (img != null) {
        cover = img.attributes['src'];
        if (cover!.startsWith('/')) {
          cover = '${AppConfig.bandbbsBase}$cover';
        }
      }

      // 更新时间
      DateTime? updatedAt;
      final time = item.querySelector('time');
      if (time != null) {
        updatedAt = DateTime.tryParse(time.attributes['datetime'] ?? '');
      }

      // 分类标签（label/prefix 标签）
      String category = '资源';
      final label = item.querySelector('span.label');
      if (label != null && label.text.trim().isNotEmpty) {
        category = label.text.trim();
      }

      result.add(BandResource(
        source: sourceName,
        sourceId: rid,
        title: _clean(title),
        category: category,
        deviceModel: null,
        author: _clean(author),
        coverUrl: cover,
        detailUrl: '${AppConfig.bandbbsBase}/resources/$rid/',
        updatedAt: updatedAt ?? DateTime.now(),
        description: _clean(desc),
      ));
    }

    // ===== 兼容旧模板 li.block-row（无 structItem 时的兜底） =====
    if (result.isEmpty) {
      result.addAll(_parseBlockRow(doc));
    }
    return result;
  }

  /// 旧模板 `li.block-row` 解析（备用）
  List<BandResource> _parseBlockRow(dom.Document doc) {
    final result = <BandResource>[];
    for (final li in doc.querySelectorAll('li.block-row')) {
      final link =
          li.querySelector('div.contentRow-main a[href*="/resources/"]');
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final idMatch = RegExp(r'/resources/(\d+)/').firstMatch(href);
      if (idMatch == null) continue;
      final rid = idMatch.group(1)!;

      String category = '资源';
      final label = li.querySelector('span.label');
      if (label != null && label.text.trim().isNotEmpty) {
        category = label.text.trim();
      }
      String title = link.text
          .replaceAll(category, '')
          .replaceAll('\u00a0', ' ')
          .trim();
      if (title.isEmpty) title = link.attributes['title'] ?? '未知资源';

      String desc = '';
      final lesser = li.querySelector('div.contentRow-lesser');
      if (lesser != null) desc = lesser.text.trim();

      String author = '';
      final minorLis = li.querySelectorAll('div.contentRow-minor li');
      for (final m in minorLis) {
        final t = m.text.trim();
        if (author.isEmpty) {
          author = t;
          break;
        }
      }

      String? cover;
      final img = li.querySelector('img[src*="resource_icons"]');
      if (img != null) {
        cover = img.attributes['src'];
        if (cover!.startsWith('/')) {
          cover = '${AppConfig.bandbbsBase}$cover';
        }
      }

      result.add(BandResource(
        source: sourceName,
        sourceId: rid,
        title: _clean(title),
        category: category,
        author: _clean(author),
        coverUrl: cover,
        detailUrl: '${AppConfig.bandbbsBase}/resources/$rid/',
        updatedAt: DateTime.now(),
        description: _clean(desc),
      ));
    }
    return result;
  }

  @override
  Future<BandResource> fetchDetail(BandResource resource) async {
    final resp = await Http.getHtml(resource.detailUrl);
    return parseDetail(resp.data ?? '', resource);
  }

  /// 解析资源详情页 HTML（公开以便测试）：描述、预览图、下载链接、评分、下载量
  BandResource parseDetail(String html, BandResource base) {
    final doc = hp.parse(html);
    var desc = base.description;
    final article = doc.querySelector('article.message-body');
    if (article != null) {
      desc = article.text.trim();
    } else {
      final content = doc.querySelector('div.bbWrapper');
      if (content != null) desc = content.text.trim();
    }
    // 提取正文预览图（跳过头像/表情/图标，去重，限 9 张）
    final images = <String>[];
    final scope = article ?? doc;
    for (final img in scope.querySelectorAll('img')) {
      final src = img.attributes['src'] ?? '';
      if (src.isEmpty) continue;
      if (src.contains('/data/avatars/') ||
          src.contains('/styles/') ||
          src.contains('/data/smilies/') ||
          src.contains('emoji') ||
          src.contains('/svg/') ||
          src.contains('smilie')) {
        continue;
      }
      final full =
          src.startsWith('http') ? src : '${AppConfig.bandbbsBase}$src';
      if (!images.contains(full)) images.add(full);
      if (images.length >= 9) break;
    }
    // 提取下载链接（站内下载路径）
    String? downloadUrl;
    for (final a in doc.querySelectorAll(
        'a[href*="download"], a[href*="attachment"]')) {
      final h = a.attributes['href'] ?? '';
      if (h.isNotEmpty) {
        downloadUrl = h.startsWith('http') ? h : '${AppConfig.bandbbsBase}$h';
        break;
      }
    }
    // 评分 / 评分人数 / 下载量（游客无权限下载时也能看到统计）
    double ratingValue = 0;
    int ratingCount = 0;
    int downloads = 0;
    for (final el in doc.querySelectorAll('span.u-srOnly')) {
      final t = el.text.trim();
      final m = RegExp(r'(\d+(?:\.\d+)?)\s*星').firstMatch(t);
      if (m != null) {
        ratingValue = double.tryParse(m.group(1)!) ?? 0;
        break;
      }
    }
    for (final el in doc.querySelectorAll('span.ratingStarsRow-text')) {
      final m = RegExp(r'(\d[\d,]*)\s*个评分').firstMatch(el.text.trim());
      if (m != null) {
        ratingCount = int.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
        break;
      }
    }
    final dlEls = doc.querySelectorAll('dl.pairs');
    for (final dl in dlEls) {
      final dt = dl.querySelector('dt')?.text.trim() ?? '';
      if (dt == '下载') {
        final dd = dl.querySelector('dd')?.text.trim() ?? '';
        downloads = int.tryParse(dd.replaceAll(',', '')) ?? 0;
        break;
      }
    }
    return base.copyWith(
      description: desc,
      downloadUrl: downloadUrl,
      previewImages: images,
      ratingValue: ratingValue,
      ratingCount: ratingCount,
      downloads: downloads > 0 ? downloads : base.downloads,
    );
  }

  static String _clean(String s) {
    return s
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'");
  }
}
