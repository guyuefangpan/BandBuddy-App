import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/models/band_resource.dart';
import '../core/utils/http.dart';
import '../data/local_db.dart';

/// 用户取消了系统保存对话框
class _DownloadCancelledException implements Exception {
  const _DownloadCancelledException();
  @override
  String toString() => '已取消保存';
}

/// 下载管理：米坛资源（登录后 App 内直下）/ GitHub 直连下载，记录历史
class DownloadProvider extends ChangeNotifier {
  final Map<String, double> _progress = {}; // uniqueKey -> 0~1
  final Set<String> _downloading = {};
  List<Map<String, dynamic>> history = [];

  bool isDownloading(String key) => _downloading.contains(key);
  double progressOf(String key) => _progress[key] ?? 0;

  /// 是否已下载过（有实际保存文件的历史记录；排除"浏览器打开"记录）
  bool isDownloaded(BandResource r) {
    final key = '${r.source}:${r.sourceId}';
    return history.any((h) {
      final src = h['source']?.toString() ?? '';
      final sid = h['sourceId']?.toString() ?? '';
      final path = h['filePath']?.toString() ?? '';
      return '$src:$sid' == key &&
          path.isNotEmpty &&
          path != '浏览器打开';
    });
  }

  Future<void> loadHistory() async {
    try {
      history = await LocalDb.instance.getDownloadHistory();
    } catch (e) {
      debugPrint('download history load failed: $e');
      history = [];
    }
    notifyListeners();
  }

  /// 尝试 App 内下载
  /// - 米坛资源：需已登录，走站内下载端点（带会话 Cookie）
  /// - GitHub 直连资源：直接下载
  /// - 其他不可直连链接：浏览器打开
  /// 返回最终保存路径；用户取消保存返回 null
  Future<String?> download(BandResource r) async {
    final url = r.downloadUrl?.isNotEmpty == true ? r.downloadUrl! : r.detailUrl;
    if (url.isEmpty) return null;

    // 米坛资源 → App 内直接下载（需登录态）
    if (r.source == 'bandbbs') {
      if (!Http.hasSessionCookie) {
        throw Exception('请先登录米坛账号（我的 → 登录米坛账号）');
      }
      final dlUrl =
          '${AppConfig.bandbbsBase}/resources/${r.sourceId}/download';
      return _downloadToDir(r, dlUrl);
    }

    // 非直连链接 → 浏览器打开
    if (!_looksDirect(url)) {
      await _openInBrowser(url);
      await recordExternal(r, url);
      return null;
    }

    // 直连下载（如 GitHub release 资产）
    return _downloadToDir(r, url);
  }

  /// 下载到临时目录后弹出系统保存框，由用户选择最终保存位置
  Future<String?> _downloadToDir(BandResource r, String url) async {
    _downloading.add(r.uniqueKey);
    _progress[r.uniqueKey] = 0;
    notifyListeners();
    try {
      final tmpDir = await getTemporaryDirectory();
      final dlDir = Directory(p.join(tmpDir.path, 'bandbuddy_downloads'));
      await dlDir.create(recursive: true);
      final fileName = _fileNameFor(r, url);
      final tmpPath = p.join(dlDir.path, fileName);

      await Http.dio.download(url, tmpPath,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
          ),
          onReceiveProgress: (count, total) {
            if (total > 0) {
              _progress[r.uniqueKey] = count / total;
              notifyListeners();
            }
          });
      // 校验：若返回的是 HTML 错误页（权限不足/未登录），删除并报错
      final f = File(tmpPath);
      if (f.existsSync() && f.lengthSync() < 200 * 1024) {
        final head =
            String.fromCharCodes(await f.readAsBytes()).trimLeft().toLowerCase();
        if (head.startsWith('<html') || head.startsWith('<!doctype')) {
          f.deleteSync();
          throw Exception('下载失败：可能没有该资源的下载权限');
        }
      }
      if (!f.existsSync()) {
        throw Exception('下载失败：未获得文件数据');
      }
      // 弹出系统保存对话框：由用户选择最终保存位置（首次会请求授权）
      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: tmpPath,
          fileName: fileName,
        ),
      );
      if (savedPath == null) {
        // 用户取消保存：清理临时文件
        try {
          f.deleteSync();
        } catch (_) {}
        throw const _DownloadCancelledException();
      }
      // 保存成功：清理临时副本，记录历史（最终路径）
      try {
        f.deleteSync();
      } catch (_) {}
      final size = File(savedPath).existsSync()
          ? File(savedPath).lengthSync()
          : 0;
      await LocalDb.instance.addDownload(r, url, fileName, savedPath, size);
      await loadHistory();
      return savedPath;
    } on _DownloadCancelledException {
      rethrow;
    } catch (e) {
      debugPrint('download failed: $e');
      rethrow;
    } finally {
      _downloading.remove(r.uniqueKey);
      notifyListeners();
    }
  }

  /// 记录一次"浏览器打开"下载（非直连资源）
  Future<void> recordExternal(BandResource r, [String? url]) async {    try {
      await LocalDb.instance.addDownload(
          r, url ?? r.detailUrl, '${r.title}.bin', '浏览器打开', 0);
      await loadHistory();
    } catch (e) {
      debugPrint('record external download failed: $e');
    }
  }

  bool _looksDirect(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return false;
    final host = u.host.toLowerCase();
    if (host.contains('github') && u.path.contains('/releases/download/')) {
      return true;
    }
    if (host.contains('objects.githubusercontent')) return true;
    return false;
  }

  String _fileNameFor(BandResource r, String url) {
    final safe = r.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final base = safe.isEmpty ? 'resource_${r.sourceId}' : safe;
    // 尝试从 URL 尾部取扩展名
    final seg = Uri.parse(url).pathSegments.isNotEmpty
        ? Uri.parse(url).pathSegments.last
        : '';
    final dot = seg.lastIndexOf('.');
    if (dot > 0 && dot < seg.length - 1 && seg.length - dot <= 6) {
      final ext = seg.substring(dot).toLowerCase();
      if (RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext)) return '$base$ext';
    }
    return '$base.bin';
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> clearHistory() async {
    await LocalDb.instance.clearDownloadHistory();
    await loadHistory();
  }
}
