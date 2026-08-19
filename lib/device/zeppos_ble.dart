// 小米手环 / ZeppOS 设备蓝牙直装（BLE）
// 协议参考 OronBox（AGPL-3.0）与 Gadgetbridge，本文件为精简重写实现
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'zeppos_auth_crypto.dart';
import 'zeppos_package_parser.dart';

/// ZeppOS 设备：服务/特征 UUID
class ZepposUuids {
  // Zepp OS（Amazfit / 小米手环7+）
  static const zeppService = '00001530-0000-3512-2118-0009af100700';
  static const zeppRecv = '00000017-0000-3512-2118-0009af100700'; // 通知
  static const zeppSent = '00000016-0000-3512-2118-0009af100700'; // 写入
  static const zeppControl = '00001531-0000-3512-2118-0009af100700';
  static const zeppData = '00001532-0000-3512-2118-0009af100700';
  // 小米经典（手环4-6）：0xFE95 服务
  static const xiaomiService = '0000fe95-0000-1000-8000-00805f9b34fb';
  static const xiaomiRecv = '0000005e-0000-1000-8000-00805f9b34fb';
  static const xiaomiSent = '0000005f-0000-1000-8000-00805f9b34fb';
}

/// 设备类型
enum BandDeviceKind { zepp, xiaomi, unknown }

/// 一台可连接的候选设备
class BandDeviceInfo {
  final String id;
  final String name;
  final BandDeviceKind kind;
  const BandDeviceInfo(this.id, this.name, this.kind);
}

/// 扫描附近的米环 / ZeppOS 设备
Future<List<BandDeviceInfo>> scanBandDevices({Duration timeout = const Duration(seconds: 8)}) async {
  final result = <BandDeviceInfo>[];
  if (await FlutterBluePlus.isSupported == false) return result;
  try {
    if ((await FlutterBluePlus.adapterState.first) != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }
    await FlutterBluePlus.startScan(timeout: timeout);
    await Future<void>.delayed(timeout);
    final devices = await FlutterBluePlus.scanResults.first;
    for (final d in devices) {
      final name = d.device.platformName;
      if (name.isEmpty) continue;
      final n = name.toLowerCase();
      final kind = n.contains('amazfit') ||
              n.contains('zepp') ||
              n.contains('gtr') ||
              n.contains('gts') ||
              n.contains('balance') ||
              n.contains('active')
          ? BandDeviceKind.zepp
          : n.contains('mi band') || n.contains('miband') || n.contains('小米手环')
              ? BandDeviceKind.xiaomi
              : BandDeviceKind.unknown;
      // 过滤：只留明显是手环/手表的
      if (kind == BandDeviceKind.unknown) {
        if (!n.contains('band') && !n.contains('watch') && !n.contains('手环') && !n.contains('手表')) {
          continue;
        }
      }
      result.add(BandDeviceInfo(d.device.remoteId.str, name, kind));
    }
  } catch (e) {
    // 扫描失败忽略
  } finally {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }
  return result;
}

/// ZeppOS 精简 BLE 传输：连接、订阅、写入、MTU
class ZepposBleTransport {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _recv;
  BluetoothCharacteristic? _sent;
  BluetoothCharacteristic? _control;
  BluetoothCharacteristic? _data;
  bool _xiaomiMode = false;
  int _mtu = 23;
  final _incoming = StreamController<Uint8List>.broadcast();
  StreamSubscription<List<int>>? _recvSub;

  Stream<Uint8List> get incoming => _incoming.stream;

  /// 连接设备并发现特征（自动区分 Zepp / Xiaomi）
  Future<void> connect(BandDeviceInfo device) async {
    _device = BluetoothDevice.fromId(device.id);
    _xiaomiMode = device.kind == BandDeviceKind.xiaomi;
    await _device!.connect(timeout: const Duration(seconds: 20), license: License.nonprofit);
    _mtu = (await _device!.mtu.first).clamp(23, 515);
    final services = await _device!.discoverServices();
    for (final s in services) {
      final suuid = s.uuid.toString().toLowerCase();
      if (!_xiaomiMode && suuid == ZepposUuids.zeppService) {
        for (final c in s.characteristics) {
          final cu = c.uuid.toString().toLowerCase();
          if (cu == ZepposUuids.zeppRecv) {
            _recv = c;
          } else if (cu == ZepposUuids.zeppSent) {
            _sent = c;
          } else if (cu == ZepposUuids.zeppControl) {
            _control = c;
          } else if (cu == ZepposUuids.zeppData) {
            _data = c;
          }
        }
      } else if (_xiaomiMode && suuid == ZepposUuids.xiaomiService) {
        for (final c in s.characteristics) {
          final cu = c.uuid.toString().toLowerCase();
          if (cu == ZepposUuids.xiaomiRecv) {
            _recv = c;
          } else if (cu == ZepposUuids.xiaomiSent) {
            _sent = c;
          }
        }
      }
    }
    if (_recv == null || _sent == null) {
      throw StateError('未在设备上找到所需的 BLE 特征（可能设备不兼容）');
    }
    _recvSub = _recv!.lastValueStream.listen((v) {
      _incoming.add(Uint8List.fromList(v));
    });
    await _recv!.setNotifyValue(true);
  }

