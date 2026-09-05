import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'category_repository.dart';
import 'repository_validation.dart';

class ListWithCategory {
  const ListWithCategory({required this.list, required this.category});

  final ListModel list;
  final Category category;
}

abstract interface class ListRepository {
  Stream<List<ListWithCategory>> watchLists();
  Stream<ListWithCategory?> watchList(int id);
  Future<ListModel?> getList(int id);
  Future<ListModel> createList({
    required int categoryId,
    required String name,
    String? note,
  });
  Future<ListModel> createListInCategory({
    required String categoryName,
    required String name,
    String? note,
  });
  Future<bool> updateList({
    required int id,
    required int categoryId,
    required String name,
    String? note,
  });
  Future<bool> deleteList(int id);
}

class DriftListRepository implements ListRepository {
  DriftListRepository(this._database, this._categoryRepository);

  final AppDatabase _database;
  final CategoryRepository _categoryRepository;

  @override
  Stream<List<ListWithCategory>> watchLists() {
    final query = _listWithCategoryQuery()
      ..orderBy([OrderingTerm.desc(_database.listModels.createdAt)]);
    return query.watch().map(_mapListsWithCategories);
  }

  @override
  Stream<ListWithCategory?> watchList(int id) {
    final query = _listWithCategoryQuery()
      ..where(_database.listModels.id.equals(id));
    return query.watch().map((rows) {
      if (rows.isEmpty) {
        return null;
      }
      return _mapListWithCategory(rows.single);
    });
  }

  @override
  Future<ListModel?> getList(int id) {
    return (_database.select(
      _database.listModels,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<ListModel> createList({
    required int categoryId,
    required String name,
    String? note,
  }) async {
    final id = await _database
        .into(_database.listModels)
        .insert(
          ListModelsCompanion.insert(
            categoryId: categoryId,
            name: requiredText(name, 'name'),
            note: Value(optionalText(note)),
          ),
        );
    return (_database.select(
      _database.listModels,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  @override
  Future<ListModel> createListInCategory({
    required String categoryName,
    required String name,
    String? note,
  }) {
    return _database.transaction(() async {
      final category = await _categoryRepository.createOrGetCategory(
        name: categoryName,
      );
      return createList(categoryId: category.id, name: name, note: note);
    });
  }

  @override
  Future<bool> updateList({
    required int id,
    required int categoryId,
    required String name,
    String? note,
  }) async {
    final updatedRows =
        await (_database.update(
          _database.listModels,
        )..where((table) => table.id.equals(id))).write(
          ListModelsCompanion(
            categoryId: Value(categoryId),
            name: Value(requiredText(name, 'name')),
            note: Value(optionalText(note)),
          ),
        );
    return updatedRows == 1;
  }

  @override
  Future<bool> deleteList(int id) async {
    final deletedRows = await (_database.delete(
      _database.listModels,
    )..where((table) => table.id.equals(id))).go();
    return deletedRows == 1;
  }

  JoinedSelectStatement _listWithCategoryQuery() {
    return _database.select(_database.listModels).join([
      innerJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.listModels.categoryId),
      ),
    ]);
  }

  List<ListWithCategory> _mapListsWithCategories(List<TypedResult> rows) {
    return rows.map(_mapListWithCategory).toList(growable: false);
  }

  ListWithCategory _mapListWithCategory(TypedResult row) {
    return ListWithCategory(
      list: row.readTable(_database.listModels),
      category: row.readTable(_database.categories),
    );
  }
}
