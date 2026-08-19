# 米环资源大全 (BandBuddy App)

聚合米坛社区(BandBBS)等来源的小米手环第三方资源（表盘 / 小程序 / 固件 / 工具）的手机应用。

## 功能

- **资源聚合浏览**：按手环型号（手环5~10 / Pro 系列）分类 + 类型标签筛选
- **搜索**：跨源关键词搜索（米坛官方 API 服务端搜索 + 客户端兜底）
- **下载**：GitHub 直连资源 App 内下载；米坛资源跳转站内下载（合规）
- **多站聚合**：米坛社区（API / 页面兜底）+ GitHub 开源仓库 Releases
- **本地管理**：收藏（跨源统一）、下载历史（SQLite）

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.47 / Dart 3.13（Material 3） |
| 状态管理 | Provider (ChangeNotifier) |
| 本地存储 | sqflite (SQLite) + shared_preferences |
| 网络 | dio + 拦截器（XF-Api-Key 注入） |
| HTML 兜底解析 | html 包（XenForo 页面） |

## 目录结构

```
lib/
├── main.dart / app.dart        # 入口 + 主框架（4 Tab）
├── core/
│   ├── config.dart             # 站点配置、型号分类映射
│   ├── models/band_resource.dart  # 统一资源模型
│   └── utils/http.dart         # dio 全局实例 + API Key 拦截器
├── data/
│   ├── adapters/               # 数据源适配器（可扩展）
│   │   ├── base_adapter.dart   # 适配器接口
│   │   ├── bandbbs_api_adapter.dart  # 米坛 XenForo 官方 API
│   │   ├── bandbbs_html_adapter.dart # 米坛页面兜底解析
│   │   └── github_adapter.dart # GitHub 开源仓库 Releases
│   └── local_db.dart           # SQLite（收藏/下载历史）
├── providers/                  # 状态管理（资源流/收藏/下载/设置）
├── pages/                      # 发现/搜索/收藏/我的 + 详情页
└── widgets/                    # 资源卡片、分类 chips
```

## 运行

```bash
# 环境变量（国内镜像 + 缓存外置，按需调整）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter pub get
flutter run                    # 连接 Android 设备
flutter build apk --release    # 打包
```

## 接入新数据源

实现 `ResourceAdapter` 接口（`fetchResources` / `fetchDetail`），
在 `ResourceProvider._buildAdapters()` 注册即可，UI 无需改动。

## 合规

数据来自米坛社区官方 API 及公开页面；资源版权归原作者；应用仅聚合展示与跳转。
详见 `docs/02-使用说明.md`。
