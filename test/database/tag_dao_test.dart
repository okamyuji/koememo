import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/database/daos/tag_dao.dart';

void main() {
  late AppDatabase db;
  late TagDao tagDao;
  late MemoDao memoDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tagDao = db.tagDao;
    memoDao = db.memoDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('TagDao', () {
    test('creates and retrieves a tag', () async {
      final id = await tagDao.createTag('仕事');
      final tags = await tagDao.getAllTags();
      expect(tags.length, 1);
      expect(tags.first.name, '仕事');
      expect(tags.first.id, id);
    });

    test('prevents duplicate tag names', () async {
      await tagDao.createTag('仕事');
      expect(() => tagDao.createTag('仕事'), throwsA(anything));
    });

    test('adds tag to memo and retrieves', () async {
      final memoId = await memoDao.insertMemo(
        title: 'T',
        transcript: '',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      final tagId = await tagDao.createTag('重要');

      await tagDao.addTagToMemo(memoId, tagId);
      final tags = await tagDao.getTagsForMemo(memoId);
      expect(tags.length, 1);
      expect(tags.first.name, '重要');
    });

    test('removes tag from memo', () async {
      final memoId = await memoDao.insertMemo(
        title: 'T',
        transcript: '',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      final tagId = await tagDao.createTag('重要');
      await tagDao.addTagToMemo(memoId, tagId);

      await tagDao.removeTagFromMemo(memoId, tagId);
      final tags = await tagDao.getTagsForMemo(memoId);
      expect(tags, isEmpty);
    });

    test('gets memos by tag', () async {
      final memoId1 = await memoDao.insertMemo(
        title: 'A',
        transcript: '',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      await memoDao.insertMemo(
        title: 'B',
        transcript: '',
        audioFilePath: 'b.wav',
        durationMs: 0,
      );
      final tagId = await tagDao.createTag('仕事');
      await tagDao.addTagToMemo(memoId1, tagId);

      final memos = await tagDao.getMemosByTag(tagId);
      expect(memos.length, 1);
      expect(memos.first.title, 'A');
    });

    test('deletes tag', () async {
      final tagId = await tagDao.createTag('削除予定');
      await tagDao.deleteTag(tagId);
      final tags = await tagDao.getAllTags();
      expect(tags, isEmpty);
    });
  });
}
