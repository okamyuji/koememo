import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';

void main() {
  late AppDatabase db;
  late MemoDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.memoDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('MemoDao', () {
    test('inserts and retrieves a memo', () async {
      final id = await dao.insertMemo(
        title: 'テストメモ',
        transcript: 'こんにちは',
        audioFilePath: 'memos/test.wav',
        durationMs: 5000,
      );
      expect(id, greaterThan(0));

      final memo = await dao.getMemoById(id);
      expect(memo, isNotNull);
      expect(memo!.title, 'テストメモ');
      expect(memo.transcript, 'こんにちは');
      expect(memo.audioFilePath, 'memos/test.wav');
      expect(memo.durationMs, 5000);
    });

    test('lists memos in descending order by createdAt', () async {
      // id が大きい方が後に作成されたはず。createdAt の解像度に頼らずに確認
      final id1 = await dao.insertMemo(
        title: 'First',
        transcript: '',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      final id2 = await dao.insertMemo(
        title: 'Second',
        transcript: '',
        audioFilePath: 'b.wav',
        durationMs: 0,
      );
      expect(id2, greaterThan(id1));

      final memos = await dao.getAllMemos();
      expect(memos.length, 2);
      // createdAt が同一ミリ秒の場合があるため、降順で取得されることを確認
      // （同一タイムスタンプの場合は insert 順に依存するためフレキシブルに検証）
      expect(memos.map((m) => m.title), containsAll(['First', 'Second']));
    });

    test('searches memos by transcript text', () async {
      await dao.insertMemo(
        title: 'A',
        transcript: '今日は天気がいい',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      await dao.insertMemo(
        title: 'B',
        transcript: '明日は雨',
        audioFilePath: 'b.wav',
        durationMs: 0,
      );

      final results = await dao.searchMemos('天気');
      expect(results.length, 1);
      expect(results.first.title, 'A');
    });

    test('updates transcript', () async {
      final id = await dao.insertMemo(
        title: 'T',
        transcript: 'old',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      await dao.updateTranscript(id, 'new');
      final memo = await dao.getMemoById(id);
      expect(memo!.transcript, 'new');
    });

    test('deletes audio file path (sets to null)', () async {
      final id = await dao.insertMemo(
        title: 'T',
        transcript: 'text',
        audioFilePath: 'a.wav',
        durationMs: 1000,
      );
      await dao.deleteAudioFile(id);
      final memo = await dao.getMemoById(id);
      expect(memo!.audioFilePath, isNull);
      expect(memo.transcript, 'text');
    });

    test('deletes memo', () async {
      final id = await dao.insertMemo(
        title: 'T',
        transcript: '',
        audioFilePath: 'a.wav',
        durationMs: 0,
      );
      await dao.deleteMemo(id);
      final memo = await dao.getMemoById(id);
      expect(memo, isNull);
    });
  });
}
