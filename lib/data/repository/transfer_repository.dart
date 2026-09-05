import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../transfer/csv_import_models.dart';
import '../transfer/export_snapshot.dart';
import 'repository_validation.dart';

abstract interface class TransferRepository {
  Future<ListTrackerExportSnapshot> getExportSnapshot();
  Future<CsvImportPreview> previewCsvImport(CsvImportDocument document);
  Future<CsvImportResult> importCsvEntries(CsvImportDocument document);
}

class DriftTransferRepository implements TransferRepository {
  DriftTransferRepository(this._database);

  final AppDatabase _database;

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

  Future<_CsvImportResolution> _resolveCsvImport(
    CsvImportDocument document,
  ) async {
    _validateCsvDocument(document);
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

  void _validateCsvDocument(CsvImportDocument document) {
    if (document.entries.length > maxCsvImportDataRows) {
      throw const CsvImportFormatException(
        'The CSV file contains too many data rows. The maximum is 10,000.',
      );
    }

    for (final categoryName in document.categoryNames) {
      _validateRequiredImportText(
        categoryName,
        fieldName: 'category',
        maxLength: categoryNameMaxLength,
      );
    }
    for (final reference in document.listReferences) {
      _validateRequiredImportText(
        reference.categoryName,
        fieldName: 'category',
        maxLength: categoryNameMaxLength,
      );
      _validateRequiredImportText(
        reference.listName,
        fieldName: 'list',
        maxLength: listNameMaxLength,
      );
    }
    for (final entry in document.entries) {
      _validateRequiredImportText(
        entry.content,
        fieldName: 'entry',
        maxLength: entryContentMaxLength,
        allowLineBreaks: true,
      );
      if (entry.date != null) {
        try {
          dateOnly(entry.date);
        } on ArgumentError catch (error) {
          throw CsvImportFormatException(
            error.message?.toString() ?? 'Invalid date.',
          );
        }
      }
    }
  }

  void _validateRequiredImportText(
    String value, {
    required String fieldName,
    required int maxLength,
    bool allowLineBreaks = false,
  }) {
    try {
      normalizeRequiredText(
        value,
        fieldName: fieldName,
        maxLength: maxLength,
        allowLineBreaks: allowLineBreaks,
      );
    } on InputValidationException catch (error) {
      throw CsvImportFormatException(
        'The CSV document has an invalid $fieldName: ${error.message}',
      );
    }
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
