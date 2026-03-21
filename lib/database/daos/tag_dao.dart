import 'package:drift/drift.dart';
import '../app_database.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, MemoTags, Memos])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Future<int> createTag(String name) {
    return into(
      tags,
    ).insert(TagsCompanion.insert(name: name, createdAt: DateTime.now()));
  }

  Future<List<Tag>> getAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> addTagToMemo(int memoId, int tagId) {
    return into(
      memoTags,
    ).insert(MemoTagsCompanion.insert(memoId: memoId, tagId: tagId));
  }

  Future<void> removeTagFromMemo(int memoId, int tagId) {
    return (delete(
      memoTags,
    )..where((mt) => mt.memoId.equals(memoId) & mt.tagId.equals(tagId))).go();
  }

  Future<List<Tag>> getTagsForMemo(int memoId) {
    final query = select(tags).join([
      innerJoin(memoTags, memoTags.tagId.equalsExp(tags.id)),
    ])..where(memoTags.memoId.equals(memoId));
    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Memo>> getMemosByTag(int tagId) {
    final query =
        select(
            memos,
          ).join([innerJoin(memoTags, memoTags.memoId.equalsExp(memos.id))])
          ..where(memoTags.tagId.equals(tagId))
          ..orderBy([OrderingTerm.desc(memos.createdAt)]);
    return query.map((row) => row.readTable(memos)).get();
  }

  Future<void> deleteTag(int tagId) async {
    await (delete(memoTags)..where((mt) => mt.tagId.equals(tagId))).go();
    await (delete(tags)..where((t) => t.id.equals(tagId))).go();
  }
}