  /// 发送协议数据（sent / control 特征，取决于模式）
  Future<void> sendProtocol(Uint8List data) async {
    if (_xiaomiMode) {
      await _sent!.write(data, withoutResponse: true);
    } else {
      await _sent!.write(data, withoutResponse: false);
    }
  }

  Future<void> writeControl(Uint8List data) async {
    await _control!.write(data, withoutResponse: false);
  }

  Future<void> writeData(Uint8List data, {bool withResponse = true}) async {
    await _data!.write(data, withoutResponse: !withResponse);
  }

  int get maxWriteLength => (_mtu - 3).clamp(20, 512);

  Future<void> requestMtu(int mtu) async {
    try {
      final m = await _device!.requestMtu(mtu);
      _mtu = m;
    } catch (_) {}
  }

  Future<void> disconnect() async {
    await _recvSub?.cancel();
    _recvSub = null;
    await _device?.disconnect();
    if (!_incoming.isClosed) await _incoming.close();
  }
}

/// 认证 + 安装流程
class ZepposInstaller {
  ZepposInstaller(this._transport);
  final ZepposBleTransport _transport;

  static const _response = 0x10;
  static const _success = 0x01;
  static const _endpointAuth = 0x0082;
  static const _cmdPubKey = 0x04;
  static const _cmdSessionKey = 0x05;

  StreamSubscription<Uint8List>? _sub;

  // 认证状态
  ZeppOsAuthKeyPair? _keyPair;
  String? _authKey;

