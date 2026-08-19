# OronBox 米坛接入方式调研报告

> 调研对象：https://github.com/zxor-org/OronBox（VelaOS/ZeppOS 穿戴管理工具，作者：OrPudding & zxxhcj，米坛社区创作者）
> 调研日期：2026-08-19 ｜ 源码版本：2026-08-09 提交

## 一、结论速览

| 对比项 | OronBox 的做法 | 我们的 App（v1.0.1） |
|---|---|---|
| 认证方式 | **OAuth 授权码登录**（用户点一下授权） | XF-Api-Key（可选）或 HTML 兜底（零配置） |
| 是否需要用户填 Key | **不需要** | 不需要（兜底模式零配置可用） |
| Token 获取 | 自建服务器做 OAuth 中继 | — |
| 请求认证头 | `Authorization: Bearer <token>` | `XF-Api-Key` |
| 分类 | `GET /api/resource-categories/flattened` 动态拉取 | HTML 兜底用实测分类 ID 表 |
| 搜索 | `GET /api/resource-search/?keywords=` | HTML 搜索 + 客户端过滤 |
| 付费资源 | 解密接口（DRM） | 不支持（跳站内） |

## 二、OronBox 的接入架构

```
┌────────────┐   OAuth 授权码流    ┌─────────────────┐
│ OronBox App│───打开浏览器授权────▶│ OronBox 服务器    │
│ (Flutter)  │◀──ticket 回调────────│ (自建 OAuth 中继) │
└────────────┘                      └────────┬────────┘
      │                                     │ 持有 refresh_token
      │ Bearer access_token                 │（米坛 OAuth 需 client_secret，
      ▼                                     ▼  只能放服务端）
┌──────────────────────────────────────────────┐
│ 米坛 XenForo API（www.bandbbs.cn/api）        │
│ GET /api/resources/  ?page=&prefix_id=&type=  │
│ GET /api/resources/{id}                       │
│ GET /api/resource-search/?keywords=&categories[]= │
│ GET /api/resource-categories/{id}/resources   │
│ GET /api/resource-categories/flattened        │
│ GET /api/resource-check/{id}                  │
└──────────────────────────────────────────────┘
```

关键点：
1. **OAuth 客户端凭证不能放客户端** → OronBox 部署了自己的服务器（`oronboxServerBaseUrl`），走标准授权码流：
   - App 打开 `{server}/oauth2/bandbbs/start?app_id=oronbox&return_uri=oronbox://oauth/bandbbs`
   - 用户在浏览器登录米坛并授权
   - 回调 `oronbox://oauth/bandbbs?ticket=xxx` → App 拿 ticket 换 token
   - access_token 给客户端（短时效），refresh_token 留在服务器
2. 客户端请求头：`Authorization: Bearer <accessToken>`
3. 会话失效处理：401 → `expireSession()` 清凭证并广播（onSessionExpired）

## 三、对我们的启示

1. **"免填 API"的正确实现是 OAuth 登录**，但需要自建服务器（米坛 OAuth client_secret 不能下发客户端）。自用场景没有服务器，所以我们的 App 走**HTML 兜底零配置**路线（用户无需任何操作即可浏览/搜索/收藏），API Key 作为可选增强——这是务实的选择。
2. **米坛 API 端点已确认支持**：`/api/resources/`（分页/prefix_id/type/order）、`/api/resource-search/`（keywords/categories[]）、`/api/resource-categories/flattened`（动态分类树）。若未来有服务器，可平滑升级到 API 模式。
3. **分类的正确语义**：米坛资源分类是 **Resource Category 树**（`/resources/categories/{id}/`，型号即分类），`prefix_id` 只是"表盘/小程序"这类类型标签。我们 v1.0.1 已修正为真实分类 ID。

## 四、我们 v1.0.1 修复内容（基于本调研）

- 型号分类 → 米坛 Resource Category ID（19/91/90/103…，2026-08-19 实测）
- HTML 解析适配米坛新版 `structItem` 模板（此前只匹配旧 `li.block-row`，导致只能看到推荐区块）
- 分页走 `/resources/categories/{id}/?page=N`，上滑加载更多恢复
