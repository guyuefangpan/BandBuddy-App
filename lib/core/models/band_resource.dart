/// 统一资源模型：聚合米坛(BandBBS)、GitHub 等来源的资源条目
class BandResource {
  final String source; // 来源标识: bandbbs / github
  final String sourceId; // 源内唯一 ID（米坛资源ID / GitHub repo 名）
  final String title; // 标题
  final String category; // 分类标签: 表盘/小程序/固件/工具/教程
  final String? deviceModel; // 适配型号（可空）
  final String author; // 作者
  final String? version; // 版本（可空）
  final String? coverUrl; // 封面图 URL（可空）
  final String detailUrl; // 详情页 URL
  final String? downloadUrl; // 下载 URL（可空，可能需登录）
  final int rating; // 评分 0-5
  final int downloads; // 下载量
  final int views; // 浏览量
  final DateTime updatedAt; // 更新时间
  final String description; // 描述（列表页可能为空，详情页拉取）
  final List<String> previewImages; // 详情页预览图 URL 列表
  final double ratingValue; // 评分（0-5 浮点，详情页解析）
  final int ratingCount; // 评分人数

  const BandResource({
    required this.source,
    required this.sourceId,
    required this.title,
    required this.category,
    this.deviceModel,
    required this.author,
    this.version,
    this.coverUrl,
    required this.detailUrl,
    this.downloadUrl,
    this.rating = 0,
    this.downloads = 0,
    this.views = 0,
    required this.updatedAt,
    this.description = '',
    this.previewImages = const [],
    this.ratingValue = 0,
    this.ratingCount = 0,
  });

  BandResource copyWith({
    String? description,
    String? downloadUrl,
    List<String>? previewImages,
    double? ratingValue,
    int? ratingCount,
    int? downloads,
  }) {
    return BandResource(
      source: source,
      sourceId: sourceId,
      title: title,
      category: category,
      deviceModel: deviceModel,
      author: author,
      version: version,
      coverUrl: coverUrl,
      detailUrl: detailUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      rating: rating,
      downloads: downloads ?? this.downloads,
      views: views,
      updatedAt: updatedAt,
      description: description ?? this.description,
      previewImages: previewImages ?? this.previewImages,
      ratingValue: ratingValue ?? this.ratingValue,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }

  /// 转为可存储的 Map（本地库）
  Map<String, dynamic> toMap() => {
        'source': source,
        'sourceId': sourceId,
        'title': title,
        'category': category,
        'deviceModel': deviceModel ?? '',
        'author': author,
        'version': version ?? '',
        'coverUrl': coverUrl ?? '',
        'detailUrl': detailUrl,
        'downloadUrl': downloadUrl ?? '',
        'rating': rating,
        'downloads': downloads,
        'views': views,
        'updatedAt': updatedAt.toIso8601String(),
        'description': description,
      };

  factory BandResource.fromMap(Map<String, dynamic> m) => BandResource(
        source: m['source'] as String,
        sourceId: (m['sourceId'] as dynamic).toString(),
        title: m['title'] as String,
        category: m['category'] as String,
        deviceModel: (m['deviceModel'] as String?)?.isNotEmpty == true
            ? m['deviceModel'] as String
            : null,
        author: m['author'] as String,
        version: (m['version'] as String?)?.isNotEmpty == true
            ? m['version'] as String
            : null,
        coverUrl: (m['coverUrl'] as String?)?.isNotEmpty == true
            ? m['coverUrl'] as String
            : null,
        detailUrl: m['detailUrl'] as String,
        downloadUrl: (m['downloadUrl'] as String?)?.isNotEmpty == true
            ? m['downloadUrl'] as String
            : null,
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        downloads: (m['downloads'] as num?)?.toInt() ?? 0,
        views: (m['views'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        description: m['description'] as String? ?? '',
      );

  /// 唯一键（用于收藏去重）
  String get uniqueKey => '$source:$sourceId';
}
