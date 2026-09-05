import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'repository_validation.dart';

abstract interface class EntryRepository {
  Stream<List<Entry>> watchEntries(int listId);
  Future<Entry> createEntry({
    required int listId,
    required String content,
    DateTime? date,
  });
  Future<bool> updateEntry({
    required int id,
    required String content,
    required DateTime? date,
  });
  Future<bool> deleteEntry(int id);
}

class DriftEntryRepository implements EntryRepository {
  DriftEntryRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Entry>> watchEntries(int listId) {
    final query = _database.select(_database.entries)
      ..where((table) => table.listId.equals(listId))
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return query.watch();
  }

  @override
  Future<Entry> createEntry({
    required int listId,
    required String content,
    DateTime? date,
  }) async {
    final id = await _database
        .into(_database.entries)
        .insert(
          EntriesCompanion.insert(
            listId: listId,
            content: requiredText(content, 'content'),
            date: Value(dateOnly(date)),
          ),
        );
    return (_database.select(
      _database.entries,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  @override
  Future<bool> updateEntry({
    required int id,
    required String content,
    required DateTime? date,
  }) async {
    final updatedRows =
        await (_database.update(
          _database.entries,
        )..where((table) => table.id.equals(id))).write(
          EntriesCompanion(
            content: Value(requiredText(content, 'content')),
            date: Value(dateOnly(date)),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return updatedRows == 1;
  }

  @override
  Future<bool> deleteEntry(int id) async {
    final deletedRows = await (_database.delete(
      _database.entries,
    )..where((table) => table.id.equals(id))).go();
    return deletedRows == 1;
  }
}
