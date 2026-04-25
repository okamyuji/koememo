import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koememo/features/memo_detail/memo_detail_controller.dart';

class MemoEditScreen extends ConsumerStatefulWidget {
  final int memoId;
  const MemoEditScreen({super.key, required this.memoId});

  @override
  ConsumerState<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<MemoEditScreen> {
  late final TextEditingController _textController;
  bool _initialized = false;
  bool _saving = false;

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

  Future<void> _onSave() async {
    if (_saving) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テキストが空のため保存できません')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(memoEditorProvider.notifier)
          .updateTranscript(widget.memoId, text);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      setState(() => _saving = false);
    }
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
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('メモ編集'),
            actions: [
              TextButton(
                onPressed: _saving ? null : _onSave,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
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
