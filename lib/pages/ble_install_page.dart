import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../device/zeppos_ble.dart';
import '../providers/settings_provider.dart';

/// 蓝牙直装：连接手环 → 认证 → 推送表盘/小程序
class BleInstallPage extends StatefulWidget {
  const BleInstallPage({super.key});

  @override
  State<BleInstallPage> createState() => _BleInstallPageState();
}

class _BleInstallPageState extends State<BleInstallPage> {
  bool _scanning = false;
  List<BandDeviceInfo> _devices = [];
  String? _deviceError;
  BandDeviceInfo? _selected;
  bool _connecting = false;
  bool _authenticated = false;
  ZepposBleTransport? _transport;
  ZepposInstaller? _installer;
  String? _filePath;
  String? _fileName;
  bool _installing = false;
  double _progress = 0;
  String? _status;
  String? _installError;

  @override
  void dispose() {
    _transport?.disconnect();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _devices = [];
      _deviceError = null;
    });
    try {
      final devices = await scanBandDevices();
      if (!mounted) return;
      setState(() => _devices = devices);
      if (devices.isEmpty) {
        _deviceError = '未发现手环设备。请开启蓝牙并让手环靠近手机（保持屏幕点亮）。';
      }
    } catch (e) {
      if (mounted) setState(() => _deviceError = '扫描失败：$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(BandDeviceInfo device) async {
    setState(() {
      _selected = device;
      _connecting = true;
      _authenticated = false;
      _status = '正在连接 ${device.name}…';
      _installError = null;
    });
    try {
      final authKey = context.read<SettingsProvider>().bandAuthKey;
      if (authKey.isEmpty) {
        throw StateError('请先在「手环 AuthKey」页面获取并保存 AuthKey');
      }
      final transport = ZepposBleTransport();
      await transport.connect(device);
      _transport = transport;
      _installer = ZepposInstaller(transport);
      setState(() => _status = '正在认证…');
      await _installer!.authenticate(authKey);
      if (!mounted) return;
      setState(() {
        _authenticated = true;
        _status = '认证成功，可以安装资源';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installError = e.toString().replaceFirst('StateError: ', '');
        _status = null;
        _selected = null;
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: '表盘/小程序文件',
      extensions: ['bin', 'zab'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
      _installError = null;
      _progress = 0;
    });
  }

  Future<void> _install() async {
    final transport = _transport;
    final installer = _installer;
    final filePath = _filePath;
    final fileName = _fileName;
    if (transport == null || installer == null || !_authenticated) {
      setState(() => _installError = '请先连接并认证手环');
      return;
    }
    if (filePath == null || fileName == null) {
      setState(() => _installError = '请先选择表盘/小程序文件（.bin 或 .zab）');
      return;
    }
    setState(() {
      _installing = true;
      _progress = 0;
      _installError = null;
    });
    try {
      final package = buildInstallPackage(filePath, fileName);
      await installer.installPackage(
        package,
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
      );
      if (!mounted) return;
      setState(() => _status = '安装完成，请在手环上查看');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('安装完成！')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _installError = e.toString().replaceFirst('StateError: ', ''));
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saved = context.watch<SettingsProvider>().bandAuthKey;
    return Scaffold(
      appBar: AppBar(title: const Text('蓝牙直装')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.surfaceContainerLow,
            child: ListTile(
              leading: Icon(Icons.key, color: saved.isEmpty ? scheme.outline : Colors.green.shade600),
              title: const Text('AuthKey', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                saved.isEmpty
                    ? '未获取（先去「手环 AuthKey」页面获取）'
                    : saved,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: saved.isEmpty ? scheme.outline : null,
                ),
              ),
              trailing: saved.isEmpty
                  ? null
                  : const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          // 扫描/选择设备
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_scanning ? '扫描中…' : '扫描附近手环'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _selected == null ? null : () async {
                await _transport?.disconnect();
                setState(() {
                  _selected = null;
                  _authenticated = false;
                  _installer = null;
                  _transport = null;
                });
              },
              icon: const Icon(Icons.bluetooth_disabled),
              tooltip: '断开',
            ),
          ]),
          if (_deviceError != null) ...[
            const SizedBox(height: 8),
            Text(_deviceError!, style: TextStyle(fontSize: 12, color: scheme.error)),
          ],
          if (_devices.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final d in _devices)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.watch, size: 22),
                  title: Text(d.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    d.kind == BandDeviceKind.xiaomi ? '小米手环' : 'ZeppOS 设备',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: _selected?.id == d.id
                      ? Icon(Icons.check_circle, color: Colors.green.shade600)
                      : null,
                  onTap: _connecting || _installing ? null : () => _connect(d),
                ),
              ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_status!, style: const TextStyle(fontSize: 13))),
            ]),
          ],
          if (_authenticated) ...[
            const Divider(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_fileName ?? '选择表盘/小程序文件'),
                ),
              ),
            ]),
            if (_fileName != null) ...[
              const SizedBox(height: 6),
              Text('已选择：$_fileName（.bin 表盘 / .zab 应用）',
                  style: TextStyle(fontSize: 11.5, color: scheme.outline)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _installing ? null : _install,
              icon: const Icon(Icons.bluetooth_connected),
              label: Text(_installing
                  ? '安装中 ${(_progress * 100).toStringAsFixed(0)}%'
                  : '安装到手环'),
            ),
            if (_installing) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _progress, minHeight: 6),
              const SizedBox(height: 4),
              Text('${(_progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: scheme.outline)),
            ],
          ],
          if (_installError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_installError!,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onErrorContainer, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '说明：\n'
            '1. 需先获取并保存 AuthKey（日志扫描 / Zepp Life 登录 / 小米运动健康登录）\n'
            '2. 支持小米手环 4~10、Amazfit GTR/GTS 等 ZeppOS 设备\n'
            '3. 推送表盘（.bin / .zab）或小程序（.zab）到手环\n'
            '4. 连接前请在手环上开启蓝牙可发现（保持手表显示主界面）\n'
            '5. 部分设备需要先在官方 App 中与手机配对',
            style: TextStyle(fontSize: 11.5, color: scheme.outline, height: 1.6),
          ),
        ],
      ),
    );
  }
}
