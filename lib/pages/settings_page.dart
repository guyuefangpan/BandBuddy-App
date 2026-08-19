import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/services/update_service.dart';
import '../providers/bandbbs_session_provider.dart';
import '../providers/settings_provider.dart';
import 'authkey_page.dart';
import 'bandbbs_login_page.dart';
import 'download_history_page.dart';

/// Tab4 我的：米坛登录（应用内账号登录）/ 数据源管理 / 关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final session = context.watch<BandBbsSessionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          // ===== 米坛社区接入（应用内登录，直接下载） =====
          _sectionTitle('米坛社区', context),
          ListTile(
            leading: Icon(
              session.isLoggedIn ? Icons.verified_user : Icons.login,
              color: session.isLoggedIn ? Colors.green : null,
            ),
            title: Text(session.isLoggedIn ? '已登录米坛' : '登录米坛账号'),
            subtitle: Text(session.statusText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (session.isLoggedIn) {
                await _confirmSignOut(context, session);
              } else {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const BandBbsLoginPage(),
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('App 内直接下载'),
            subtitle: const Text(
                '登录后，米坛资源可直接下载到本机（不再跳转浏览器）；付费/权限受限资源会提示用浏览器打开'),
            isThreeLine: true,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.web),
            title: const Text('页面浏览模式'),
            subtitle: const Text('解析米坛页面浏览资源（默认开启）'),
            value: s.useHtmlFallback,
            onChanged: s.setUseHtmlFallback,
          ),

          const Divider(),
          // ===== 数据源 =====
          _sectionTitle('数据源', context),
          SwitchListTile(
            secondary: const Icon(Icons.watch),
            title: const Text('米坛社区'),
            value: s.useBandBbs,
            onChanged: s.setUseBandBbs,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.code),
            title: const Text('GitHub 开源仓库'),
            subtitle: const Text('聚合开源表盘/工具仓库 Releases'),
            value: s.useGitHub,
            onChanged: s.setUseGitHub,
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('GitHub 仓库列表'),
            subtitle: Text(
              s.githubRepos.join('\n'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _editGithubRepos(context),
          ),

          const Divider(),
          // ===== 下载历史 =====
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('下载历史'),
            subtitle: const Text('查看 App 内直连下载与站内打开的记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const DownloadHistoryPage(),
            )),
          ),

          const Divider(),
          // ===== 关于 =====
          _sectionTitle('关于', context),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('米环资源大全 v${AppConfig.appVersion}'),
            subtitle: const Text('聚合米坛社区(BandBBS)等来源的手环第三方资源'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('作者'),
            subtitle: const Text('洪淑森'),
            onTap: () => _copyText(context, '洪淑森', '作者信息已复制'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('作者 QQ'),
            subtitle: const Text('3675711（点击复制）'),
            onTap: () => _copyText(context, '3675711', 'QQ 号已复制：3675711'),
          ),
          const Divider(),
          // ===== 偏好设置 =====
          _sectionTitle('偏好设置', context),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('字体大小'),
            trailing: SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.9, label: Text('小')),
                ButtonSegment(value: 1.0, label: Text('标准')),
                ButtonSegment(value: 1.15, label: Text('大')),
              ],
              selected: {s.fontScale},
              onSelectionChanged: (v) => s.setFontScale(v.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('手环 AuthKey'),
            subtitle: const Text('获取手环蓝牙密钥（蓝牙直装的第一步）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AuthKeyPage(),
            )),
          ),

          const Divider(),
          // ===== 更新 =====
          _sectionTitle('更新', context),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('检查更新'),
            subtitle: Text(
              s.updateRepo.isEmpty
                  ? '未配置更新源（需 GitHub 仓库，见下）'
                  : '更新源：${s.updateRepo}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _checkUpdate(context, s),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('更新源仓库'),
            subtitle: Text(
                'GitHub 仓库（owner/repo），发布 APK Releases 后应用启动将自动提示更新',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
            trailing: const Icon(Icons.edit),
            onTap: () => _editUpdateRepo(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('合规说明'),
            subtitle: const Text(
                '数据来自米坛社区公开页面，资源版权归原作者；本应用仅聚合展示与跳转，登录在浏览器中完成，本应用不保存任何账号密码。请合理控制请求频率。'),
            isThreeLine: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _copyText(
      BuildContext context, String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(toast)));
    }
  }

  Future<void> _editUpdateRepo(BuildContext context) async {
    final s = context.read<SettingsProvider>();
    final ctrl = TextEditingController(text: s.updateRepo);
    final newVal = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更新源仓库'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '格式：owner/repo，如 hongseng/bandbuddy-app\n发布 APK 到 GitHub Releases 即可',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('保存')),
        ],
      ),
    );
    if (newVal != null) {
      await s.setUpdateRepo(newVal);
    }
  }

  Future<void> _checkUpdate(BuildContext context, SettingsProvider s) async {
    if (s.updateRepo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在上方「更新源仓库」填写 GitHub 仓库')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在检查更新…')),
    );
    final info =
        await UpdateService.fetchLatest(repo: s.updateRepo);
    if (!context.mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查失败：无法访问更新源，请稍后重试')),
      );
      return;
    }
    if (!UpdateService.isNewer(info.latestVersion, AppConfig.appVersion)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前已是最新版本 v${AppConfig.appVersion}')),
      );
      return;
    }
    _showManualUpdateDialog(context, info);
  }

  void _showManualUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 ${info.latestVersion}'),
        content: Text(
            info.releaseNotes.isEmpty
                ? '当前版本：v${AppConfig.appVersion}'
                : '更新内容：\n${info.releaseNotes}',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(info.releasesUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('前往 Releases'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请从发现页/下次启动时使用「应用内下载」完成更新')),
              );
            },
            child: const Text('应用内下载'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, BandBbsSessionProvider session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出米坛登录？'),
        content: const Text('退出后将无法在应用内直接下载，本机保存的会话将被清除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) {
      await session.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已退出登录')));
      }
    }
  }

  Widget _sectionTitle(String t, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(t,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  Future<void> _editGithubRepos(BuildContext context) async {
    final s = context.read<SettingsProvider>();
    final ctrl = TextEditingController(text: s.githubRepos.join(','));
    final newVal = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub 仓库列表'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '每行一个，格式：owner/repo\n如：melon-block/amazfit-watchfaces',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('保存')),
        ],
      ),
    );
    if (newVal != null) {
      await s.setGithubRepos(newVal);
    }
  }
}
