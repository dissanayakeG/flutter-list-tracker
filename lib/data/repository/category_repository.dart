import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'repository_validation.dart';

abstract interface class CategoryRepository {
  Stream<List<Category>> watchCategories();
  Future<List<Category>> getCategories();
  Future<Category?> getCategory(int id);
  Future<Category> createOrGetCategory({required String name});
  Future<bool> updateCategory({required int id, required String name});
  Future<bool> isCategoryInUse(int id);
  Future<bool> deleteCategory(int id);
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Category>> watchCategories() {
    final query = _database.select(_database.categories)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  @override
  Future<List<Category>> getCategories() {
    final query = _database.select(_database.categories)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.get();
  }

  @override
  Future<Category?> getCategory(int id) {
    return (_database.select(
      _database.categories,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<Category> createOrGetCategory({required String name}) {
    final normalizedName = requiredText(name, 'name');

    return _database.transaction(() async {
      final existing = await (_database.select(
        _database.categories,
      )..where((table) => table.name.equals(normalizedName))).getSingleOrNull();
      if (existing != null) {
        return existing;
      }

      final id = await _database
          .into(_database.categories)
          .insert(CategoriesCompanion.insert(name: normalizedName));
      return (_database.select(
        _database.categories,
      )..where((table) => table.id.equals(id))).getSingle();
    });
  }

  @override
  Future<bool> updateCategory({required int id, required String name}) async {
    final updatedRows =
        await (_database.update(
          _database.categories,
        )..where((table) => table.id.equals(id))).write(
          CategoriesCompanion(name: Value(requiredText(name, 'name'))),
        );
    return updatedRows == 1;
  }

  @override
  Future<bool> isCategoryInUse(int id) async {
    final list = await (_database.select(
      _database.listModels,
    )..where((table) => table.categoryId.equals(id))).getSingleOrNull();
    return list != null;
  }

  @override
  Future<bool> deleteCategory(int id) async {
    if (await isCategoryInUse(id)) {
      return false;
    }

    final deletedRows = await (_database.delete(
      _database.categories,
    )..where((table) => table.id.equals(id))).go();
    return deletedRows == 1;
  }
}
