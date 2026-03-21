import 'package:flutter/material.dart';
import 'package:koememo/database/app_database.dart';

class TagFilterChips extends StatelessWidget {
  final List<Tag> tags;
  final int? selectedTagId;
  final ValueChanged<int?> onTagSelected;

  const TagFilterChips({
    super.key,
    required this.tags,
    required this.selectedTagId,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('すべて'),
              selected: selectedTagId == null,
              onSelected: (_) => onTagSelected(null),
            ),
          ),
          ...tags.map(
            (tag) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag.name),
                selected: selectedTagId == tag.id,
                onSelected: (_) =>
                    onTagSelected(selectedTagId == tag.id ? null : tag.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
