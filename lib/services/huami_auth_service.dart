// 手环 AuthKey 获取：Zepp Life（Amazfit）与小米运动健康（Mi Fitness）账号登录方式
// 协议移植自 huami-token（https://github.com/argrento/huami-token，MIT License）
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;

/// 设备信息（authkey 等）
class BandAuthDevice {
  final String mac;
  final bool active;
  final String authKey;
  const BandAuthDevice(this.mac, this.active, this.authKey);
}

/// Zepp Life 登录（邮箱/手机号 + 密码）
Future<List<BandAuthDevice>> zeppLogin(String emailOrPhone, String password) async {
  // 1. 加密请求 tokens
  final payload = {
    'emailOrPhone': emailOrPhone,
    'state': 'REDIRECTION',
    'client_id': 'HuaMi',
    'password': password,
    'redirect_uri':
        'https://s3-us-west-2.amazonaws.com/hm-registration/successsignin.html',
    'region': 'us-west-2',
    'token': ['access', 'refresh'],
    'country_code': 'US',
  };
  final encoded = _urlEncode(payload);
  final encrypted = _aesCbcEncrypt(
    utf8.encode(encoded),
    utf8.encode('xeNtBVqzDc6tuNTh'),
    utf8.encode('MAAAYAAAAAAAAABg'),
  );
  final resp = await _postBytes(
    'https://api-user-us2.zepp.com/v2/registrations/tokens',
    encrypted,
    headers: const {
      'app_name': 'com.huami.midong',
      'appname': 'com.huami.midong',
      'cv': '151689_9.12.5',
      'v': '2.0',
      'appplatform': 'android_phone',
      'vb': '202509151347',
      'vn': '9.12.5',
      'user-agent': 'Zepp/9.12.5 (Pixel 4; Android 12; Density/2.75)',
      'x-hm-ekv': '1',
      'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
    },
  );
  final accessToken = _queryParam(resp.location, 'access');
  final refreshToken = _queryParam(resp.location, 'refresh');
  if (accessToken == null || refreshToken == null) {
    throw StateError('Zepp 登录失败：未获取到令牌（账号或密码错误？）');
  }

  // 2. login → app_token / login_token / user_id
  final loginPayload = {
    'code': accessToken,
    'device_id': _uuid(),
    'device_model': 'android_phone',
    'app_version': '9.12.5',
    'dn':
        'api-mifit.zepp.com,api-user.zepp.com,api-mifit.zepp.com,api-watch.zepp.com,app-analytics.zepp.com,auth.zepp.com,api-analytics.zepp.com',
    'third_name': 'huami',
    'source': 'com.huami.watch.hmwatchmanager:9.12.5:151689',
    'app_name': 'com.huami.midong',
    'country_code': 'US',
    'grant_type': 'access_token',
    'allow_registration': 'false',
    'lang': 'en',
    'countryState': 'US-NY',
  };
  final loginResp = await _postForm(
    'https://api-mifit-us2.zepp.com/v2/client/login',
    loginPayload,
    headers: const {
      'app_name': 'com.huami.webapp',
      'appname': 'com.huami.webapp',
      'origin': 'https://user.zepp.com',
      'referer': 'https://user.zepp.com/',
      'user-agent':
          'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
      'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
    },
  );
  final loginData = loginResp.json;
  final tokenInfo = loginData['token_info'] as Map? ?? const {};
  final appToken = tokenInfo['app_token']?.toString() ?? '';
  final userId = tokenInfo['user_id']?.toString() ?? '';
  if (appToken.isEmpty || userId.isEmpty) {
    throw StateError('Zepp 登录失败：登录响应缺少令牌');
  }

  // 3. 设备列表
  final deviceResp = await _getForm(
    'https://api-mifit.zepp.com/users/$userId/devices',
    params: {
      'r': _random64(),
      'enableMultiDeviceOnMultiType': 'true',
      'userid': userId,
      'appid': _random64(),
      'channel': 'a100900101016',
      'country': 'US',
      'cv': '151689_9.12.5',
      'device': 'android_32',
      'device_type': 'android_phone',
      'enableMultiDevice': 'true',
      'lang': 'en_US',
      'timezone': 'Asia/Shanghai',
      'v': '2.0',
    },
    headers: {
      'hm-privacy-diagnostics': 'false',
      'country': 'US',
      'appplatform': 'android_phone',
      'hm-privacy-ceip': 'true',
      'x-request-id': _uuid(),
      'timezone': 'Asia/Shanghai',
      'channel': 'a100900101016',
      'vb': '202509151347',
      'cv': '151689_9.12.5',
      'appname': 'com.huami.midong',
      'v': '2.0',
      'vn': '9.12.5',
      'apptoken': appToken,
      'lang': 'en_US',
      'user-agent': 'Zepp/9.12.5 (Pixel 4; Android 12; Density/2.75)',
    },
  );
  final items = (deviceResp.json['items'] as List? ?? const []);
  final devices = <BandAuthDevice>[];
  for (final item in items) {
    if (item is! Map) continue;
    final additional = _jsonDecodeMap(item['additionalInfo']?.toString() ?? '{}');
    final authKey = additional['auth_key']?.toString() ?? '';
    if (authKey.isEmpty) continue;
    devices.add(BandAuthDevice(
      item['macAddress']?.toString() ?? '??',
      (item['activeStatus'] ?? 0) != 0,
      authKey,
    ));
  }
  if (devices.isEmpty) {
    throw StateError('Zepp 账号下未找到设备（请先在 Zepp App 中绑定手环）');
  }
  return devices;
}

