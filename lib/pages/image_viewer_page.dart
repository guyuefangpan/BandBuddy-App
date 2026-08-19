import 'package:flutter/material.dart';

/// 全屏图片查看页：黑底大图，支持双指缩放、左右滑动切换、页码显示
class ImageViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const ImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late int _index = widget.initialIndex.clamp(0, widget.images.length - 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            controller: PageController(initialPage: _index),
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return Center(
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Image.network(
                    widget.images[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white54)),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38, size: 56),
                    ),
                  ),
                ),
              );
            },
          ),
          // 顶部栏：关闭 + 页码
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
