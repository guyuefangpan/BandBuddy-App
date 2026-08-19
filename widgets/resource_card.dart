import 'package:flutter/material.dart';
import '../core/models/band_resource.dart';

/// 资源卡片：封面 + 标题 + 彩色类型标签 + 作者 + 来源 + 更新时间
class ResourceCard extends StatelessWidget {
  final BandResource resource;
  final VoidCallback? onTap;

  const ResourceCard({super.key, required this.resource, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = resource.version ?? '';
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
              _cover(scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            resource.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
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

  Widget _cover(ColorScheme scheme) {
    final url = resource.coverUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.watch, color: scheme.onPrimaryContainer),
      );
    }
    return ClipRRect(
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
