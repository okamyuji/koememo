import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:koememo/database/app_database.dart';

part 'database_service.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(() => db.close());
  return db;
}
