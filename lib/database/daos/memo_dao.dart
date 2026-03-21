import 'package:drift/drift.dart';
import '../app_database.dart';

part 'memo_dao.g.dart';

@DriftAccessor(tables: [Memos])
class MemoDao extends DatabaseAccessor<AppDatabase> with _$MemoDaoMixin {
  MemoDao(super.db);

  Future<int> insertMemo({
    required String title,
    required String transcript,
    required String? audioFilePath,
    required int durationMs,
  }) {
    final now = DateTime.now();
    return into(memos).insert(
      MemosCompanion.insert(
        title: title,
        transcript: Value(transcript),
        audioFilePath: Value(audioFilePath),
        durationMs: Value(durationMs),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<Memo?> getMemoById(int id) {
    return (select(memos)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  Future<List<Memo>> getAllMemos() {
    return (select(
      memos,
    )..orderBy([(m) => OrderingTerm.desc(m.createdAt)])).get();
  }

  Future<List<Memo>> searchMemos(String query) {
    return (select(memos)
          ..where(
            (m) => m.transcript.like('%$query%') | m.title.like('%$query%'),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Future<void> updateTranscript(int id, String newTranscript) {
    return (update(memos)..where((m) => m.id.equals(id))).write(
      MemosCompanion(
        transcript: Value(newTranscript),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteAudioFile(int id) {
    return (update(memos)..where((m) => m.id.equals(id))).write(
      MemosCompanion(
        audioFilePath: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteMemo(int id) {
    return (delete(memos)..where((m) => m.id.equals(id))).go();
  }
}
