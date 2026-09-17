import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates v4 language-scoped taxonomy to shared categories', () async {
    final raw = sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE languages (id INTEGER PRIMARY KEY, external_id TEXT NOT NULL UNIQUE, name TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE vocabulary_categories (id INTEGER PRIMARY KEY, external_id TEXT NOT NULL UNIQUE, language_id INTEGER NOT NULL, name TEXT NOT NULL, created_at INTEGER NOT NULL, UNIQUE(language_id, name))',
    );
    raw.execute(
      'CREATE TABLE vocabulary_subcategories (id INTEGER PRIMARY KEY, external_id TEXT NOT NULL UNIQUE, category_id INTEGER NOT NULL, name TEXT NOT NULL, created_at INTEGER NOT NULL, UNIQUE(category_id, name))',
    );
    raw.execute(
      'CREATE TABLE vocabulary_words (id INTEGER PRIMARY KEY, external_id TEXT NOT NULL UNIQUE, category_id INTEGER NOT NULL, subcategory_id INTEGER, word TEXT NOT NULL, meaning TEXT NOT NULL, is_completed INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, UNIQUE(category_id, subcategory_id, word, meaning))',
    );
    raw.execute("INSERT INTO languages VALUES (1, 'language-1', 'Spanish', 0)");
    raw.execute(
      "INSERT INTO vocabulary_categories VALUES (1, 'category-1', 1, 'Nouns', 0)",
    );
    raw.execute(
      "INSERT INTO vocabulary_subcategories VALUES (1, 'subcategory-1', 1, 'Nature', 0)",
    );
    raw.execute(
      "INSERT INTO vocabulary_words VALUES (1, 'word-1', 1, 1, 'árbol', 'tree', 0, 0, 0)",
    );
    raw.execute('PRAGMA user_version = 4');

    final database = AppDatabase(NativeDatabase.opened(raw));
    addTearDown(database.close);

    final category = await database
        .select(database.vocabularyCategories)
        .getSingle();
    final word = await database.select(database.vocabularyWords).getSingle();
    expect(category.name, 'Nouns');
    expect(word.languageId, 1);
    expect(word.categoryId, category.id);
    expect(word.subcategoryId, isNotNull);
  });
}
