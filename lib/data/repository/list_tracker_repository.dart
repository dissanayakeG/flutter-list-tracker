import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../transfer/csv_import_models.dart';
import '../transfer/export_snapshot.dart';

class ListWithCategory {
  const ListWithCategory({required this.list, required this.category});

  final ListModel list;
  final Category category;
}

/// The app-facing API for all local list-tracking data.
///
/// Keeping callers on this interface means a future sync implementation can
/// change storage details without changing the UI.
abstract interface class ListTrackerRepository {
  Stream<List<Category>> watchCategories();
  Future<List<Category>> getCategories();
  Future<Category?> getCategory(int id);
  Future<Category> createOrGetCategory({required String name});
  Future<bool> updateCategory({required int id, required String name});
  Future<bool> isCategoryInUse(int id);
  Future<bool> deleteCategory(int id);
  Future<ListTrackerExportSnapshot> getExportSnapshot();
  Future<CsvImportPreview> previewCsvImport(CsvImportDocument document);
  Future<CsvImportResult> importCsvEntries(CsvImportDocument document);

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

  Future<bool> updateList({
    required int id,
    required int categoryId,
    required String name,
    String? note,
  });

  Future<bool> deleteList(int id);
}

class DriftListTrackerRepository implements ListTrackerRepository {
  DriftListTrackerRepository(this._database);

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
    final normalizedName = _requiredText(name, 'name');

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
          CategoriesCompanion(name: Value(_requiredText(name, 'name'))),
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

  @override
  Future<ListTrackerExportSnapshot> getExportSnapshot() {
    return _database.transaction(() async {
      final categoryRows = await (_database.select(
        _database.categories,
      )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
      final listRows = await (_database.select(
        _database.listModels,
      )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
      final entryRows = await (_database.select(
        _database.entries,
      )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();

      final categoryNames = {
        for (final category in categoryRows) category.id: category.name,
      };
      final listsById = {for (final list in listRows) list.id: list};

      return ListTrackerExportSnapshot(
        categories: categoryRows
            .map((category) => ExportCategory(name: category.name))
            .toList(growable: false),
        lists: listRows
            .map(
              (list) => ExportList(
                categoryName: categoryNames[list.categoryId]!,
                name: list.name,
              ),
            )
            .toList(growable: false),
        entries: entryRows
            .map((entry) {
              final list = listsById[entry.listId]!;
              return ExportEntry(
                categoryName: categoryNames[list.categoryId]!,
                listName: list.name,
                content: entry.content,
                date: entry.date,
              );
            })
            .toList(growable: false),
      );
    });
  }

  @override
  Future<CsvImportPreview> previewCsvImport(CsvImportDocument document) {
    return _database.transaction(() async {
      final resolution = await _resolveCsvImport(document);
      return resolution.preview;
    });
  }

  @override
  Future<CsvImportResult> importCsvEntries(CsvImportDocument document) {
    return _database.transaction(() async {
      final resolution = await _resolveCsvImport(document);
      if (resolution.preview.hasBlockingReferences) {
        throw CsvImportPreflightException(resolution.preview);
      }

      final listIds = Map<CsvListReference, int>.from(resolution.listIds);
      var createdLists = 0;
      for (final reference in resolution.listsToCreate) {
        final listId = await _database
            .into(_database.listModels)
            .insert(
              ListModelsCompanion.insert(
                categoryId:
                    resolution.categoryIdsByName[reference.categoryName]!,
                name: reference.listName,
              ),
            );
        listIds[reference] = listId;
        createdLists += 1;
      }

      var addedEntries = 0;
      var skippedEntries = 0;
      for (final entry in document.entries) {
        final listId = listIds[entry.reference]!;
        final identity = (listId, entry.content, entry.date);
        if (resolution.existingEntryIdentities.contains(identity)) {
          skippedEntries += 1;
          continue;
        }

        await _database
            .into(_database.entries)
            .insert(
              EntriesCompanion.insert(
                listId: listId,
                content: entry.content,
                date: Value(entry.date),
              ),
            );
        addedEntries += 1;
      }

      return CsvImportResult(
        createdLists: createdLists,
        addedEntries: addedEntries,
        skippedEntries: skippedEntries,
      );
    });
  }

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
            name: _requiredText(name, 'name'),
            note: Value(_optionalText(note)),
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
      final category = await createOrGetCategory(name: categoryName);
      return createList(categoryId: category.id, name: name, note: note);
    });
  }

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
            content: _requiredText(content, 'content'),
            date: Value(_dateOnly(date)),
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
            content: Value(_requiredText(content, 'content')),
            date: Value(_dateOnly(date)),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return updatedRows == 1;
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
            name: Value(_requiredText(name, 'name')),
            note: Value(_optionalText(note)),
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

