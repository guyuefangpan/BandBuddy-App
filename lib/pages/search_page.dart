import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../providers/resource_provider.dart';
import '../widgets/resource_card.dart';
import 'resource_detail_page.dart';

/// 搜索页：顶部大搜索框 + 型号/类型筛选 + 结果
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _categoryId = 'all';
  String _typeTag = '全部';
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search({bool immediate = false}) async {
    _debounce?.cancel();
    if (immediate) {
      await _doSearch();
    } else {
      _debounce = Timer(const Duration(milliseconds: 400), _doSearch);
    }
  }

  Future<void> _doSearch() async {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty && !_searched) return;
    FocusScope.of(context).unfocus();
    if (!mounted) return;
    setState(() => _searched = true);
    final rp = context.read<ResourceProvider>();
    await rp.search(keyword: kw, categoryId: _categoryId, typeTag: _typeTag);
  }

  void _onChanged(String _) {
    setState(() {}); // 更新清除按钮显示
    _search();
  }

  void _clearKeyword() {
    _ctrl.clear();
    _onChanged('');
  }

  void _applyFilter({String? categoryId, String? typeTag}) {
    setState(() {
      if (categoryId != null) _categoryId = categoryId;
      if (typeTag != null) _typeTag = typeTag;
    });
    _search(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
      ),
      body: Column(
        children: [
          // 大搜索框（body 顶部，更醒目）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.search,
                      autofocus: false,
                      style: const TextStyle(fontSize: 16),
                      onChanged: _onChanged,
                      onSubmitted: (_) => _search(immediate: true),
                      decoration: const InputDecoration(
                        hintText: '搜索表盘 / 小程序 / 固件…',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: _clearKeyword,
                      tooltip: '清除',
                    ),
                ],
              ),
            ),
          ),
          // 加载进度条
          Selector<ResourceProvider, bool>(
            selector: (_, rp) => rp.loading,
            builder: (_, loading, __) =>
                AnimatedSize(duration: const Duration(milliseconds: 200),
                    child: loading
                        ? const LinearProgressIndicator(minHeight: 2)
                        : const SizedBox(height: 2)),
          ),
          // 筛选区（型号 + 类型）
          _filters(scheme),
          const Divider(height: 1),
          // 结果区
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _filters(ColorScheme scheme) {
    final models = AppConfig.categories
        .where((c) => c.id != 'all' && c.sourceKey == null)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('型号',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.outline)),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip('全部', _categoryId == 'all',
                  () => _applyFilter(categoryId: 'all')),
              for (final m in models)
                _chip(m.name, _categoryId == m.id,
                    () => _applyFilter(categoryId: m.id)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text('类型',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.outline)),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final t in AppConfig.typeTags)
                _chip(t, _typeTag == t, () => _applyFilter(typeTag: t)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
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
    if (rp.resources.isEmpty) {
      if (rp.loading) {
        return const SizedBox.shrink();
      }
      return Center(
          child: Text(
              rp.error ??
                  '没有找到相关资源\n试试换关键词或筛选条件（搜索覆盖最新+推荐多型号分类）',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline)));
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text('输入关键词搜索资源',
                style: TextStyle(color: scheme.outline)),
            const SizedBox(height: 6),
            Text('覆盖最新与推荐排序；筛选型号/类型缩小范围',
                style: TextStyle(fontSize: 12, color: scheme.outline)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['表盘', '小程序', '像素鸟', '电子书', '固件'].map((k) {
                return ActionChip(
                  label: Text(k),
                  onPressed: () {
                    _ctrl.text = k;
                    _search(immediate: true);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}