/// 小米运动健康（Mi Fitness）登录（小米账号/手机号 + 密码）
Future<List<BandAuthDevice>> xiaomiLogin(String account, String password) async {
  final deviceId = 'an_${md5.convert(utf8.encode(account)).toString()}';

  // 1. serviceLogin
  final page = await _getForm(
    'https://account.xiaomi.com/pass/serviceLogin',
    params: {'_json': 'true', 'sid': 'miothealth', '_locale': 'en_US'},
    headers: _xiaomiHeaders(),
    cookies: {'userId': account, 'deviceId': deviceId},
  );
  final pageData = _parseXiaomiJson(page.text);
  final sign = pageData['_sign']?.toString() ?? '';
  final qs = pageData['qs']?.toString() ?? '';
  final callback = pageData['callback']?.toString() ?? '';
  if (sign.isEmpty || qs.isEmpty || callback.isEmpty) {
    throw StateError('小米登录失败：无法获取登录参数');
  }

  // 2. serviceLoginAuth2
  final authResp = await _postForm(
    'https://account.xiaomi.com/pass/serviceLoginAuth2',
    {
      'qs': qs,
      'callback': callback,
      '_json': 'true',
      '_sign': sign,
      'user': account,
      'hash': md5.convert(utf8.encode(password)).toString().toUpperCase(),
      'sid': 'miothealth',
      '_locale': 'en_US',
    },
    headers: _xiaomiHeaders(),
    cookies: {'deviceId': deviceId},
  );
  final authData = _parseXiaomiJson(authResp.text);
  if ((authData['code'] ?? -1) != 0) {
    throw StateError('小米登录失败：${authData['description'] ?? authData['code']}');
  }
  final ssecurity = authData['ssecurity']?.toString() ?? '';
  final nonce = authData['nonce']?.toString() ?? '';
  final cUserId = authData['cUserId']?.toString() ?? '';
  final location = authData['location']?.toString() ?? '';
  if (ssecurity.isEmpty || location.isEmpty) {
    throw StateError('小米登录失败：缺少安全参数');
  }

  // 3. serviceToken（跟随 location + clientSign）
  final clientSign = base64Encode(sha1
      .convert(utf8.encode('nonce=$nonce&$ssecurity'))
      .bytes);
  final tokenResp = await _getRaw(
    '$location&clientSign=${Uri.encodeComponent(clientSign)}',
    allowRedirects: false,
  );
  var serviceToken = tokenResp.cookies['serviceToken'];
  if (serviceToken == null) {
    final loc = tokenResp.location;
    if (loc != null) {
      serviceToken = await _followForToken(loc);
    }
  }
  if (serviceToken == null || serviceToken.isEmpty) {
    throw StateError('小米登录失败：未获取到 serviceToken');
  }

  // 4. 设备列表（RC4 加密）
  final data = jsonEncode({'page_size': 50, 'status': 1});
  final nonceB64 = _generateNonce();
  final encrypted = _miEncryptParams(
    method: 'POST',
    signingPath: '/app/v1/source/get_source_list',
    params: {'data': data},
    nonceB64: nonceB64,
    ssecurityB64: ssecurity,
  );
  final deviceResp = await _postForm(
    'https://hlth.io.mi.com/app/v1/source/get_source_list',
    encrypted,
    headers: {
      'User-Agent': 'Android-12-9.8.348i-google-Pixel 4',
      'Accept-Encoding': 'gzip',
      'region_tag': 'cn',
    },
    cookies: {'cUserId': cUserId, 'serviceToken': serviceToken, 'locale': 'zh_cn'},
  );
  final decrypted = _miDecryptResponse(deviceResp.text, nonceB64, ssecurity);
  final items = (_jsonDecodeMap(decrypted)['items'] as List? ?? const []);
  final devices = <BandAuthDevice>[];
  for (final item in items) {
    if (item is! Map) continue;
    final additional = _jsonDecodeMap(item['additionalInfo']?.toString() ?? '{}');
    final authKey = additional['auth_key']?.toString() ?? '';
    if (authKey.isEmpty) continue;
    devices.add(BandAuthDevice(
      item['macAddress']?.toString() ?? '??',
      (item['activeStatus'] ?? 0) != 0,
      authKey,
    ));
  }
  if (devices.isEmpty) {
    throw StateError('小米账号下未找到设备（请先在小米运动健康中绑定手环）');
  }
  return devices;
}

