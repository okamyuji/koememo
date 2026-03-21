import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koememo/features/memo_detail/memo_detail_controller.dart';
import 'package:koememo/features/memo_detail/widgets/audio_player_bar.dart';
import 'package:koememo/features/memo_detail/widgets/tag_editor.dart';
import 'package:koememo/services/share_service.dart';

class MemoDetailScreen extends ConsumerWidget {
  final int memoId;
  const MemoDetailScreen({super.key, required this.memoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoAsync = ref.watch(memoDetailProvider(memoId));
    final tagsAsync = ref.watch(memoTagsProvider(memoId));

    return memoAsync.when(
      data: (memo) {
        if (memo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('メモ詳細')),
            body: const Center(child: Text('メモが見つかりません')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('メモ詳細'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/memo/$memoId/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  if (memo.transcript.isNotEmpty) {
                    ref.read(shareServiceProvider).shareText(memo.transcript);
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  final editor = ref.read(memoEditorProvider.notifier);
                  if (value == 'delete_all') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('メモを削除'),
                        content: const Text('このメモを完全に削除しますか？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('削除'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await editor.deleteMemo(memoId);
                      if (context.mounted) context.pop();
                    }
                  } else if (value == 'delete_audio') {
                    await editor.deleteAudioFile(memoId);
                  }
                },
                itemBuilder: (context) => [
                  if (memo.audioFilePath != null)
                    const PopupMenuItem(
                      value: 'delete_audio',
                      child: Text('音声のみ削除'),
                    ),
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Text('メモを削除'),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(memo.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (memo.audioFilePath != null) ...[
                  AudioPlayerBar(filePath: memo.audioFilePath!),
                  const SizedBox(height: 16),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    memo.transcript.isEmpty ? '（文字起こしなし）' : memo.transcript,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 24),
                tagsAsync.when(
                  data: (tags) => TagEditor(
                    tags: tags,
                    onAdd: (name) => ref
                        .read(memoEditorProvider.notifier)
                        .addTag(memoId, name),
                    onRemove: (tagId) => ref
                        .read(memoEditorProvider.notifier)
                        .removeTag(memoId, tagId),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => const Text('タグの読み込みに失敗'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('メモ詳細')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('メモ詳細')),
        body: Center(child: Text('エラー: $error')),
      ),
    );
  }
}
