import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:koememo/features/memo_detail/memo_detail_controller.dart';

part 'memo_edit_controller.g.dart';

@riverpod
class MemoEditState extends _$MemoEditState {
  @override
  String build() => '';

  void setText(String text) => state = text;

  Future<bool> save(int memoId) async {
    final text = state.trim();
    if (text.isEmpty) return false;

    final editor = ref.read(memoEditorProvider.notifier);
    await editor.updateTranscript(memoId, text);
    return true;
  }
}
