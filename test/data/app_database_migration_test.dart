import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates version 1 data to date and UUID schema', () async {
    final rawDatabase = sqlite3.openInMemory();
    rawDatabase.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    rawDatabase.execute('''
      CREATE TABLE list_models (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    rawDatabase.execute('''
      CREATE TABLE entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        list_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    rawDatabase.execute(
      "INSERT INTO categories (id, name) VALUES (1, 'Reading')",
    );
    rawDatabase.execute('''
      INSERT INTO list_models (id, category_id, name, note, created_at)
      VALUES (1, 1, 'Books', NULL, 0)
    ''');
    rawDatabase.execute('''
      INSERT INTO entries (id, list_id, content, created_at, updated_at)
      VALUES (1, 1, 'Existing entry', 0, 0)
    ''');
    rawDatabase.execute('PRAGMA user_version = 1');

    final database = AppDatabase(NativeDatabase.opened(rawDatabase));
    addTearDown(database.close);

    final entryColumns = await database
        .customSelect('PRAGMA table_info(entries)')
        .get();
    final migratedCategory = await database
        .select(database.categories)
        .getSingle();
    final migratedList = await database.select(database.listModels).getSingle();
    final migratedEntry = await database.select(database.entries).getSingle();

    expect(entryColumns.map((column) => column.data['name']), contains('date'));
    expect(migratedEntry.date, isNull);
    expect(migratedCategory.name, 'Reading');
    expect(migratedList.name, 'Books');
    expect(migratedEntry.content, 'Existing entry');
    _expectUuid(migratedCategory.externalId);
    _expectUuid(migratedList.externalId);
    _expectUuid(migratedEntry.externalId);
    expect(
      {
        migratedCategory.externalId,
        migratedList.externalId,
        migratedEntry.externalId,
      }.length,
      3,
    );
  });

  test('migrates version 2 rows to persistent unique UUIDs', () async {
    final rawDatabase = sqlite3.openInMemory();
    rawDatabase.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    rawDatabase.execute('''
      CREATE TABLE list_models (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    rawDatabase.execute('''
      CREATE TABLE entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        list_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    rawDatabase.execute(
      "INSERT INTO categories (id, name) VALUES (1, 'Meals')",
    );
    rawDatabase.execute('''
      INSERT INTO list_models (id, category_id, name, note, created_at)
      VALUES (1, 1, 'Weekday meals', 'Fast', 0)
    ''');
    rawDatabase.execute('''
      INSERT INTO entries (id, list_id, content, date, created_at, updated_at)
      VALUES (1, 1, 'Soup', 0, 0, 0)
    ''');
    rawDatabase.execute('PRAGMA user_version = 2');

    final database = AppDatabase(NativeDatabase.opened(rawDatabase));
    addTearDown(database.close);

    final category = await database.select(database.categories).getSingle();
    final list = await database.select(database.listModels).getSingle();
    final entry = await database.select(database.entries).getSingle();
    final newCategoryId = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(name: 'Exercise'));
    final newCategory = await (database.select(
      database.categories,
    )..where((table) => table.id.equals(newCategoryId))).getSingle();

    _expectUuid(category.externalId);
    _expectUuid(list.externalId);
    _expectUuid(entry.externalId);
    _expectUuid(newCategory.externalId);
    expect(
      {
        category.externalId,
        list.externalId,
        entry.externalId,
        newCategory.externalId,
      }.length,
      4,
    );
  });
}

void _expectUuid(String value) {
  expect(
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value),
    isTrue,
  );
}
