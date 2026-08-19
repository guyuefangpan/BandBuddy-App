import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../providers/resource_provider.dart';
import '../widgets/resource_card.dart';
import 'resource_detail_page.dart';

/// Tab2 搜索：关键词搜索 + 型号/类型筛选
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _categoryId = 'all';
  String _typeTag = '全部';
  bool _searched = false;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty && !_searched) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searched = true;
      _searching = true;
      _error = null;
    });
    final rp = context.read<ResourceProvider>();
    await rp.search(keyword: kw, categoryId: _categoryId, typeTag: _typeTag);
    if (mounted) {
      setState(() {
        _searching = false;
        _error = rp.error;
      });
    }
  }

  void _applyFilter({String? categoryId, String? typeTag}) {
    setState(() {
      if (categoryId != null) _categoryId = categoryId;
      if (typeTag != null) _typeTag = typeTag;
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: '搜索表盘 / 小程序 / 固件…',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: _filters(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  /// 型号 + 类型筛选栏
  Widget _filters(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final models = AppConfig.categories
        .where((c) => c.id != 'all' && c.sourceKey == null)
        .toList();
    return Column(
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('全部', _categoryId == 'all', () => _applyFilter(categoryId: 'all')),
              for (final m in models)
                _chip(m.name, _categoryId == m.id,
                    () => _applyFilter(categoryId: m.id)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final t in AppConfig.typeTags)
                _chip(t, _typeTag == t, () => _applyFilter(typeTag: t)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '本地聚合检索：抓取所选型号的最新列表并按关键词/类型匹配；米坛站内搜索需登录，游客不可用。',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final rp = context.watch<ResourceProvider>();
    if (!_searched) {
      return _searchHint();
    }
    if (_searching && rp.resources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && rp.resources.isEmpty) {
      return Center(
          child: Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.outline)));
    }
    if (rp.resources.isEmpty) {
      return const Center(child: Text('没有找到相关资源\n试试换关键词或筛选条件'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: rp.resources.length,
      itemBuilder: (context, i) {
        final r = rp.resources[i];
        return ResourceCard(
          resource: r,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResourceDetailPage(resource: r),
          )),
        );
      },
    );
  }

  Widget _searchHint() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text('输入关键词搜索资源，可筛选型号与类型',
              style: TextStyle(color: scheme.outline)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: ['表盘', '小程序', '像素鸟', '电子书'].map((k) {
              return ActionChip(
                label: Text(k),
                onPressed: () {
                  _ctrl.text = k;
                  _search();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
