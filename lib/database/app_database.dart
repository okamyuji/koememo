import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'daos/memo_dao.dart';
import 'daos/tag_dao.dart';

part 'app_database.g.dart';

class Memos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get transcript => text().withDefault(const Constant(''))();
  TextColumn get audioFilePath => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50).unique()();
  DateTimeColumn get createdAt => dateTime()();
}

class MemoTags extends Table {
  IntColumn get memoId => integer().references(Memos, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {memoId, tagId};
}

@DriftDatabase(tables: [Memos, Tags, MemoTags], daos: [MemoDao, TagDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(driftDatabase(name: 'koememo.db'));

  @override
  int get schemaVersion => 1;
}
