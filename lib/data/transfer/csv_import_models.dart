class CsvListReference {
  const CsvListReference({required this.categoryName, required this.listName});

  final String categoryName;
  final String listName;

  String get displayName => '$categoryName > $listName';

  @override
  bool operator ==(Object other) {
    return other is CsvListReference &&
        other.categoryName == categoryName &&
        other.listName == listName;
  }

  @override
  int get hashCode => Object.hash(categoryName, listName);
}

class CsvImportEntry {
  const CsvImportEntry({
    required this.reference,
    required this.content,
    required this.date,
  });

  final CsvListReference reference;
  final String content;
  final DateTime? date;
}

/// The validated, user-facing contents of one List Tracker CSV file.
class CsvImportDocument {
  const CsvImportDocument({
    required this.categoryNames,
    required this.listReferences,
    required this.entries,
  });

  final List<String> categoryNames;
  final List<CsvListReference> listReferences;
  final List<CsvImportEntry> entries;
}

/// The named local records and changes shown before import is confirmed.
class CsvImportPreview {
  const CsvImportPreview({
    required this.missingCategories,
    required this.listsToCreate,
    required this.ambiguousLists,
    required this.entriesToAdd,
    required this.entriesToSkip,
  });

  final List<String> missingCategories;
  final List<CsvListReference> listsToCreate;
  final List<CsvListReference> ambiguousLists;
  final int entriesToAdd;
  final int entriesToSkip;

  bool get hasBlockingReferences {
    return missingCategories.isNotEmpty || ambiguousLists.isNotEmpty;
  }
}

class CsvImportResult {
  const CsvImportResult({
    required this.createdLists,
    required this.addedEntries,
    required this.skippedEntries,
  });

  final int createdLists;
  final int addedEntries;
  final int skippedEntries;
}

class CsvImportFormatException implements Exception {
  const CsvImportFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when references changed after preview but before confirmation.
class CsvImportPreflightException implements Exception {
  const CsvImportPreflightException(this.preview);

  final CsvImportPreview preview;
}
