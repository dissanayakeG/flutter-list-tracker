/// Repository-owned, human-readable data required by CSV export.
///
/// Local SQLite IDs and internal UUIDs stay inside the repository and do not
/// appear in these export models.
class ListTrackerExportSnapshot {
  ListTrackerExportSnapshot({
    required Iterable<ExportCategory> categories,
    required Iterable<ExportList> lists,
    required Iterable<ExportEntry> entries,
  }) : categories = List.unmodifiable(categories),
       lists = List.unmodifiable(lists),
       entries = List.unmodifiable(entries);

  final List<ExportCategory> categories;
  final List<ExportList> lists;
  final List<ExportEntry> entries;
}

class ExportCategory {
  const ExportCategory({required this.name});

  final String name;
}

class ExportList {
  const ExportList({required this.categoryName, required this.name});

  final String categoryName;
  final String name;
}

class ExportEntry {
  const ExportEntry({
    required this.categoryName,
    required this.listName,
    required this.content,
    required this.date,
  });

  final String categoryName;
  final String listName;
  final String content;
  final DateTime? date;
}
