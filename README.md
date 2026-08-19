# 米环资源大全 (BandBuddy App)

聚合米坛社区(BandBBS)等来源的小米手环第三方资源（表盘 / 小程序 / 固件 / 工具）的手机应用。

> 当前版本：**v1.1.1**

## 功能

- **资源聚合浏览**：发现页按手环型号（手环4~10 / Pro 系列 / HyperOS）分类 + 类型标签（表盘/小程序/固件/工具/教程）筛选，支持「推荐 / 最新」排序、下拉刷新、上滑加载更多
- **搜索**：发现页右上角搜索按钮进入搜索页；关键词 + 型号 + 类型三重筛选（本地聚合检索：抓取所选型号最新列表并按关键词本地匹配；米坛站内搜索要求登录，游客不可用）
- **应用内登录**：应用内网页（WebView）打开米坛登录页，登录后软件自动抓取会话，已登录状态自动识别同步
- **App 内直接下载**：登录后米坛资源直接下载到本机（下载完成弹系统保存框，由用户选择保存位置，首次自动授权）；GitHub 直连资源同样 App 内下载
- **详情页**：预览图轮播、评分（★ 与评分人数）、下载量、作者、更新时间、资源描述
- **本地管理**：下载历史（SQLite），入口在「我的 → 下载历史」
- **多站聚合**：米坛社区（页面浏览模式）+ GitHub 开源仓库 Releases（仓库列表可自定义）

> 历史版本变更摘要：v1.0.1 修复型号分类（改用米坛 Resource Category）与页面解析；
> v1.0.2 移除 API Key（米坛未开放自助申请）；v1.0.4 移除收藏、新增详情预览图与搜索筛选；
> v1.0.6 新增排序与评分/下载量；v1.0.7~v1.1.0 应用内登录 + 直接下载 + 系统保存框。

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.47 / Dart 3.13（Material 3） |
| 状态管理 | Provider (ChangeNotifier) |
| 本地存储 | sqflite (SQLite) + shared_preferences |
| 网络 | dio（统一注入米坛会话 Cookie） |
| 页面解析 | html 包（XenForo structItem 模板） |
| 网页登录 | webview_flutter（桌面 Chrome UA 规避站点检测） |
| 保存文件 | flutter_file_dialog（系统保存框 / SAF） |

## 目录结构

```
lib/
├── main.dart / app.dart        # 入口 + 主框架（2 Tab：发现 / 我的，搜索入口在发现页右上角）
├── core/
│   ├── config.dart             # 站点配置、型号分类映射（Resource Category ID）
│   ├── models/band_resource.dart  # 统一资源模型（含评分/下载量/预览图）
│   └── utils/http.dart         # dio 全局实例 + 会话 Cookie 注入
├── data/
│   ├── adapters/               # 数据源适配器（可扩展）
│   │   ├── base_adapter.dart   # 适配器接口
│   │   ├── bandbbs_html_adapter.dart # 米坛页面解析（列表/详情/搜索/评分）
│   │   └── github_adapter.dart # GitHub 开源仓库 Releases
│   └── local_db.dart           # SQLite（下载历史）
├── providers/                  # 状态管理（资源流/会话/下载/设置）
│   └── bandbbs_session_provider.dart # 米坛会话（登录/抓取 Cookie/退出）
├── pages/                      # 发现/我的 + 搜索页/登录页/下载历史/详情页
└── widgets/                    # 资源卡片、分类/类型 chips
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

## 登录与下载说明

1. **登录**：我的 → 登录米坛账号 → 应用内网页登录（密码只交给米坛官方页面）→ 点「已完成登录」由软件抓取会话；若本机已登录会自动识别同步
2. **下载**：资源详情 → 下载资源 → 进度条完成后弹出系统保存框 → 自行选择保存位置 → 记录到下载历史
3. 付费 / 权限受限资源在未授权时下载会提示失败

## 接入新数据源

实现 `ResourceAdapter` 接口（`fetchResources` / `fetchDetail`），
在 `ResourceProvider._buildAdapters()` 注册即可，UI 无需改动。

## 合规

数据来自米坛社区公开页面（登录态仅保存于本机，用于应用内浏览与下载）；
资源版权归原作者，应用仅聚合展示与下载跳转，不缓存/分发资源本体；
请合理控制请求频率。详见 `docs/02-使用说明.md`。
