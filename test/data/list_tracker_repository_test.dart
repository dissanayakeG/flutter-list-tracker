import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/list_tracker_repository.dart';
import 'package:list_tracker/data/transfer/csv_export_service.dart';
import 'package:list_tracker/data/transfer/csv_import_models.dart';

void main() {
  late AppDatabase database;
  late DriftListTrackerRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftListTrackerRepository(database);
  });

  tearDown(() => database.close());

  test('creates and reuses normalized categories', () async {
    final first = await repository.createOrGetCategory(name: ' Meal Plans ');
    final second = await repository.createOrGetCategory(name: 'Meal Plans');

    expect(second.id, first.id);
    expect(second.name, 'Meal Plans');
    expect(await repository.getCategories(), [first]);
  });

  test(
    'creates a list with its category and exposes the joined summary',
    () async {
      final list = await repository.createListInCategory(
        categoryName: 'Exercise Routines',
        name: 'Morning mobility',
        note: ' 15 minutes ',
      );

      final summary = await repository.watchList(list.id).first;
      final allLists = await repository.watchLists().first;

      expect(summary, isNotNull);
      expect(summary!.category.name, 'Exercise Routines');
      expect(summary.list.name, 'Morning mobility');
      expect(summary.list.note, '15 minutes');
      expect(allLists.single.list, summary.list);
    },
  );

  test('updates a list name, note, and category', () async {
    final reading = await repository.createOrGetCategory(name: 'Reading');
    final plans = await repository.createOrGetCategory(name: 'Plans');
    final list = await repository.createList(
      categoryId: reading.id,
      name: 'Books to finish',
      note: 'This month',
    );

    expect(
      await repository.updateList(
        id: list.id,
        categoryId: plans.id,
        name: '  Weekend plans ',
        note: '  Plan ahead ',
      ),
      isTrue,
    );

    final updated = await repository.watchList(list.id).first;
    expect(updated!.category.id, plans.id);
    expect(updated.list.name, 'Weekend plans');
    expect(updated.list.note, 'Plan ahead');
    expect(
      await repository.updateList(
        id: 999,
        categoryId: plans.id,
        name: 'Missing',
      ),
      isFalse,
    );
  });

  test(
    'keeps UUIDs internal and creates a human-readable export snapshot',
    () async {
      final list = await repository.createListInCategory(
        categoryName: 'Meal Plans',
        name: 'Weekday meals',
        note: 'Quick recipes',
      );
      final entry = await repository.createEntry(
        listId: list.id,
        content: 'Soup and salad',
        date: DateTime(2026, 3, 15),
      );

      final category = (await repository.getCategories()).single;
      final snapshot = await repository.getExportSnapshot();

      expect(category.externalId, isNotEmpty);
      expect(list.externalId, isNotEmpty);
      expect(entry.externalId, isNotEmpty);
      expect(snapshot.categories, hasLength(1));
      expect(snapshot.lists, hasLength(1));
      expect(snapshot.entries, hasLength(1));
      expect(snapshot.categories.single.name, category.name);
      expect(snapshot.lists.single.categoryName, category.name);
      expect(snapshot.lists.single.name, list.name);
      expect(snapshot.entries.single.categoryName, category.name);
      expect(snapshot.entries.single.listName, list.name);
      expect(snapshot.entries.single.content, 'Soup and salad');
      expect(snapshot.entries.single.date, DateTime(2026, 3, 15));

      final csv = const CsvExportEncoder().encode(snapshot);
      expect(csv, isNot(contains('Quick recipes')));
      expect(csv, isNot(contains(category.externalId)));
      expect(csv, isNot(contains(list.externalId)));
      expect(csv, isNot(contains(entry.externalId)));
      expect(csv, isNot(contains(entry.createdAt.toUtc().toIso8601String())));
      expect(csv, isNot(contains(entry.updatedAt.toUtc().toIso8601String())));
    },
  );

  test('updates and deletes an entry', () async {
    final list = await repository.createListInCategory(
      categoryName: 'Reading',
      name: 'Books to finish',
    );
    final entry = await repository.createEntry(
      listId: list.id,
      content: '  The Left Hand of Darkness ',
      date: DateTime(2026, 3, 15, 18),
    );

    expect(entry.content, 'The Left Hand of Darkness');
    expect(entry.date, DateTime(2026, 3, 15));
    expect(
      await repository.updateEntry(
        id: entry.id,
        content: 'Finished reading',
        date: null,
      ),
      isTrue,
    );

    final updatedEntry = (await repository.watchEntries(list.id).first).single;
    expect(updatedEntry.content, 'Finished reading');
    expect(updatedEntry.date, isNull);
    expect(
      updatedEntry.updatedAt.isAfter(entry.updatedAt) ||
          updatedEntry.updatedAt.isAtSameMomentAs(entry.updatedAt),
      isTrue,
    );

    expect(await repository.deleteEntry(entry.id), isTrue);
    expect(await repository.watchEntries(list.id).first, isEmpty);
  });

  test(
    'blocks missing categories without creating other proposed lists',
    () async {
      final reading = await repository.createOrGetCategory(name: 'Reading');
      final books = await repository.createList(
        categoryId: reading.id,
        name: 'Books',
      );
      await repository.createOrGetCategory(name: 'Meals');
      final document = CsvImportDocument(
        categoryNames: const ['Fitness', 'Meals', 'Reading'],
        listReferences: const [
          CsvListReference(categoryName: 'Reading', listName: 'Books'),
          CsvListReference(categoryName: 'Meals', listName: 'Weekday'),
        ],
        entries: const [
          CsvImportEntry(
            reference: CsvListReference(
              categoryName: 'Reading',
              listName: 'Books',
            ),
            content: 'Read a chapter',
            date: null,
          ),
        ],
      );

      final preview = await repository.previewCsvImport(document);

      expect(preview.missingCategories, ['Fitness']);
      expect(preview.listsToCreate, const [
        CsvListReference(categoryName: 'Meals', listName: 'Weekday'),
      ]);
      expect(preview.ambiguousLists, isEmpty);
      expect(preview.hasBlockingReferences, isTrue);
      await expectLater(
        repository.importCsvEntries(document),
        throwsA(isA<CsvImportPreflightException>()),
      );
      expect(await repository.getCategories(), hasLength(2));
      expect(await repository.watchEntries(books.id).first, isEmpty);
    },
  );

  test(
    'creates confirmed lists under their categories and preserves empty lists',
    () async {
      final meals = await repository.createOrGetCategory(name: 'Meals');
      final errands = await repository.createOrGetCategory(name: 'Errands');
      await repository.createList(categoryId: errands.id, name: 'Weekday');
      final document = CsvImportDocument(
        categoryNames: const ['Meals'],
        listReferences: const [
          CsvListReference(categoryName: 'Meals', listName: 'Weekday'),
          CsvListReference(categoryName: 'Meals', listName: 'Someday'),
        ],
        entries: [
          CsvImportEntry(
            reference: const CsvListReference(
              categoryName: 'Meals',
              listName: 'Weekday',
            ),
            content: 'Make soup',
            date: DateTime(2026, 3, 15),
          ),
        ],
      );

      final preview = await repository.previewCsvImport(document);
      final result = await repository.importCsvEntries(document);
      final summaries = await repository.watchLists().first;
      final weekday = summaries.singleWhere(
        (summary) =>
            summary.category.id == meals.id && summary.list.name == 'Weekday',
      );
      final someday = summaries.singleWhere(
        (summary) =>
            summary.category.id == meals.id && summary.list.name == 'Someday',
      );

      expect(preview.hasBlockingReferences, isFalse);
      expect(preview.listsToCreate.map((item) => item.displayName), [
        'Meals > Someday',
        'Meals > Weekday',
      ]);
      expect(preview.entriesToAdd, 1);
      expect(result.createdLists, 2);
      expect(result.addedEntries, 1);
      expect(
        (await repository.watchEntries(weekday.list.id).first).single.content,
        'Make soup',
      );
      expect(await repository.watchEntries(someday.list.id).first, isEmpty);

      final retryPreview = await repository.previewCsvImport(document);
      final retryResult = await repository.importCsvEntries(document);

      expect(retryPreview.listsToCreate, isEmpty);
      expect(retryPreview.entriesToAdd, 0);
      expect(retryPreview.entriesToSkip, 1);
      expect(retryResult.createdLists, 0);
      expect(retryResult.addedEntries, 0);
      expect(retryResult.skippedEntries, 1);
    },
  );

  test('resolves same-named lists within their own categories', () async {
    final reading = await repository.createOrGetCategory(name: 'Reading');
    final travel = await repository.createOrGetCategory(name: 'Travel');
    await repository.createList(categoryId: reading.id, name: 'Books');
    final travelBooks = await repository.createList(
      categoryId: travel.id,
      name: 'Books',
    );
    final document = CsvImportDocument(
      categoryNames: const ['Travel'],
      listReferences: const [
        CsvListReference(categoryName: 'Travel', listName: 'Books'),
      ],
      entries: [
        CsvImportEntry(
          reference: const CsvListReference(
            categoryName: 'Travel',
            listName: 'Books',
          ),
          content: 'Pack a guidebook',
          date: DateTime(2026, 3, 15),
        ),
      ],
    );

    final preview = await repository.previewCsvImport(document);
    final result = await repository.importCsvEntries(document);

    expect(preview.hasBlockingReferences, isFalse);
    expect(preview.entriesToAdd, 1);
    expect(result.createdLists, 0);
    expect(result.addedEntries, 1);
    expect(
      (await repository.watchEntries(travelBooks.id).first).single.content,
      'Pack a guidebook',
    );
  });

  test('blocks ambiguous lists without changing any entries', () async {
    final reading = await repository.createOrGetCategory(name: 'Reading');
    final firstBooks = await repository.createList(
      categoryId: reading.id,
      name: 'Books',
    );
    await repository.createList(categoryId: reading.id, name: 'Books');
    final document = CsvImportDocument(
      categoryNames: const ['Reading'],
      listReferences: const [
        CsvListReference(categoryName: 'Reading', listName: 'Books'),
      ],
      entries: const [
        CsvImportEntry(
          reference: CsvListReference(
            categoryName: 'Reading',
            listName: 'Books',
          ),
          content: 'Read a chapter',
          date: null,
        ),
      ],
    );

    final preview = await repository.previewCsvImport(document);

    expect(preview.ambiguousLists.single.displayName, 'Reading > Books');
    await expectLater(
      repository.importCsvEntries(document),
      throwsA(isA<CsvImportPreflightException>()),
    );
    expect(await repository.watchEntries(firstBooks.id).first, isEmpty);
  });

  test(
    'skips exact existing entries so import retries are idempotent',
    () async {
      final reading = await repository.createOrGetCategory(name: 'Reading');
      final books = await repository.createList(
        categoryId: reading.id,
        name: 'Books',
      );
      await repository.createEntry(
        listId: books.id,
        content: 'Already tracked',
        date: DateTime(2026, 3, 15),
      );
      final unrelated = await repository.createListInCategory(
        categoryName: 'Meals',
        name: 'Weekday',
      );
      await repository.createEntry(
        listId: unrelated.id,
        content: 'Keep this entry',
        date: null,
      );
      final document = CsvImportDocument(
        categoryNames: const ['Reading'],
        listReferences: const [
          CsvListReference(categoryName: 'Reading', listName: 'Books'),
        ],
        entries: [
          CsvImportEntry(
            reference: const CsvListReference(
              categoryName: 'Reading',
              listName: 'Books',
            ),
            content: 'Already tracked',
            date: DateTime(2026, 3, 15),
          ),
          CsvImportEntry(
            reference: const CsvListReference(
              categoryName: 'Reading',
              listName: 'Books',
            ),
            content: 'New chapter',
            date: null,
          ),
        ],
      );

      final firstPreview = await repository.previewCsvImport(document);
      final firstResult = await repository.importCsvEntries(document);
      final retryPreview = await repository.previewCsvImport(document);
      final retryResult = await repository.importCsvEntries(document);

      expect(firstPreview.entriesToAdd, 1);
      expect(firstPreview.entriesToSkip, 1);
      expect(firstResult.createdLists, 0);
      expect(firstResult.addedEntries, 1);
      expect(firstResult.skippedEntries, 1);
      expect(retryPreview.entriesToAdd, 0);
      expect(retryPreview.entriesToSkip, 2);
      expect(retryResult.createdLists, 0);
      expect(retryResult.addedEntries, 0);
      expect(retryResult.skippedEntries, 2);
      expect(await repository.watchEntries(books.id).first, hasLength(2));
      expect(
        (await repository.watchEntries(unrelated.id).first).single.content,
        'Keep this entry',
      );
    },
  );

  test('rejects blank required values', () {
    expect(
      () => repository.createOrGetCategory(name: '  '),
      throwsArgumentError,
    );
    expect(
      () => repository.createList(categoryId: 1, name: ' '),
      throwsArgumentError,
    );
    expect(
      () => repository.createEntry(listId: 1, content: ''),
      throwsArgumentError,
    );
  });
}
