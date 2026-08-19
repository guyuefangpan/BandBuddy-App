import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/config.dart';
import 'core/services/update_service.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'providers/settings_provider.dart';

/// App 主框架：底部 2 Tab 导航（搜索在发现页右上角）+ 启动自动检查更新
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _updateChecked = false;
  Timer? _updateTimer;

  static const _pages = [
    HomePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 启动后延迟自动检查更新（不阻塞首屏）
    _updateTimer = Timer(const Duration(seconds: 2), _autoCheckUpdate);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  /// 自动检查更新：有新版则弹窗，提供「应用内下载 / 前往 Releases」两种方式
  Future<void> _autoCheckUpdate() async {
    if (_updateChecked || !mounted) return;
    _updateChecked = true;
    final repo = context.read<SettingsProvider>().updateRepo;
    if (repo.isEmpty) return; // 未配置更新源，跳过
    final info = await UpdateService.fetchLatest(repo: repo);
    if (info == null || !mounted) return;
    if (UpdateService.isNewer(info.latestVersion, AppConfig.appVersion)) {
      _showUpdateDialog(info);
    }
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 ${info.latestVersion}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前版本：v${AppConfig.appVersion}',
                  style: const TextStyle(fontSize: 12)),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('更新内容：',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(info.releaseNotes, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openReleases(info.releasesUrl);
            },
            child: const Text('前往 Releases'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadUpdate(info);
            },
            child: const Text('应用内下载'),
          ),
        ],
      ),
    );
  }

  void _openReleases(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// 应用内下载更新（APK）：下载 → 系统保存框 → 打开安装
  Future<void> _downloadUpdate(AppUpdateInfo info) async {
    final url = info.downloadUrl;
    if (url == null || url.isEmpty) {
      _openReleases(info.releasesUrl);
      return;
    }
    // 进度对话框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('正在下载更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(minHeight: 4),
              const SizedBox(height: 10),
              Text('正在下载 ${info.latestVersion}…',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
    try {
      final tmpDir = await getTemporaryDirectory();
      final tmpPath =
          p.join(tmpDir.path, 'bandbuddy_update_${info.latestVersion}.apk');
      await HttpDownload.download(url, tmpPath);
      // 系统保存框选择安装包位置
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: tmpPath,
          fileName: '米环资源大全_${info.latestVersion}.apk',
        ),
      );
      if (mounted) Navigator.of(context).pop(); // 关闭进度框
      if (saved == null) {
        _toast('已取消保存');
        return;
      }
      _toast('已保存：$saved');
      // 打开 APK 触发系统安装（需允许"安装未知应用"）
      OpenFilex.open(saved);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _toast('下载失败：$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的'),
        ],
      ),
    );
  }
}

/// APK 下载辅助（更新用）
class HttpDownload {
  static Future<void> download(String url, String savePath) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      followRedirects: true,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36',
        'Accept': 'application/octet-stream, */*',
      },
    ));
    await dio.download(url, savePath,
        options: Options(responseType: ResponseType.bytes));
    final f = File(savePath);
    if (!f.existsSync() || f.lengthSync() < 100 * 1024) {
      throw Exception('下载失败：文件不完整');
    }
  }
}
