/// 全局配置：站点常量、分类映射、数据源开关
class AppConfig {
  AppConfig._();

  // ===== 米坛社区 (BandBBS) =====
  static const String bandbbsBase = 'https://www.bandbbs.cn';
  static const String bandbbsApiBase = 'https://www.bandbbs.cn/api';
  static const String xfApiKeyHeader = 'XF-Api-Key';

  // ===== GitHub 聚合源（开源表盘仓库，可配置） =====
  static const String githubApiBase = 'https://api.github.com';
  // 默认聚合的开源表盘仓库（owner/repo，可配置）
  static const List<String> defaultGitHubRepos = [
    'novvember/amazfit-watchfaces', // 圆表 ZeppOS 开源表盘
    'GreatApo/GreatFit', // Amazfit 表盘源合集
  ];

  // ===== 米坛资源分类 → 型号映射（category_id 为米坛 Resource Category ID） =====
  // 2026-08-19 实测自米坛 /resources/categories/ 分类树：
  // 小米手环(19) > 手环2(27) 手环3(21) 手环4(20) 手环5(70) 手环6(75)
  // 手环7(90) 手环7Pro(93) 手环8(91) 手环8Pro(94) 手环9(95) 手环9Pro(100)
  // 手环10(103) 手环10Pro(108) HyperOS(99)
  static const List<ResourceCategory> categories = [
    ResourceCategory('all', '全部', null, null),
    ResourceCategory('band10pro', '手环10 Pro', 108, null),
    ResourceCategory('band10', '手环10', 103, null),
    ResourceCategory('band9pro', '手环9 Pro', 100, null),
    ResourceCategory('band9', '手环9', 95, null),
    ResourceCategory('band8pro', '手环8 Pro', 94, null),
    ResourceCategory('band8', '手环8', 91, null),
    ResourceCategory('band7pro', '手环7 Pro', 93, null),
    ResourceCategory('band7', '手环7', 90, null),
    ResourceCategory('band6', '手环6', 75, null),
    ResourceCategory('band5', '手环5', 70, null),
    ResourceCategory('band4', '手环4', 20, null),
    ResourceCategory('hyperos', '小米手表(HyperOS)', 99, null),
    ResourceCategory('github', 'GitHub 开源', null, 'github'),
  ];

  /// 资源类型标签（用于筛选）
  static const List<String> typeTags = ['全部', '表盘', '小程序', '固件', '工具', '教程'];
}

class ResourceCategory {
  final String id;
  final String name;
  final int? bandbbsCategoryId; // 米坛 Resource Category ID（null 表示不适用）
  final String? sourceKey; // 数据源标识（github 等）
  const ResourceCategory(this.id, this.name, this.bandbbsCategoryId, this.sourceKey);
}
