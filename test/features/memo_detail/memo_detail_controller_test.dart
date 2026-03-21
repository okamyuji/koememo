import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/database/daos/tag_dao.dart';
import 'package:koememo/features/memo_detail/memo_detail_controller.dart';
import 'package:koememo/services/database_service.dart';

void main() {
  group('MemoDetailController', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('retrieves memo by id', () async {
      final dao = MemoDao(db);
      final id = await dao.insertMemo(
        title: 'Test',
        transcript: 'hello',
        audioFilePath: 'a.wav',
        durationMs: 1000,
      );

      final memo = await container.read(memoDetailProvider(id).future);
      expect(memo, isNotNull);
      expect(memo!.title, 'Test');
    });

    test('updateTranscript updates memo text', () async {
      final dao = MemoDao(db);
      final id = await dao.insertMemo(
        title: 'T',
        transcript: 'old',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );

      final editor = container.read(memoEditorProvider.notifier);
      await editor.updateTranscript(id, 'new text');

      final memo = await dao.getMemoById(id);
      expect(memo!.transcript, 'new text');
    });

    test('deleteAudioFile sets audioFilePath to null', () async {
      final dao = MemoDao(db);
      final id = await dao.insertMemo(
        title: 'T',
        transcript: 'text',
        audioFilePath: null,
        durationMs: 1000,
      );

      final editor = container.read(memoEditorProvider.notifier);
      await editor.deleteAudioFile(id);

      final memo = await dao.getMemoById(id);
      expect(memo!.audioFilePath, isNull);
      expect(memo.transcript, 'text');
    });

    test('deleteMemo removes memo', () async {
      final dao = MemoDao(db);
      final id = await dao.insertMemo(
        title: 'T',
        transcript: '',
        audioFilePath: null,
        durationMs: 0,
      );

      final editor = container.read(memoEditorProvider.notifier);
      await editor.deleteMemo(id);

      final memo = await dao.getMemoById(id);
      expect(memo, isNull);
    });

    test('addTag and removeTag work', () async {
      final memoDao = MemoDao(db);
      final tagDao = TagDao(db);
      final memoId = await memoDao.insertMemo(
        title: 'T',
        transcript: '',
        audioFilePath: null,
        durationMs: 0,
      );

      final editor = container.read(memoEditorProvider.notifier);
      await editor.addTag(memoId, '仕事');

      var tags = await tagDao.getTagsForMemo(memoId);
      expect(tags.length, 1);
      expect(tags.first.name, '仕事');

      await editor.removeTag(memoId, tags.first.id);
      tags = await tagDao.getTagsForMemo(memoId);
      expect(tags, isEmpty);
    });
  });
}
