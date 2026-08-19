import 'package:dio/dio.dart';
import '../../core/utils/http.dart';

/// 更新信息（来自 GitHub Releases）
class AppUpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String releasesUrl; // GitHub Releases 页面
  final String? downloadUrl; // APK 直链（assets 第一个 APK）
  const AppUpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.releasesUrl,
    this.downloadUrl,
  });
}

/// 检查更新服务：从 GitHub Releases 获取最新版本
/// （参考 OronBox 的降级方案：其服务器 API 不可用时走 GitHub Releases）
class UpdateService {
  static const _githubApi = 'https://api.github.com';

  /// 获取最新 Release 信息；仓库未配置或请求失败返回 null（静默跳过）
  static Future<AppUpdateInfo?> fetchLatest({required String repo}) async {
    final r = repo.trim();
    if (r.isEmpty) return null;
    try {
      final resp = await Http.dio.get<Map<String, dynamic>>(
        '$_githubApi/repos/$r/releases/latest',
        options: Options(headers: {
          'User-Agent': 'BandBuddyApp/1.0',
          'Accept': 'application/vnd.github+json',
        }),
      );
      final data = resp.data;
      if (data == null) return null;
      final tag = data['tag_name']?.toString() ?? '';
      if (tag.isEmpty) return null;
      // APK 直链：assets 里第一个 .apk
      String? apkUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map) {
            final url = a['browser_download_url']?.toString() ?? '';
            if (url.toLowerCase().endsWith('.apk')) {
              apkUrl = url;
              break;
            }
          }
        }
      }
      return AppUpdateInfo(
        latestVersion: tag,
        releaseNotes: (data['body']?.toString() ?? '').trim(),
        releasesUrl: data['html_url']?.toString() ??
            'https://github.com/$r/releases/latest',
        downloadUrl: apkUrl,
      );
    } catch (e) {
      // 网络失败/仓库不存在：静默跳过，不打扰用户
      return null;
    }
  }

  /// 版本号比较：latest 是否比 current 新（支持 v1.2.3 / 1.2.3 格式）
  static bool isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    if (l.isEmpty) return false;
    final len = l.length > c.length ? l.length : c.length;
    for (var i = 0; i < len; i++) {
      final a = i < l.length ? l[i] : 0;
      final b = i < c.length ? c[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  static List<int> _parse(String version) {
    final clean = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return clean
        .split(RegExp(r'[.\-_+]'))
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
  }
}
