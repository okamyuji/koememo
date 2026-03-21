import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koememo/features/memo_detail/memo_detail_controller.dart';
import 'package:koememo/features/memo_edit/memo_edit_controller.dart';

class MemoEditScreen extends ConsumerStatefulWidget {
  final int memoId;
  const MemoEditScreen({super.key, required this.memoId});

  @override
  ConsumerState<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<MemoEditScreen> {
  late TextEditingController _textController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoAsync = ref.watch(memoDetailProvider(widget.memoId));

    return memoAsync.when(
      data: (memo) {
        if (memo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('メモ編集')),
            body: const Center(child: Text('メモが見つかりません')),
          );
        }

        if (!_initialized) {
          _textController.text = memo.transcript;
          ref.read(memoEditStateProvider.notifier).setText(memo.transcript);
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('メモ編集'),
            actions: [
              TextButton(
                onPressed: () async {
                  final saved = await ref
                      .read(memoEditStateProvider.notifier)
                      .save(widget.memoId);
                  if (saved && context.mounted) context.pop();
                },
                child: const Text('保存'),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '文字起こしテキストを編集...',
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                ref.read(memoEditStateProvider.notifier).setText(text);
              },
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('メモ編集')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('メモ編集')),
        body: Center(child: Text('エラー: $error')),
      ),
    );
  }
}
