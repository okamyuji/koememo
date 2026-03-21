import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/database/daos/tag_dao.dart';
import 'package:koememo/services/database_service.dart';

final memoListProvider = FutureProvider.family
    .autoDispose<List<Memo>, ({String? searchQuery, int? tagId})>((
      ref,
      params,
    ) async {
      final db = ref.watch(appDatabaseProvider);
      final memoDao = MemoDao(db);
      final tagDao = TagDao(db);

      if (params.tagId != null) {
        return tagDao.getMemosByTag(params.tagId!);
      }
      if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
        return memoDao.searchMemos(params.searchQuery!);
      }
      return memoDao.getAllMemos();
    });

final tagListProvider = FutureProvider.autoDispose<List<Tag>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final tagDao = TagDao(db);
  return tagDao.getAllTags();
});
