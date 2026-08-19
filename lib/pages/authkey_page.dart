import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/huami_auth_service.dart';

/// 手环 AuthKey 获取页（三种方式）
/// 1. 日志扫描：读取小米运动健康/小米穿戴日志（参考 Suiteki）
/// 2. Zepp Life 登录：邮箱/手机号 + 密码（参考 huami-token）
/// 3. 小米运动健康登录：小米账号 + 密码（参考 huami-token）
class AuthKeyPage extends StatelessWidget {
  const AuthKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('手环 AuthKey'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '日志扫描'),
              Tab(text: 'Zepp Life 登录'),
              Tab(text: '小米运动健康'),
            ],
          ),
        ),
        body: TabBarView(
          children: const [
            _LogScanTab(),
            _LoginTab(mode: _LoginMode.zepp),
            _LoginTab(mode: _LoginMode.xiaomi),
          ],
        ),
      ),
    );
  }
}

/// 已保存的 AuthKey 展示
class _SavedAuthKey extends StatelessWidget {
  const _SavedAuthKey();

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SettingsProvider>().bandAuthKey;
    if (saved.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: Icon(Icons.key, color: Colors.green.shade600),
        title: const Text('本机已保存的 AuthKey', style: TextStyle(fontSize: 13)),
        subtitle: SelectableText(saved,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
      ),
    );
  }
}

/// 方式 1：日志扫描
class _LogScanTab extends StatefulWidget {
  const _LogScanTab();

  @override
  State<_LogScanTab> createState() => _LogScanTabState();
}

class _LogScanTabState extends State<_LogScanTab> {
  bool _scanning = false;
  String? _result;
  String? _error;

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
          break;
        }
      }
      if (found == null) {
        _error = '未找到 AuthKey。\n'
            '请先确认：\n'
            '1. 手机已安装"小米运动健康"或"小米穿戴"并登录绑定手环\n'
            '2. 已授予本应用"所有文件访问"权限\n'
            '3. 打开过一次官方 App（让日志生成）';
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '从小米运动健康 / 小米穿戴的日志文件中提取 AuthKey（参考开源项目 Suiteki）。'
              '无需输入账号，但需要"所有文件访问"权限。',
              style: const TextStyle(fontSize: 12.5, height: 1.5),
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
                    fontSize: 12.5, height: 1.5, color: scheme.onErrorContainer)),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copy(_result!),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制'),
                ),
              ],
            ),
          ),
        ],
        const _SavedAuthKey(),
      ],
    );
  }
}

enum _LoginMode { zepp, xiaomi }

/// 方式 2/3：账号登录获取
class _LoginTab extends StatefulWidget {
  final _LoginMode mode;
  const _LoginTab({required this.mode});

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  List<BandAuthDevice> _devices = [];

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  bool get _isZepp => widget.mode == _LoginMode.zepp;

  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (user.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入账号和密码')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _devices = [];
    });
    try {
      final devices = _isZepp
          ? await zeppLogin(user, pwd)
          : await xiaomiLogin(user, pwd);
      if (!mounted) return;
      setState(() => _devices = devices);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('StateError: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndDone(String key) async {
    await context.read<SettingsProvider>().saveBandAuthKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AuthKey 已保存，可用于蓝牙直装')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              _isZepp
                  ? '登录 Zepp Life（原小米运动健康国际版）账号，从服务器获取已绑定设备的 AuthKey。'
                      '支持邮箱或手机号登录（参考开源项目 huami-token）。'
                  : '登录小米运动健康（Mi Fitness）账号，从服务器获取已绑定设备的 AuthKey。'
                      '使用小米账号/手机号登录（参考开源项目 huami-token）。',
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _userCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: _isZepp ? 'Zepp 邮箱或手机号' : '小米账号/手机号',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pwdCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '密码',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _login,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isZepp ? '登录 Zepp Life 获取' : '登录小米获取'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(fontSize: 12.5, color: scheme.error)),
        ],
        if (_devices.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('找到 ${_devices.length} 台设备，点击选择 AuthKey',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final d in _devices)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.watch,
                    color: d.active ? Colors.green : scheme.outline),
                title: Text(d.authKey,
                    style: const TextStyle(
                        fontSize: 12.5, fontFamily: 'monospace')),
                subtitle: Text('MAC: ${d.mac}${d.active ? '' : '（未激活）'}',
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.save_outlined),
                  tooltip: '保存',
                  onPressed: () => _saveAndDone(d.authKey),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          '密码仅用于本次登录请求，不会保存。若登录失败，请确认：\n'
          '· Zepp：账号已在 Zepp App 注册且绑定过手环\n'
          '· 小米：账号已绑定过手环（新注册未绑定会提示无设备）',
          style: TextStyle(fontSize: 11.5, color: scheme.outline, height: 1.5),
        ),
        const _SavedAuthKey(),
      ],
    );
  }
}
