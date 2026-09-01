import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_3/data/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates version 1 entries with a nullable date column', () async {
    final rawDatabase = sqlite3.openInMemory();
    rawDatabase.execute('''
      CREATE TABLE entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        list_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    rawDatabase.execute('''
      INSERT INTO entries (id, list_id, content, created_at, updated_at)
      VALUES (1, 1, 'Existing entry', 0, 0)
    ''');
    rawDatabase.execute('PRAGMA user_version = 1');

    final database = AppDatabase(NativeDatabase.opened(rawDatabase));
    addTearDown(database.close);

    final columns = await database
        .customSelect('PRAGMA table_info(entries)')
        .get();
    final migratedEntry = await database
        .customSelect('SELECT date FROM entries WHERE id = 1')
        .getSingle();

    expect(columns.map((column) => column.data['name']), contains('date'));
    expect(migratedEntry.data['date'], isNull);
  });
}
