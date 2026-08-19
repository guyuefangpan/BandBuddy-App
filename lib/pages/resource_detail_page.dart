import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models/band_resource.dart';
import '../providers/download_provider.dart';
import '../providers/resource_provider.dart';
import 'bandbbs_login_page.dart';
import 'image_viewer_page.dart';

/// 资源详情页：完整描述 / 预览图 / 版本 / 下载 / 分享
class ResourceDetailPage extends StatefulWidget {
  final BandResource resource;
  const ResourceDetailPage({super.key, required this.resource});

  @override
  State<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends State<ResourceDetailPage> {
  late BandResource _resource;
  bool _detailLoaded = false;

  @override
  void initState() {
    super.initState();
    _resource = widget.resource;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final rp = context.read<ResourceProvider>();
      final detail = await rp.fetchDetail(_resource);
      if (mounted) {
        setState(() {
          _resource = detail;
          _detailLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _detailLoaded = true);
    }
  }

  Future<void> _download() async {
    final dp = context.read<DownloadProvider>();
    try {
      final savedPath = await dp.download(_resource);
      if (!mounted) return;
      if (savedPath != null) {
        // 已下载并保存到用户选择的位置
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到：$savedPath',
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        );
      } else if (_resource.source != 'bandbbs' &&
          (_resource.downloadUrl?.isEmpty ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已跳转到浏览器，请在站内完成下载')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      // 用户取消保存 → 轻提示
      if (msg.contains('取消')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消保存')),
        );
        return;
      }
      // 米坛资源未登录 → 引导登录
      if (_resource.source == 'bandbbs' && msg.contains('登录')) {
        final goLogin = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('需要登录米坛'),
            content: const Text('登录后可在应用内直接下载资源。\n是否前往登录？'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('暂不')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('去登录')),
            ],
          ),
        );
        if (goLogin == true && mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const BandBbsLoginPage(),
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$msg')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dp = context.watch<DownloadProvider>();
    final downloading = dp.isDownloading(_resource.uniqueKey);
    final progress = dp.progressOf(_resource.uniqueKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资源详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已复制链接：${_resource.detailUrl}')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cover(scheme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_resource.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _tag(_resource.source == 'bandbbs' ? '米坛' : 'GitHub'),
                        if (_resource.category.isNotEmpty) _tag(_resource.category),
                        if (_resource.deviceModel != null)
                          _tag(_resource.deviceModel!),
                        if (_resource.version != null &&
                            _resource.version!.isNotEmpty)
                          _tag('v${_resource.version}'),
                        if (_resource.ratingValue > 0)
                          _tag('★ ${_resource.ratingValue.toStringAsFixed(1)}'
                              '${_resource.ratingCount > 0 ? ' (${_resource.ratingCount}评分)' : ''}'),
                        if (_resource.downloads > 0)
                          _tag('${_fmtCount(_resource.downloads)}次下载'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('作者：${_resource.author}',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('更新：${_fmtDate(_resource.updatedAt)}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.outline)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 下载按钮
          FilledButton.icon(
            onPressed: downloading ? null : _download,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            icon: downloading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, value: progress),
                  )
                : const Icon(Icons.download),
            label: Text(downloading
                ? '下载中 ${(progress * 100).toStringAsFixed(0)}%'
                : '下载资源'),
          ),
          if (_resource.downloadUrl == null ||
              _resource.downloadUrl!.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '提示：登录后可直接下载到本机，下载时会弹出系统保存框选择保存位置',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
          const SizedBox(height: 20),
          // 预览图（详情页正文图片，点击放大）
          if (_resource.previewImages.isNotEmpty) ...[
            const Text('资源预览',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _resource.previewImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = _resource.previewImages[i];
                  return GestureDetector(
                    onTap: () => _openImageViewer(i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 150,
                          height: 150,
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined,
                              color: scheme.outline),
                        ),
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                    width: 150,
                                    height: 150,
                                    color: scheme.surfaceContainerHighest,
                                    child: const Center(
                                        child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))),
                                  ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text('点击预览图可放大查看',
                style: TextStyle(fontSize: 11, color: scheme.outline)),
            const SizedBox(height: 10),
          ],
          const Text('资源描述',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (!_detailLoaded)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _resource.description.isEmpty
                    ? '（暂无描述，可到站内查看详情）'
                    : _resource.description,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            ),
          const SizedBox(height: 16),
          // 来源信息
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.link, color: scheme.primary),
            title: const Text('原始链接', style: TextStyle(fontSize: 13)),
            subtitle: Text(_resource.detailUrl,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openBrowser(_resource.detailUrl),
          ),
        ],
      ),
    );
  }

  Future<void> _openBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  /// 打开全屏图片查看器（从预览图 index 开始）
  void _openImageViewer(int index) {
    if (_resource.previewImages.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImageViewerPage(
        images: _resource.previewImages,
        initialIndex: index,
      ),
    ));
  }

  /// 封面图点击放大（若也在预览图中则从对应位置开始）
  void _openCoverViewer() {
    final cover = _resource.coverUrl;
    if (cover == null || cover.isEmpty) return;
    final idx = _resource.previewImages.indexOf(cover);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImageViewerPage(
        images: idx >= 0 ? _resource.previewImages : [cover],
        initialIndex: idx >= 0 ? idx : 0,
      ),
    ));
  }

  Widget _cover(ColorScheme scheme) {
    final url = _resource.coverUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.watch, size: 34, color: scheme.onPrimaryContainer),
      );
    }
    return GestureDetector(
      onTap: _openCoverViewer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 72,
            height: 72,
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.watch, color: scheme.outline),
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _fmtCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _tag(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: scheme.onSecondaryContainer)),
    );
  }
}
