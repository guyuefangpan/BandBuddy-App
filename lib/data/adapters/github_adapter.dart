import 'package:dio/dio.dart';
import '../../core/config.dart';
import '../../core/models/band_resource.dart';
import '../../core/utils/http.dart';
import 'base_adapter.dart';

/// GitHub 开源表盘仓库聚合源
/// 从用户配置的开源仓库列表拉取 Releases 作为资源
class GitHubAdapter implements ResourceAdapter {
  final List<String> repos; // owner/repo 列表
  final String? token; // 可选 GitHub Token（提高限速）

  GitHubAdapter({List<String>? repos, this.token})
      : repos = repos ?? AppConfig.defaultGitHubRepos;

  @override
  String get sourceName => 'github';

  @override
  bool get enabled => repos.isNotEmpty;

  @override
  Future<List<BandResource>> fetchResources({
    required int page,
    String? categoryId,
    String? typeTag,
    String? keyword,
  }) async {
    // 按仓库轮询最近 releases（每仓库取第一页，合并）
    final all = <BandResource>[];
    for (final repo in repos) {
      try {
        final resp = await _gh('/repos/$repo/releases', {
          'per_page': '15',
          if (keyword != null && keyword.isNotEmpty) 'q': keyword,
        });
        if (resp.data is List) {
          for (final r in resp.data as List) {
            all.add(_fromRelease(repo, r));
          }
        }
      } catch (_) {
        // 单个仓库失败不影响其他
      }
    }
    // 简单分页：第一页 15/repo，合并后截取
    final start = (page - 1) * 20;
    return all.skip(start).take(20).toList();
  }

  Future<Response> _gh(String path, Map<String, dynamic> query) {
    // 使用完整 URL 覆盖全局 baseUrl（dio 对绝对 URL 直接使用）
    return Http.dio.get(
      '${AppConfig.githubApiBase}$path',
      options: Options(headers: {
        'User-Agent': 'BandBuddyApp/1.0',
        'Accept': 'application/vnd.github+json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      }),
      queryParameters: query,
    );
  }

  BandResource _fromRelease(String repo, dynamic raw) {
    final r = raw as Map;
    final tag = r['tag_name']?.toString() ?? '';
    final name = r['name']?.toString() ?? '';
    final title = name.isNotEmpty ? name : tag;
    final published = DateTime.tryParse(
            r['published_at']?.toString() ?? '') ??
        DateTime.now();

    // 找到第一个可下载资产
    String? downloadUrl;
    int? size;
    if (r['assets'] is List && (r['assets'] as List).isNotEmpty) {
      final assets = r['assets'] as List;
      if (assets.first is Map) {
        final a = assets.first as Map;
        downloadUrl = a['browser_download_url']?.toString();
        size = (a['size'] as num?)?.toInt();
      }
    }

    return BandResource(
      source: sourceName,
      sourceId: repo,
      title: title,
      category: '表盘/工具',
      deviceModel: null,
      author: repo.split('/').first,
      version: tag,
      coverUrl: null,
      detailUrl: 'https://github.com/$repo/releases/tag/${Uri.encodeComponent(tag)}',
      downloadUrl: downloadUrl,
      updatedAt: published,
      description: '开源仓库 $repo 的发布版本${size != null ? '（${(size / 1024 / 1024).toStringAsFixed(1)}MB）' : ''}\n${r['body']?.toString() ?? ''}',
    );
  }

  @override
  Future<BandResource> fetchDetail(BandResource resource) async {
    return resource; // release 信息已包含详情
  }
}
