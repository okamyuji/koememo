import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/features/memo_list/memo_list_controller.dart';
import 'package:koememo/services/database_service.dart';

void main() {
  group('MemoListController', () {
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

    test('returns empty list when no memos', () async {
      final memos = await container.read(
        memoListProvider((searchQuery: null, tagId: null)).future,
      );
      expect(memos, isEmpty);
    });

    test('returns memos after insert', () async {
      final dao = MemoDao(db);
      await dao.insertMemo(
        title: 'Test',
        transcript: 'hello',
        audioFilePath: 'a.wav',
        durationMs: 1000,
      );

      final memos = await container.read(
        memoListProvider((searchQuery: null, tagId: null)).future,
      );
      expect(memos.length, 1);
      expect(memos.first.title, 'Test');
    });

    test('search filters by transcript', () async {
      final dao = MemoDao(db);
      await dao.insertMemo(
        title: 'A',
        transcript: '天気予報',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      await dao.insertMemo(
        title: 'B',
        transcript: 'ニュース',
        audioFilePath: 'b.wav',
        durationMs: 0,
      );

      final memos = await container.read(
        memoListProvider((searchQuery: '天気', tagId: null)).future,
      );
      expect(memos.length, 1);
      expect(memos.first.title, 'A');
    });
  });
}
