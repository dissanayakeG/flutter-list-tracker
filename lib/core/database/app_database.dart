import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/*
Look at these table classes:
Categories, ListModels, Entries

Then generate:
app_database.g.dart
*/

@DriftDatabase(
  tables: [
    Categories,
    ListModels,
    Entries,
    Languages,
    VocabularyCategories,
    VocabularySubcategories,
    VocabularyWords,
    AppPreferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'list_tracker'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      await customStatement('PRAGMA foreign_keys = OFF');
      try {
        await transaction(() async {
          //if the old database is version 1, add the date column introduced in version 2.
          if (from < 2) {
            await migrator.addColumn(entries, entries.date);
          }

          //if the old database is version 1 or 2, add the UUID externalId columns introduced in version 3.
          if (from < 3) {
            await _addExternalIds(migrator);
          }

          if (from < 4) {
            await migrator.createTable(languages);
            await migrator.createTable(vocabularyCategories);
            await migrator.createTable(vocabularySubcategories);
            await migrator.createTable(vocabularyWords);
            await _createVocabularyIntegrityTriggers();
          }

          if (from < 5 && from >= 4) {
            await _migrateVocabularyTaxonomy(migrator);
          }
          if (from < 6) {
            await migrator.createTable(appPreferences);
          }
        });
      } finally {
        await customStatement('PRAGMA foreign_keys = ON');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createVocabularyIntegrityTriggers();
    },
  );

  Future<void> _createVocabularyIntegrityTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS vocabulary_words_validate_subcategory_insert
      BEFORE INSERT ON vocabulary_words
      WHEN NEW.subcategory_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM vocabulary_subcategories
          WHERE id = NEW.subcategory_id AND category_id = NEW.category_id
        )
      BEGIN
        SELECT RAISE(ABORT, 'Vocabulary subcategory must belong to its category.');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS vocabulary_words_validate_subcategory_update
      BEFORE UPDATE OF category_id, subcategory_id ON vocabulary_words
      WHEN NEW.subcategory_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM vocabulary_subcategories
          WHERE id = NEW.subcategory_id AND category_id = NEW.category_id
        )
      BEGIN
        SELECT RAISE(ABORT, 'Vocabulary subcategory must belong to its category.');
      END
    ''');
  }

  Future<void> _migrateVocabularyTaxonomy(Migrator migrator) async {
    // v4 categories were duplicated for each language. v5 shares grammar
    // categories and records the language on each word instead.
    await customStatement(
      'DROP TRIGGER IF EXISTS vocabulary_words_validate_subcategory_insert',
    );
    await customStatement(
      'DROP TRIGGER IF EXISTS vocabulary_words_validate_subcategory_update',
    );
    await customStatement(
      'ALTER TABLE vocabulary_words RENAME TO vocabulary_words_v4',
    );
    await customStatement(
      'ALTER TABLE vocabulary_subcategories RENAME TO vocabulary_subcategories_v4',
    );
    await customStatement(
      'ALTER TABLE vocabulary_categories RENAME TO vocabulary_categories_v4',
    );

    await migrator.createTable(vocabularyCategories);
    await migrator.createTable(vocabularySubcategories);
    await migrator.createTable(vocabularyWords);

    await customStatement('''
      INSERT INTO vocabulary_categories (external_id, name, created_at)
      SELECT external_id, name, created_at
      FROM vocabulary_categories_v4
      GROUP BY name
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO vocabulary_subcategories
        (external_id, category_id, name, created_at)
      SELECT old_subcategory.external_id, category.id,
             old_subcategory.name, old_subcategory.created_at
      FROM vocabulary_subcategories_v4 AS old_subcategory
      JOIN vocabulary_categories_v4 AS old_category
        ON old_category.id = old_subcategory.category_id
      JOIN vocabulary_categories AS category
        ON category.name = old_category.name
    ''');
    await customStatement('''
      INSERT INTO vocabulary_words
        (external_id, language_id, category_id, subcategory_id, word, meaning,
         is_completed, created_at, updated_at)
      SELECT old_word.external_id, old_category.language_id, category.id,
             new_subcategory.id, old_word.word, old_word.meaning,
             old_word.is_completed, old_word.created_at, old_word.updated_at
      FROM vocabulary_words_v4 AS old_word
      JOIN vocabulary_categories_v4 AS old_category
        ON old_category.id = old_word.category_id
      JOIN vocabulary_categories AS category
        ON category.name = old_category.name
      LEFT JOIN vocabulary_subcategories_v4 AS old_subcategory
        ON old_subcategory.id = old_word.subcategory_id
      LEFT JOIN vocabulary_subcategories AS new_subcategory
        ON new_subcategory.category_id = category.id
       AND new_subcategory.name = old_subcategory.name
    ''');
    await customStatement('DROP TABLE vocabulary_words_v4');
    await customStatement('DROP TABLE vocabulary_subcategories_v4');
    await customStatement('DROP TABLE vocabulary_categories_v4');
  }

  Future<void> _addExternalIds(Migrator migrator) async {
    await migrator.alterTable(
      TableMigration(
        categories,
        newColumns: [categories.externalId],
        columnTransformer: {
          categories.externalId: CustomExpression<String>(_sqliteUuidV4),
        },
      ),
    );
    await migrator.alterTable(
      TableMigration(
        listModels,
        newColumns: [listModels.externalId],
        columnTransformer: {
          listModels.externalId: CustomExpression<String>(_sqliteUuidV4),
        },
      ),
    );
    await migrator.alterTable(
      TableMigration(
        entries,
        newColumns: [entries.externalId],
        columnTransformer: {
          entries.externalId: CustomExpression<String>(_sqliteUuidV4),
        },
      ),
    );
  }
}

const _sqliteUuidV4 =
    "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || "
    "'-4' || substr(lower(hex(randomblob(2))), 2) || '-' || "
    "substr('89ab', (random() & 3) + 1, 1) || "
    "substr(lower(hex(randomblob(2))), 2) || '-' || "
    "lower(hex(randomblob(6)))";
