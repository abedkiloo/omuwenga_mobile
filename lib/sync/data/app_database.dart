import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [OutboxItems, CachedProducts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  static AppDatabase memory() => AppDatabase(NativeDatabase.memory());

  static Future<AppDatabase> file({String name = 'cbpos_sync.sqlite'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, name));
    return AppDatabase(NativeDatabase.createInBackground(file));
  }
}
