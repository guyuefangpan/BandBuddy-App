import 'package:flutter/material.dart';
import '../core/config.dart';

/// 型号分类横向导航 chips
class CategoryChips extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelect;

  const CategoryChips(
      {super.key, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: AppConfig.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = AppConfig.categories[i];
          final selected = c.id == selectedId;
          return ChoiceChip(
            label: Text(c.name),
            selected: selected,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 12.5,
              color: selected
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
            ),
            backgroundColor: scheme.surfaceContainerHighest,
            selectedColor: scheme.primary,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onSelect(c.id),
          );
        },
      ),
    );
  }
}

/// 类型标签筛选 chips（表盘/小程序/固件/工具/教程）
class TypeTagChips extends StatelessWidget {
  final String selectedTag;
  final ValueChanged<String> onSelect;

  const TypeTagChips(
      {super.key, required this.selectedTag, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 12),
        ...AppConfig.typeTags.map((tag) {
          final selected = tag == selectedTag;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              selected: selected,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelect(tag),
            ),
          );
        }),
      ],
    );
  }
}
