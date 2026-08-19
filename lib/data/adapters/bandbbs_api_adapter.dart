import 'package:dio/dio.dart';
import '../../core/config.dart';
import '../../core/models/band_resource.dart';
import '../../core/utils/http.dart';
import 'base_adapter.dart';

/// 米坛社区 (BandBBS) XenForo 官方 API 适配器
/// 需要有效的 API Key（设置页配置），无 Key 时抛异常提示用户
class BandBbsApiAdapter implements ResourceAdapter {
  final String apiKey;

  BandBbsApiAdapter({required this.apiKey}) {
    Http.setApiKey(apiKey);
  }

  @override
  String get sourceName => 'bandbbs';

  @override
  bool get enabled => apiKey.isNotEmpty;

  /// 校验 Key 是否有效（用于设置页）
  Future<bool> validateKey() async {
    try {
      final resp = await Http.dio.get('/users/me');
      return resp.statusCode == 200 && resp.data is Map;
    } catch (_) {
      return false;
    }
  }

  /// 获取当前登录用户信息（Key 有效时）
  Future<Map<String, dynamic>?> currentUser() async {
    try {
      final resp = await Http.dio.get('/users/me');
      final data = resp.data;
      if (data is Map && data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BandResource>> fetchResources({
    required int page,
    String? categoryId,
    String? typeTag,
    String? keyword,
  }) async {
    if (!enabled) {
      throw Exception('未配置米坛 API Key，请到「我的 → 米坛 API Key」配置');
    }
    final query = <String, dynamic>{
      'page': page,
      'order': 'last_update',
    };
    if (keyword != null && keyword.isNotEmpty) {
      query['q'] = keyword;
    }
    // 型号分类 → 米坛 Resource Category ID
    final cat = AppConfig.categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => AppConfig.categories.first,
    );
    if (cat.bandbbsCategoryId != null) {
      query['category_id'] = cat.bandbbsCategoryId;
    }
    try {
      final resp = await Http.dio.get('/resources', queryParameters: query);
      final data = resp.data;
      if (data is! Map || data['resources'] is! List) {
        return const [];
      }
      final list = data['resources'] as List;
      return list.map((e) => _fromApi(e)).whereType<BandResource>().toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('API Key 无效或权限不足，请检查设置');
      }
      rethrow;
    }
  }

  @override
  Future<BandResource> fetchDetail(BandResource resource) async {
    try {
      final resp = await Http.dio.get('/resources/${resource.sourceId}');
      final data = resp.data;
      if (data is Map && data['resource'] is Map) {
        final detail = _fromApi(data['resource'] as Map);
        return detail ?? resource;
      }
      return resource;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return resource;
      rethrow;
    }
  }

  /// 解析 XenForo Resource Manager 资源条目（容错处理字段缺失）
  BandResource? _fromApi(dynamic raw) {
    if (raw is! Map) return null;
    final int? rid = (raw['resource_id'] as num?)?.toInt();
    if (rid == null) return null;
    final String title = raw['title']?.toString() ?? '未知资源';
    final String author = raw['username']?.toString() ?? '未知作者';
    final String desc = raw['description']?.toString() ?? '';
    final String? version = raw['version']?.toString();
    final String? prefix = raw['prefix_name']?.toString();

    String? icon = raw['resource_icon_url']?.toString();
    if (icon != null && icon.startsWith('/')) {
      icon = '${AppConfig.bandbbsBase}$icon';
    }
    final String? downloadPath = raw['download_url']?.toString();
    String? downloadUrl;
    if (downloadPath != null && downloadPath.isNotEmpty) {
      downloadUrl = downloadPath.startsWith('http')
          ? downloadPath
          : '${AppConfig.bandbbsBase}$downloadPath';
    }
    final num? ratingRaw = raw['rating_avg'];
    final int rating =
        (ratingRaw == null ? 0 : ratingRaw.round().clamp(0, 5));
    final int downloads = (raw['download_count'] as num?)?.toInt() ?? 0;
    final int views = (raw['view_count'] as num?)?.toInt() ?? 0;
    final int ts = (raw['last_update'] as num?)?.toInt() ??
        (raw['resource_date'] as num?)?.toInt() ??
        0;
    final DateTime updatedAt = ts > 0
        ? DateTime.fromMillisecondsSinceEpoch(ts * 1000)
        : DateTime.now();

    final tags = raw['tags'] is List ? (raw['tags'] as List) : const [];
    String category = prefix ?? '资源';
    if (tags.isNotEmpty) {
      for (final t in tags) {
        final s = t.toString();
        if (s.contains('表盘') || s.contains('小程序') || s.contains('固件')) {
          category = s;
          break;
        }
      }
    }

    return BandResource(
      source: sourceName,
      sourceId: rid.toString(),
      title: title,
      category: category,
      deviceModel: prefix,
      author: author,
      version: version,
      coverUrl: icon,
      detailUrl: '${AppConfig.bandbbsBase}/resources/$rid/',
      downloadUrl: downloadUrl,
      rating: rating,
      downloads: downloads,
      views: views,
      updatedAt: updatedAt,
      description: desc,
    );
  }
}
