import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/database/daos/tag_dao.dart';
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

class MemoEditor extends Notifier<Object?> {
  @override
  Object? build() => null;

  Future<void> updateTranscript(int memoId, String text) async {
    final db = ref.read(appDatabaseProvider);
    final dao = MemoDao(db);
    await dao.updateTranscript(memoId, text);
  }

  Future<void> deleteMemo(int memoId) async {
    final db = ref.read(appDatabaseProvider);
    final memoDao = MemoDao(db);

    final memo = await memoDao.getMemoById(memoId);
    if (memo?.audioFilePath != null) {
      final file = File(memo!.audioFilePath!);
      if (await file.exists()) await file.delete();
    }

    await memoDao.deleteMemo(memoId);
  }

  Future<void> deleteAudioFile(int memoId) async {
    final db = ref.read(appDatabaseProvider);
    final memoDao = MemoDao(db);

    final memo = await memoDao.getMemoById(memoId);
    if (memo?.audioFilePath != null) {
      final file = File(memo!.audioFilePath!);
      if (await file.exists()) await file.delete();
    }

    await memoDao.deleteAudioFile(memoId);
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
  }

  Future<void> removeTag(int memoId, int tagId) async {
    final db = ref.read(appDatabaseProvider);
    final tagDao = TagDao(db);
    await tagDao.removeTagFromMemo(memoId, tagId);
  }
}

final memoEditorProvider = NotifierProvider<MemoEditor, Object?>(
  MemoEditor.new,
);
