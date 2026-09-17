import 'package:drift/drift.dart';

import 'package:list_tracker/core/database/app_database.dart';

abstract interface class PreferenceRepository {
  Stream<String> watchThemeMode();
  Future<void> saveThemeMode(String value);
}

class DriftPreferenceRepository implements PreferenceRepository {
  DriftPreferenceRepository(this._database);
  final AppDatabase _database;

  @override
  Stream<String> watchThemeMode() {
    final query = _database.select(_database.appPreferences)
      ..where((table) => table.id.equals(1));
    return query.watchSingleOrNull().map((row) => row?.themeMode ?? 'dark');
  }

  @override
  Future<void> saveThemeMode(String value) => _database
      .into(_database.appPreferences)
      .insertOnConflictUpdate(
        AppPreferencesCompanion.insert(id: Value(1), themeMode: Value(value)),
      );
}
