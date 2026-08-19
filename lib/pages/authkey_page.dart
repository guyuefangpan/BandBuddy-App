import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// 手环 AuthKey 获取页（蓝牙直装第一期）
/// 原理参考开源项目 Suiteki（水滴）：
/// 从小米运动健康 / 小米穿戴的日志文件中正则提取设备的 authKey / MAC / 型号
class AuthKeyPage extends StatefulWidget {
  const AuthKeyPage({super.key});

  @override
  State<AuthKeyPage> createState() => _AuthKeyPageState();
}

class _AuthKeyPageState extends State<AuthKeyPage> {
  bool _scanning = false;
  String? _result;
  String? _error;

  // 日志路径（小米运动健康 / 小米穿戴）
  static const _logPaths = [
    '/storage/emulated/0/Android/data/com.mi.health/files/log/XiaomiFit.device.log',
    '/storage/emulated/0/Android/data/com.xiaomi.wearable/files/log/Wearable.log',
  ];

  Future<void> _grantPermission() async {
    if (await Permission.manageExternalStorage.isGranted) return;
    final status = await Permission.manageExternalStorage.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要授予"所有文件访问"权限才能读取日志')),
      );
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _result = null;
      _error = null;
    });
    final settings = context.read<SettingsProvider>();
    try {
      if (!await Permission.manageExternalStorage.isGranted) {
        await _grantPermission();
      }
      String? found;
      final buf = StringBuffer();
      for (final path in _logPaths) {
        final f = File(path);
        if (!await f.exists()) continue;
        final content = await f.readAsString();
        final m = RegExp(r"authKey=([0-9a-fA-F]{32})").firstMatch(content);
        if (m != null) {
          final mac = RegExp(r'mac=([0-9A-F]{2}(?::[0-9A-F]{2}){5})')
              .firstMatch(content)
              ?.group(1);
          final model = RegExp(r"model='([^']+)'")
              .firstMatch(content)
              ?.group(1);
          found = m.group(1)!.toLowerCase();
          buf.writeln('✅ 已找到 AuthKey');
          buf.writeln('AuthKey: $found');
          if (mac != null) buf.writeln('MAC: $mac');
          if (model != null) buf.writeln('型号: $model');
          buf.writeln('来源: $path');
          break;
        }
      }
      if (found == null) {
        _error = '未找到 AuthKey。\n'
            '请先确认：\n'
            '1. 手机已安装"小米运动健康"或"小米穿戴"并登录绑定手环\n'
            '2. 已授予本应用"所有文件访问"权限\n'
            '3. 打开过一次官方 App（让日志生成）\n'
            '4. 若官方 App 刚更新过，请先打开一次再重试';
      } else {
        _result = buf.toString().trim();
        await settings.saveBandAuthKey(found);
      }
    } catch (e) {
      _error = '读取失败：$e';
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saved = context.watch<SettingsProvider>().bandAuthKey;
    return Scaffold(
      appBar: AppBar(title: const Text('手环 AuthKey')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.key, size: 20, color: scheme.primary),
                    const SizedBox(width: 6),
                    const Text('什么是 AuthKey？',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'AuthKey 是手环的蓝牙授权密钥（32 位十六进制），'
                    '用于后续蓝牙直装表盘/小程序（二期功能）。'
                    '获取原理参考开源项目 Suiteki（水滴）：从官方 App 的日志文件中提取。',
                    style: TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.document_scanner_outlined),
            label: Text(_scanning ? '正在扫描日志…' : '扫描日志获取 AuthKey'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _grantPermission,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('授权"所有文件访问"权限'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: scheme.onErrorContainer)),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_result!,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, fontFamily: 'monospace')),
                  const SizedBox(height: 10),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: () => _copy(_result!.replaceAll(RegExp(r'\s+'), '\n')),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('复制'),
                    ),
                    const SizedBox(width: 8),
                    Text('已自动保存到本机',
                        style: TextStyle(
                            fontSize: 12, color: scheme.outline)),
                  ]),
                ],
              ),
            ),
          ],
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('本机已保存的 AuthKey',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            SelectableText(saved,
                style: const TextStyle(
                    fontSize: 13, fontFamily: 'monospace')),
          ],
          const SizedBox(height: 16),
          Text(
            '说明：此功能仅读取本机官方 App 日志提取密钥，密钥只保存在本机，不上传。'
            '新用户请先打开官方 App 并绑定手环后再扫描。',
            style: TextStyle(fontSize: 11.5, color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