// ============ HTTP 辅助 ============
class _Resp {
  final String text;
  final Map<String, dynamic> json;
  final String? location;
  final Map<String, String> cookies;
  const _Resp({required this.text, required this.json, this.location, this.cookies = const {}});
}

Map<String, String> _xiaomiHeaders() => const {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 12; Pixel 4 Build/SP1A.210812.016.C1; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/131.0.6778.200 Mobile Safari/537.36',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    };

Future<_Resp> _postBytes(String url, List<int> body,
    {Map<String, String> headers = const {}}) async {
  return _sendRaw('POST', url, body: body, headers: headers);
}

Future<_Resp> _postForm(String url, Map<String, dynamic> form,
    {Map<String, String> headers = const {}, Map<String, String> cookies = const {}}) async {
  return _sendRaw('POST', url, body: utf8.encode(_urlEncode(form)), headers: headers, cookies: cookies);
}

Future<_Resp> _getForm(String url, {Map<String, String> params = const {}, Map<String, String> headers = const {}, Map<String, String> cookies = const {}}) async {
  final q = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
  final full = '$url${q.isEmpty ? '' : '?$q'}';
  return _sendRaw('GET', full, headers: headers, cookies: cookies);
}

Future<_Resp> _getRaw(String url, {bool allowRedirects = true, Map<String, String> headers = const {}, Map<String, String> cookies = const {}}) async {
  return _sendRaw('GET', url, headers: headers, cookies: cookies, allowRedirects: allowRedirects);
}

Future<String?> _followForToken(String location) async {
  final r = await _getRaw(location, allowRedirects: true);
  return r.cookies['serviceToken'];
}

// 简易 HTTP 客户端（无外部依赖）
Future<_Resp> _sendRaw(String method, String url,
    {List<int>? body,
    Map<String, String> headers = const {},
    Map<String, String> cookies = const {},
    bool allowRedirects = true}) async {
  // 使用 dart:io HttpClient
  final http = HttpClient();
  try {
    final uri = Uri.parse(url);
    final req = await http.openUrl(method, uri);
    headers.forEach((k, v) => req.headers.set(k, v));
    if (cookies.isNotEmpty) {
      req.headers.set('Cookie', cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
    }
    if (body != null) {
      req.add(body);
    }
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    final jsonMap = _tryJson(text);
    Map<String, String> setCookies = {};
    resp.headers.forEach((k, v) {
      if (k.toLowerCase() == 'set-cookie') {
        for (final part in v) {
          final kv = part.split(';').first;
          final idx = kv.indexOf('=');
          if (idx > 0) {
            setCookies[kv.substring(0, idx).trim()] = kv.substring(idx + 1).trim();
          }
        }
      }
    });
    return _Resp(
      text: text,
      json: jsonMap,
      location: resp.headers.value('location'),
      cookies: setCookies,
    );
  } finally {
    http.close();
  }
}

// ============ 加密/编码辅助 ============
String _urlEncode(Map<String, dynamic> params) {
  final buf = StringBuffer();
  params.forEach((k, v) {
    if (v is List) {
      for (final item in v) {
        if (buf.isNotEmpty) buf.write('&');
        buf.write('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(item.toString())}');
      }
    } else {
      if (buf.isNotEmpty) buf.write('&');
      buf.write('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v.toString())}');
    }
  });
  return buf.toString();
}

List<int> _aesCbcEncrypt(List<int> data, List<int> key, List<int> iv) {
  final engine = pc.PaddedBlockCipherImpl(
    pc.PKCS7Padding(),
    pc.CBCBlockCipher(pc.AESEngine()),
  );
  engine.init(
    true,
    pc.PaddedBlockCipherParameters(
      pc.ParametersWithIV(
        pc.KeyParameter(Uint8List.fromList(key)),
        Uint8List.fromList(iv),
      ),
      null,
    ),
  );
  return engine.process(Uint8List.fromList(data));
}

Map<String, dynamic> _tryJson(String text) {
  try {
    return jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

Map<String, dynamic> _jsonDecodeMap(String text) {
  try {
    final v = jsonDecode(text);
    return v is Map ? Map<String, dynamic>.from(v) : {};
  } catch (_) {
    return {};
  }
}

Map<String, dynamic> _parseXiaomiJson(String text) {
  var t = text;
  const prefix = '&&&START&&&';
  if (t.startsWith(prefix)) t = t.substring(prefix.length);
  return _jsonDecodeMap(t);
}

String? _queryParam(String? url, String name) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  return uri.queryParameters[name];
}

String _uuid() => _Rng().genUuid();

String _random64() => _Rng().genUuid().replaceAll('-', '');

class _Rng {
  final _rng = Random();
  String genUuid() {
    final b = List<int>.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

// ============ 小米 RC4 加密 ============
class _RC4 {
  _RC4(List<int> key) {
    _s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + _s[i] + key[i % key.length]) & 0xff;
      final t = _s[i];
      _s[i] = _s[j];
      _s[j] = t;
    }
  }
  late List<int> _s;
  int _i = 0;
  int _j = 0;

  List<int> crypt(List<int> data) {
    final out = List<int>.filled(data.length, 0);
    for (var k = 0; k < data.length; k++) {
      _i = (_i + 1) & 0xff;
      _j = (_j + _s[_i]) & 0xff;
      final t = _s[_i];
      _s[_i] = _s[_j];
      _s[_j] = t;
      out[k] = data[k] ^ _s[(_s[_i] + _s[_j]) & 0xff];
    }
    return out;
  }
}

String _deriveRc4Key(String ssecurityB64, String nonceB64) {
  final combined = base64Decode(ssecurityB64) + base64Decode(nonceB64);
  return base64Encode(sha256.convert(combined).bytes);
}

_RC4 _makeRc4(String keyB64) {
  final rc4 = _RC4(base64Decode(keyB64));
  rc4.crypt(List<int>.filled(1024, 0));
  return rc4;
}

String _sha1Sign(String method, String path, Map<String, String> params, String keyB64) {
  final parts = <String>[];
  if (method.isNotEmpty) parts.add(method.toUpperCase());
  if (path.isNotEmpty) parts.add(path);
  if (params.isNotEmpty) {
    final keys = params.keys.toList()..sort();
    for (final k in keys) {
      parts.add('$k=${params[k]}');
    }
  }
  parts.add(keyB64);
  final digest = sha1.convert(utf8.encode(parts.join('&')));
  return base64Encode(digest.bytes);
}

String _generateNonce() {
  final random = List<int>.generate(8, (_) => Random().nextInt(256));
  final minutes = DateTime.now().millisecondsSinceEpoch ~/ 60000;
  final timeBytes = [
    (minutes >> 24) & 0xff,
    (minutes >> 16) & 0xff,
    (minutes >> 8) & 0xff,
    minutes & 0xff,
  ];
  return base64Encode(random + timeBytes);
}

Map<String, String> _miEncryptParams({
  required String method,
  required String signingPath,
  required Map<String, String> params,
  required String nonceB64,
  required String ssecurityB64,
}) {
  final keyB64 = _deriveRc4Key(ssecurityB64, nonceB64);
  final sorted = Map<String, String>.fromEntries(params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  final rc4Hash = _sha1Sign(method, signingPath, sorted, keyB64);
  sorted['rc4_hash__'] = rc4Hash;
  final sortedAll = Map<String, String>.fromEntries(sorted.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  final rc4 = _makeRc4(keyB64);
  final encrypted = <String, String>{};
  final sortedKeys = sortedAll.keys.toList()..sort();
  for (final k in sortedKeys) {
    encrypted[k] = base64Encode(rc4.crypt(utf8.encode(sortedAll[k]!)));
  }
  final signature = _sha1Sign(method, signingPath, encrypted, keyB64);
  return {...encrypted, 'signature': signature, '_nonce': nonceB64};
}

String _miDecryptResponse(String bodyB64, String nonceB64, String ssecurityB64) {
  final keyB64 = _deriveRc4Key(ssecurityB64, nonceB64);
  final rc4 = _makeRc4(keyB64);
  final bytes = rc4.crypt(base64Decode(bodyB64));
  return utf8.decode(bytes);
}
