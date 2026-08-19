import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models/band_resource.dart';
import '../providers/download_provider.dart';

/// 资源卡片：封面 + 标题 + 彩色类型标签 + 作者 + 来源 + 更新时间 + 已下载标记
class ResourceCard extends StatelessWidget {
  final BandResource resource;
  final VoidCallback? onTap;
  final String? highlightKeyword; // 搜索命中词高亮（搜索页使用）

  const ResourceCard({
    super.key,
    required this.resource,
    this.onTap,
    this.highlightKeyword,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = resource.version ?? '';
    final downloaded = context.watch<DownloadProvider>().isDownloaded(resource);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cover(scheme, downloaded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: _title(context),
                        ),
                        if (downloaded) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.download_done,
                              size: 15, color: Colors.green.shade600),
                        ],
                        if (resource.category.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _TypeBadge(category: resource.category),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${resource.author}'
                      '${version.isNotEmpty ? '  ·  v$version' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _SourceBadge(source: resource.source),
                        const SizedBox(width: 8),
                        Icon(Icons.update, size: 12, color: scheme.outline),
                        const SizedBox(width: 3),
                        Text(
                          _fmtDate(resource.updatedAt),
                          style: TextStyle(
                              fontSize: 11, color: scheme.outline),
                        ),
                        if (resource.downloads > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.download, size: 12,
                              color: scheme.outline),
                          const SizedBox(width: 3),
                          Text(
                            _fmtCount(resource.downloads),
                            style: TextStyle(
                                fontSize: 11, color: scheme.outline),
                          ),
                        ],
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            size: 16, color: scheme.outline),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(ColorScheme scheme, bool downloaded) {
    final url = resource.coverUrl;
    Widget child;
    if (url == null || url.isEmpty) {
      child = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.watch, color: scheme.onPrimaryContainer),
      );
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 56,
            height: 56,
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.watch, color: scheme.outline),
          ),
        ),
      );
    }
    if (!downloaded) return child;
    // 已下载：右下角小绿勾
    return Stack(
      children: [
        child,
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 1),
            ),
            child: const Icon(Icons.check, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// 标题（支持搜索关键词高亮）
  Widget _title(BuildContext context) {
    final kw = highlightKeyword?.trim();
    final style = const TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    if (kw == null || kw.isEmpty) {
      return Text(resource.title,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    final title = resource.title;
    final idx = title.toLowerCase().indexOf(kw.toLowerCase());
    if (idx < 0) {
      return Text(resource.title,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    final hlColor = Theme.of(context).colorScheme.primary;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: title.substring(0, idx)),
          TextSpan(
              text: title.substring(idx, idx + kw.length),
              style: TextStyle(color: hlColor, fontWeight: FontWeight.w800)),
          TextSpan(text: title.substring(idx + kw.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
}

/// 类型标签（彩色区分：表盘/小程序/固件/工具/教程）
class _TypeBadge extends StatelessWidget {
  final String category;
  const _TypeBadge({required this.category});

  static const _colors = {
    '表盘': Color(0xFF185FA5),
    '小程序': Color(0xFF7F77DD),
    '固件': Color(0xFFD85A30),
    '工具': Color(0xFF1D9E75),
    '教程': Color(0xFFBA7517),
  };

  @override
  Widget build(BuildContext context) {
    final base = _colors[category] ?? const Color(0xFF5F5E5A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: base.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        category,
        style: TextStyle(fontSize: 10, color: base),
      ),
    );
  }
}

/// 来源徽标（米坛 / GitHub）
class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isBand = source == 'bandbbs';
    final color = isBand ? const Color(0xFF0F6E56) : const Color(0xFF2C2C2A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isBand ? '米坛' : 'GitHub',
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }
}
