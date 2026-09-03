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

@DriftDatabase(tables: [Categories, ListModels, Entries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'list_tracker'));

  @override
  int get schemaVersion => 3;

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
        });
      } finally {
        await customStatement('PRAGMA foreign_keys = ON');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
