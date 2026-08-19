import '../../core/models/band_resource.dart';

/// 数据源适配器抽象接口
abstract class ResourceAdapter {
  /// 数据源标识：bandbbs / github / ...
  String get sourceName;

  /// 是否可用（如米坛 API 需要 Key）
  bool get enabled;

  /// 拉取资源列表（分页）
  Future<List<BandResource>> fetchResources({
    required int page,
    String? categoryId, // 型号分类 id（见 AppConfig.categories）
    String? typeTag, // 类型标签: 表盘/小程序/...
    String? keyword, // 搜索关键词
  });

  /// 拉取资源详情（用于详情页增强：描述、下载链接）
  Future<BandResource> fetchDetail(BandResource resource);
}
