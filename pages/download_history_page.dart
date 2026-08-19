import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';

/// 下载历史页（原收藏页的下载历史 Tab，收藏功能已移除）
class DownloadHistoryPage extends StatefulWidget {
  const DownloadHistoryPage({super.key});

  @override
  State<DownloadHistoryPage> createState() => _DownloadHistoryPageState();
}

class _DownloadHistoryPageState extends State<DownloadHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DownloadProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载历史', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: dp.history.isEmpty
          ? const Center(child: Text('暂无下载记录'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              itemCount: dp.history.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('清空下载记录？'),
                                content: const Text('仅清空记录，不影响已下载文件'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('取消')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('清空')),
                                ],
                              ),
                            );
                            if (ok == true) dp.clearHistory();
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('清空记录'),
                        ),
                      ],
                    ),
                  );
                }
                final item = dp.history[i - 1];
                final title = item['title']?.toString() ?? '未知资源';
                final filePath = item['filePath']?.toString() ?? '';
                final downloadedAt = DateTime.fromMillisecondsSinceEpoch(
                    item['downloadedAt'] as int? ?? 0);
                return ListTile(
                  leading: const Icon(Icons.download_done, color: Colors.green),
                  title: Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_fmtTime(downloadedAt)}${filePath.isNotEmpty ? '  ·  $filePath' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: filePath.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '文件位置：$filePath\n请用文件管理器打开')),
                            );
                          },
                        )
                      : null,
                );
              },
            ),
    );
  }

  static String _fmtTime(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
