import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/database/daos/tag_dao.dart';
import 'package:koememo/features/memo_list/memo_list_controller.dart';
import 'package:koememo/services/database_service.dart';

final memoDetailProvider = FutureProvider.family.autoDispose<Memo?, int>((
  ref,
  memoId,
) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = MemoDao(db);
  return dao.getMemoById(memoId);
});

final memoTagsProvider = FutureProvider.family.autoDispose<List<Tag>, int>((
  ref,
  memoId,
) async {
  final db = ref.watch(appDatabaseProvider);
  final tagDao = TagDao(db);
  return tagDao.getTagsForMemo(memoId);
});

/// 相対パスから絶対パスに変換するヘルパー
Future<String> resolveAudioPath(String relativePath) async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, relativePath);
}

class MemoEditor extends Notifier<Object?> {
  @override
  Object? build() => null;

  Future<void> updateTranscript(int memoId, String text) async {
    final db = ref.read(appDatabaseProvider);
    final dao = MemoDao(db);
    await dao.updateTranscript(memoId, text);
    ref.invalidate(memoDetailProvider(memoId));
    ref.invalidate(memoListProvider);
  }

  Future<void> deleteMemo(int memoId) async {
    final db = ref.read(appDatabaseProvider);
    final memoDao = MemoDao(db);
    final tagDao = TagDao(db);

    final memo = await memoDao.getMemoById(memoId);
    if (memo?.audioFilePath != null) {
      final absPath = await resolveAudioPath(memo!.audioFilePath!);
      final file = File(absPath);
      if (await file.exists()) await file.delete();
    }

    // 外部キー CASCADE が保証されないため明示的に中間テーブルも削除
    final tags = await tagDao.getTagsForMemo(memoId);
    for (final tag in tags) {
      await tagDao.removeTagFromMemo(memoId, tag.id);
    }

    await memoDao.deleteMemo(memoId);
    ref.invalidate(memoListProvider);
  }

  Future<void> deleteAudioFile(int memoId) async {
    final db = ref.read(appDatabaseProvider);
    final memoDao = MemoDao(db);

    final memo = await memoDao.getMemoById(memoId);
    if (memo?.audioFilePath != null) {
      final absPath = await resolveAudioPath(memo!.audioFilePath!);
      final file = File(absPath);
      if (await file.exists()) await file.delete();
    }

    await memoDao.deleteAudioFile(memoId);
    ref.invalidate(memoDetailProvider(memoId));
  }

  Future<void> addTag(int memoId, String tagName) async {
    final db = ref.read(appDatabaseProvider);
    final tagDao = TagDao(db);

    int tagId;
    try {
      tagId = await tagDao.createTag(tagName);
    } catch (_) {
      final tags = await tagDao.getAllTags();
      final existing = tags.firstWhere((t) => t.name == tagName);
      tagId = existing.id;
    }

    await tagDao.addTagToMemo(memoId, tagId);
    ref.invalidate(memoTagsProvider(memoId));
  }

  Future<void> removeTag(int memoId, int tagId) async {
    final db = ref.read(appDatabaseProvider);
    final tagDao = TagDao(db);
    await tagDao.removeTagFromMemo(memoId, tagId);
    ref.invalidate(memoTagsProvider(memoId));
  }
}

final memoEditorProvider = NotifierProvider<MemoEditor, Object?>(
  MemoEditor.new,
);
