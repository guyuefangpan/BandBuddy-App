import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models/band_resource.dart';
import '../providers/resource_provider.dart';
import '../widgets/category_chips.dart';
import '../widgets/resource_card.dart';
import 'resource_detail_page.dart';

/// Tab1 首页：资源发现流（型号分类 + 类型筛选 + 分页）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final _scrollCtrl = ScrollController();
  bool _firstLoad = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<ResourceProvider>().loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rp = context.read<ResourceProvider>();
      if (_firstLoad) {
        _firstLoad = false;
        rp.refresh();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rp = context.watch<ResourceProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('米环资源大全',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 型号分类
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CategoryChips(
              selectedId: rp.categoryId,
              onSelect: (id) {
                if (id != rp.categoryId) rp.refresh(categoryId: id);
              },
            ),
          ),
          const SizedBox(height: 6),
          // 类型标签 + 排序
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TypeTagChips(
                    selectedTag: rp.typeTag,
                    onSelect: (tag) {
                      if (tag != rp.typeTag) rp.refresh(typeTag: tag);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _sortChip(rp, 'rating_weighted', '推荐'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _sortChip(rp, 'latest', '最新'),
              ),
            ],
          ),
          const Divider(height: 10),
          // 列表
          Expanded(child: _buildList(rp)),
        ],
      ),
    );
  }

  Widget _buildList(ResourceProvider rp) {
    if (rp.loading && rp.resources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rp.error != null && rp.resources.isEmpty) {
      return _ErrorView(
        message: rp.error!,
        onRetry: () => rp.refresh(),
      );
    }
    if (rp.resources.isEmpty) {
      return _ErrorView(
        message: '暂无资源，换个分类试试',
        onRetry: () => rp.refresh(),
      );
    }
    return RefreshIndicator(
      onRefresh: () => rp.refresh(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: rp.resources.length + 1,
        itemBuilder: (context, i) {
          if (i >= rp.resources.length) {
            // 底部 footer：加载中 / 没有更多
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: rp.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        rp.hasMore ? '' : '—— 已经到底啦 ——',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline),
                      ),
              ),
            );
          }
          final r = rp.resources[i];
          return ResourceCard(
            resource: r,
            onTap: () => _openDetail(r),
          );
        },
      ),
    );
  }

  Widget _sortChip(ResourceProvider rp, String value, String label) {
    final selected = rp.order == value;
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        if (!selected) rp.refresh(order: value);
      },
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 11,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
    );
  }

  void _openDetail(BandResource r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResourceDetailPage(resource: r),
    ));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                size: 44, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