  @override
  Future<bool> deleteEntry(int id) async {
    final deletedRows = await (_database.delete(
      _database.entries,
    )..where((table) => table.id.equals(id))).go();
    return deletedRows == 1;
  }

  Future<_CsvImportResolution> _resolveCsvImport(
    CsvImportDocument document,
  ) async {
    final categoryRows = await _database.select(_database.categories).get();
    final listRows = await _database.select(_database.listModels).get();
    final categoriesByName = {
      for (final category in categoryRows) category.name: category,
    };
    final categoryIdsByName = {
      for (final category in categoryRows) category.name: category.id,
    };
    final missingCategories = <String>[];
    final listsToCreate = <CsvListReference>[];
    final ambiguousLists = <CsvListReference>[];
    final listIds = <CsvListReference, int>{};

    for (final categoryName in document.categoryNames) {
      if (!categoriesByName.containsKey(categoryName)) {
        missingCategories.add(categoryName);
      }
    }

    for (final reference in document.listReferences) {
      final category = categoriesByName[reference.categoryName];
      if (category == null) {
        continue;
      }
      final matchingLists = listRows
          .where(
            (list) =>
                list.categoryId == category.id &&
                list.name == reference.listName,
          )
          .toList(growable: false);
      if (matchingLists.isEmpty) {
        listsToCreate.add(reference);
      } else if (matchingLists.length > 1) {
        ambiguousLists.add(reference);
      } else {
        listIds[reference] = matchingLists.single.id;
      }
    }

    missingCategories.sort();
    listsToCreate.sort(_compareReferences);
    ambiguousLists.sort(_compareReferences);
    if (missingCategories.isNotEmpty || ambiguousLists.isNotEmpty) {
      return _CsvImportResolution(
        preview: CsvImportPreview(
          missingCategories: List.unmodifiable(missingCategories),
          listsToCreate: List.unmodifiable(listsToCreate),
          ambiguousLists: List.unmodifiable(ambiguousLists),
          entriesToAdd: 0,
          entriesToSkip: 0,
        ),
        listIds: Map.unmodifiable(listIds),
        categoryIdsByName: Map.unmodifiable(categoryIdsByName),
        listsToCreate: List.unmodifiable(listsToCreate),
        existingEntryIdentities: const {},
      );
    }

    final entryRows = await _database.select(_database.entries).get();
    final existingEntryIdentities = <_EntryIdentity>{
      for (final entry in entryRows) (entry.listId, entry.content, entry.date),
    };
    var entriesToSkip = 0;
    for (final entry in document.entries) {
      final listId = listIds[entry.reference];
      if (listId != null &&
          existingEntryIdentities.contains((
            listId,
            entry.content,
            entry.date,
          ))) {
        entriesToSkip += 1;
      }
    }

    return _CsvImportResolution(
      preview: CsvImportPreview(
        missingCategories: const [],
        listsToCreate: List.unmodifiable(listsToCreate),
        ambiguousLists: const [],
        entriesToAdd: document.entries.length - entriesToSkip,
        entriesToSkip: entriesToSkip,
      ),
      listIds: Map.unmodifiable(listIds),
      categoryIdsByName: Map.unmodifiable(categoryIdsByName),
      listsToCreate: List.unmodifiable(listsToCreate),
      existingEntryIdentities: Set.unmodifiable(existingEntryIdentities),
    );
  }

  int _compareReferences(CsvListReference first, CsvListReference second) {
    final categoryComparison = first.categoryName.compareTo(
      second.categoryName,
    );
    if (categoryComparison != 0) {
      return categoryComparison;
    }
    return first.listName.compareTo(second.listName);
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

  String _requiredText(String value, String fieldName) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw ArgumentError.value(value, fieldName, 'must not be blank');
    }
    return normalizedValue;
  }

  String? _optionalText(String? value) {
    final normalizedValue = value?.trim();
    return normalizedValue == null || normalizedValue.isEmpty
        ? null
        : normalizedValue;
  }

  DateTime? _dateOnly(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }
}

typedef _EntryIdentity = (int, String, DateTime?);

class _CsvImportResolution {
  const _CsvImportResolution({
    required this.preview,
    required this.listIds,
    required this.categoryIdsByName,
    required this.listsToCreate,
    required this.existingEntryIdentities,
  });

  final CsvImportPreview preview;
  final Map<CsvListReference, int> listIds;
  final Map<String, int> categoryIdsByName;
  final List<CsvListReference> listsToCreate;
  final Set<_EntryIdentity> existingEntryIdentities;
}
