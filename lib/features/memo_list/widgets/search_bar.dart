import 'package:flutter/material.dart';

class MemoSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String currentQuery;

  const MemoSearchBar({
    super.key,
    required this.onChanged,
    required this.currentQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SearchBar(
        hintText: 'メモを検索...',
        leading: const Icon(Icons.search),
        onChanged: onChanged,
        trailing: currentQuery.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(''),
                ),
              ]
            : null,
      ),
    );
  }
}
