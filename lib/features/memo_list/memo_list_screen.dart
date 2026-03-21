import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koememo/features/memo_list/memo_list_controller.dart';
import 'package:koememo/features/memo_list/widgets/memo_card.dart';
import 'package:koememo/features/memo_list/widgets/search_bar.dart';
import 'package:koememo/features/memo_list/widgets/tag_filter_chips.dart';

class MemoListScreen extends ConsumerStatefulWidget {
  const MemoListScreen({super.key});

  @override
  ConsumerState<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends ConsumerState<MemoListScreen> {
  String _searchQuery = '';
  int? _selectedTagId;

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(
      memoListProvider((searchQuery: _searchQuery, tagId: _selectedTagId)),
    );
    final tagsAsync = ref.watch(tagListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          MemoSearchBar(
            currentQuery: _searchQuery,
            onChanged: (query) => setState(() => _searchQuery = query),
          ),
          tagsAsync.when(
            data: (tags) => TagFilterChips(
              tags: tags,
              selectedTagId: _selectedTagId,
              onTagSelected: (id) => setState(() => _selectedTagId = id),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: memosAsync.when(
              data: (memos) {
                if (memos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withAlpha(100),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'メモがありません',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'マイクボタンを押して録音を開始しましょう',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: memos.length,
                  itemBuilder: (context, index) {
                    final memo = memos[index];
                    return MemoCard(
                      memo: memo,
                      onTap: () => context.push('/memo/${memo.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('エラー: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recording'),
        child: const Icon(Icons.mic),
      ),
    );
  }
}