  /// 认证（ZeppOS 握手）：返回 session key 相关对象
  Future<void> authenticate(String authKey) async {
    // 小米模式（手环4-6）暂走 ZeppOS 认证（兼容 0x82 端点设备）
    parseZeppOsAuthKey(authKey);
    _keyPair = createZeppOsAuthKeyPair();
    _authKey = authKey;

    final completer = Completer<void>();
    _sub = _transport.incoming.listen((data) {
      try {
        _handleIncoming(data, completer);
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    final command = Uint8List(52)
      ..[0] = _cmdPubKey
      ..[1] = 0x02
      ..[2] = 0x00
      ..[3] = 0x02;
    command.setRange(4, 52, _keyPair!.publicKey);
    await _sendEndpoint(_endpointAuth, command);
    await completer.future.timeout(const Duration(seconds: 15));
  }

  Future<void> _sendEndpoint(int endpoint, Uint8List payload) async {
    final out = Uint8List(payload.length + 2);
    out[0] = (endpoint >> 8) & 0xff;
    out[1] = endpoint & 0xff;
    out.setRange(2, out.length, payload);
    await _transport.sendProtocol(out);
  }

  void _handleIncoming(Uint8List data, Completer<void> completer) {
    if (data.length < 2) return;
    final endpoint = (data[0] << 8) | data[1];
    if (endpoint != _endpointAuth) return;
    final payload = Uint8List.sublistView(data, 2);
    if (payload.length < 3 || payload[0] != _response) return;
    switch (payload[1]) {
      case _cmdPubKey:
        _handlePubKey(payload, completer);
        break;
      case _cmdSessionKey:
        _handleSessionKey(payload, completer);
        break;
    }
  }

  void _handlePubKey(Uint8List payload, Completer<void> completer) {
    if (payload[2] != _success) {
      completer.completeError(StateError('公钥交换失败：${payload[2]}'));
      return;
    }
    if (payload.length < 67) {
      completer.completeError(StateError('公钥响应过短'));
      return;
    }
    final remoteRandom = Uint8List.sublistView(payload, 3, 19);
    final remotePublicKey = Uint8List.sublistView(payload, 19, 67);
    final keyPair = _keyPair;
    final authKey = _authKey;
    if (keyPair == null || authKey == null) {
      completer.completeError(StateError('认证状态缺失'));
      return;
    }
    final keys = completeZeppOsAuth(
      authKey: authKey,
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
      remotePublicKey: remotePublicKey,
    );
    // sessionKey 用于后续加密（当前认证流程已利用它完成握手）
    final secretKey = parseZeppOsAuthKey(authKey);
    final encryptedRandom1 = zeppOsAesEcbEncrypt(secretKey, remoteRandom);
    final encryptedRandom2 = zeppOsAesEcbEncrypt(keys.sessionKey, remoteRandom);
    final command = Uint8List(33)..[0] = _cmdSessionKey;
    command.setRange(1, 17, encryptedRandom1);
    command.setRange(17, 33, encryptedRandom2);
    unawaited(_sendEndpoint(_endpointAuth, command).catchError((Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    }));
  }

  void _handleSessionKey(Uint8List payload, Completer<void> completer) {
    if (payload[2] == 0x25) {
      completer.completeError(StateError('认证失败：AuthKey 错误'));
      return;
    }
    if (payload[2] != _success) {
      completer.completeError(StateError('认证失败：${payload[2]}'));
      return;
    }
    if (!completer.isCompleted) completer.complete();
  }

  // ============ 安装 ============
  static const _cmdRequestParams = 0xd0;
  static const _cmdSendInfo = 0xd2;
  static const _cmdStartTransfer = 0xd3;
  static const _cmdProgress = 0xd4;
  static const _cmdCompleteTransfer = 0xd5;
  static const _cmdFinalize = 0xd6;
  static const _packetInterval = Duration(milliseconds: 1);

  final _notifications = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _controlSub;

  /// 安装表盘/小程序包
  Future<void> installPackage(
    ZeppOsInstallPackage package, {
    void Function(double progress)? onProgress,
  }) async {
    _controlSub = _transport.incoming.listen((data) {
      _notifications.add(data);
    });
    try {
      await _transport.requestMtu(247);
      final params = await _command(_cmdRequestParams, Uint8List.fromList(const [_cmdRequestParams]));
      if (params.length < 6) {
        throw const FormatException('传输参数无效');
      }
      final deviceChunkLength = params[4] | (params[5] << 8);
      if (deviceChunkLength <= 0) {
        throw FormatException('设备分块长度无效：$deviceChunkLength');
      }

      final info = Uint8List(14)
        ..[0] = _cmdSendInfo
        ..[1] = package.firmwareType;
      _writeUint32Le(info, 2, package.bytes.length);
      _writeUint32Le(info, 6, package.crc32);
      _writeUint16Le(info, 10, deviceChunkLength);
      info[12] = 0;
      info[13] = 0xff;
      await _command(_cmdSendInfo, info);
      await _command(_cmdStartTransfer, Uint8List.fromList(const [_cmdStartTransfer, 0x01]));

      var offset = 0;
      final packetLength = _transport.maxWriteLength;
      while (offset < package.bytes.length) {
        final chunkEnd = math.min(offset + deviceChunkLength, package.bytes.length);
        final progressFuture = _next(_cmdProgress, timeout: const Duration(seconds: 60));
        for (var packetOffset = offset; packetOffset < chunkEnd; packetOffset += packetLength) {
          final packetEnd = math.min(packetOffset + packetLength, chunkEnd);
          await _transport.writeData(
            Uint8List.sublistView(package.bytes, packetOffset, packetEnd),
            withResponse: true,
          );
          if (packetEnd < package.bytes.length) {
            await Future<void>.delayed(_packetInterval);
          }
        }
        final progress = await progressFuture;
        if (progress.length < 6) {
          throw const FormatException('进度响应无效');
        }
        final nextOffset = ByteData.sublistView(progress, 2, 6).getUint32(0, Endian.little);
        if (nextOffset <= offset || nextOffset > package.bytes.length) {
          throw FormatException('传输偏移无效：$nextOffset');
        }
        offset = nextOffset;
        onProgress?.call(offset / package.bytes.length);
      }

      await _command(_cmdCompleteTransfer, Uint8List.fromList(const [_cmdCompleteTransfer]));
      await _command(_cmdFinalize, Uint8List.fromList(const [_cmdFinalize]),
          timeout: const Duration(seconds: 45));
      onProgress?.call(1);
    } finally {
      await _controlSub?.cancel();
      _controlSub = null;
    }
  }

  Future<Uint8List> _command(int command, Uint8List payload, {Duration timeout = const Duration(seconds: 15)}) async {
    final response = _next(command, timeout: timeout);
    await _transport.writeControl(payload);
    final value = await response;
    if (value.length < 3 || value[2] != _success) {
      final status = value.length >= 3 ? value[2] : -1;
      throw StateError('安装命令 0x${command.toRadixString(16)} 被设备拒绝：0x${status.toRadixString(16)}');
    }
    return value;
  }

  Future<Uint8List> _next(int command, {required Duration timeout}) =>
      _notifications.stream
          .firstWhere((v) => v.length >= 2 && v[0] == _response && v[1] == command)
          .timeout(timeout);

  static void _writeUint16Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
  }

  static void _writeUint32Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controlSub?.cancel();
    if (!_notifications.isClosed) await _notifications.close();
  }
}

/// 识别表盘文件类型（bin：表盘；zab：Zepp 应用包）
String guessFirmwareType(String fileName) {
  final n = fileName.toLowerCase();
  if (n.endsWith('.zab')) return 'zeppos-app';
  if (n.endsWith('.bin')) return 'watchface-bin';
  return 'watchface-bin';
}

/// 从本地文件构建安装包（.bin 直接装；.zab 用解析器）
ZeppOsInstallPackage buildInstallPackage(String filePath, String fileName) {
  final bytes = _ioReadBytes(filePath);
  if (fileName.toLowerCase().endsWith('.zab')) {
    return const ZeppOsPackageParser().parse(bytes);
  }
  // .bin 表盘
  return ZeppOsInstallPackage(
    type: ZeppOsPackageType.watchface,
    bytes: bytes,
    crc32: _crc32(bytes),
  );
}

Uint8List _ioReadBytes(String path) => File(path).readAsBytesSync();

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
