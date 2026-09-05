import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/category_repository.dart';
import 'package:list_tracker/data/repository/entry_repository.dart';
import 'package:list_tracker/data/repository/list_repository.dart';
import 'package:list_tracker/data/repository/transfer_repository.dart';
import 'package:list_tracker/data/transfer/csv_export_service.dart';
import 'package:list_tracker/data/transfer/csv_import_models.dart';

void main() {
  late AppDatabase database;
  late DriftCategoryRepository categoryRepository;
  late DriftListRepository listRepository;
  late DriftEntryRepository entryRepository;
  late DriftTransferRepository transferRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    categoryRepository = DriftCategoryRepository(database);
    listRepository = DriftListRepository(database, categoryRepository);
    entryRepository = DriftEntryRepository(database);
    transferRepository = DriftTransferRepository(database);
  });

  tearDown(() => database.close());

  test(
    'keeps UUIDs internal and creates a human-readable export snapshot',
    () async {
      final list = await listRepository.createListInCategory(
        categoryName: 'Meal Plans',
        name: 'Weekday meals',
        note: 'Quick recipes',
      );
      final entry = await entryRepository.createEntry(
        listId: list.id,
        content: 'Soup and salad',
        date: DateTime(2026, 3, 15),
      );

      final category = (await categoryRepository.getCategories()).single;
      final snapshot = await transferRepository.getExportSnapshot();

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

  test(
    'blocks missing categories without creating other proposed lists',
    () async {
      final reading = await categoryRepository.createOrGetCategory(
        name: 'Reading',
      );
      final books = await listRepository.createList(
        categoryId: reading.id,
        name: 'Books',
      );
      await categoryRepository.createOrGetCategory(name: 'Meals');
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

      final preview = await transferRepository.previewCsvImport(document);

      expect(preview.missingCategories, ['Fitness']);
      expect(preview.listsToCreate, const [
        CsvListReference(categoryName: 'Meals', listName: 'Weekday'),
      ]);
      expect(preview.ambiguousLists, isEmpty);
      expect(preview.hasBlockingReferences, isTrue);
      await expectLater(
        transferRepository.importCsvEntries(document),
        throwsA(isA<CsvImportPreflightException>()),
      );
      expect(await categoryRepository.getCategories(), hasLength(2));
      expect(await entryRepository.watchEntries(books.id).first, isEmpty);
    },
  );

  test(
    'creates confirmed lists under their categories and preserves empty lists',
    () async {
      final meals = await categoryRepository.createOrGetCategory(name: 'Meals');
      final errands = await categoryRepository.createOrGetCategory(
        name: 'Errands',
      );
      await listRepository.createList(categoryId: errands.id, name: 'Weekday');
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

      final preview = await transferRepository.previewCsvImport(document);
      final result = await transferRepository.importCsvEntries(document);
      final summaries = await listRepository.watchLists().first;
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
        (await entryRepository.watchEntries(weekday.list.id).first)
            .single
            .content,
        'Make soup',
      );
      expect(
        await entryRepository.watchEntries(someday.list.id).first,
        isEmpty,
      );

      final retryPreview = await transferRepository.previewCsvImport(document);
      final retryResult = await transferRepository.importCsvEntries(document);

      expect(retryPreview.listsToCreate, isEmpty);
      expect(retryPreview.entriesToAdd, 0);
      expect(retryPreview.entriesToSkip, 1);
      expect(retryResult.createdLists, 0);
      expect(retryResult.addedEntries, 0);
      expect(retryResult.skippedEntries, 1);
    },
  );

  test('resolves same-named lists within their own categories', () async {
    final reading = await categoryRepository.createOrGetCategory(
      name: 'Reading',
    );
    final travel = await categoryRepository.createOrGetCategory(name: 'Travel');
    await listRepository.createList(categoryId: reading.id, name: 'Books');
    final travelBooks = await listRepository.createList(
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

    final preview = await transferRepository.previewCsvImport(document);
    final result = await transferRepository.importCsvEntries(document);

    expect(preview.hasBlockingReferences, isFalse);
    expect(preview.entriesToAdd, 1);
    expect(result.createdLists, 0);
    expect(result.addedEntries, 1);
    expect(
      (await entryRepository.watchEntries(travelBooks.id).first).single.content,
      'Pack a guidebook',
    );
  });

  test('blocks ambiguous lists without changing any entries', () async {
    final reading = await categoryRepository.createOrGetCategory(
      name: 'Reading',
    );
    final firstBooks = await listRepository.createList(
      categoryId: reading.id,
      name: 'Books',
    );
    await listRepository.createList(categoryId: reading.id, name: 'Books');
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

    final preview = await transferRepository.previewCsvImport(document);

    expect(preview.ambiguousLists.single.displayName, 'Reading > Books');
    await expectLater(
      transferRepository.importCsvEntries(document),
      throwsA(isA<CsvImportPreflightException>()),
    );
    expect(await entryRepository.watchEntries(firstBooks.id).first, isEmpty);
  });

  test(
    'skips exact existing entries so import retries are idempotent',
    () async {
      final reading = await categoryRepository.createOrGetCategory(
        name: 'Reading',
      );
      final books = await listRepository.createList(
        categoryId: reading.id,
        name: 'Books',
      );
      await entryRepository.createEntry(
        listId: books.id,
        content: 'Already tracked',
        date: DateTime(2026, 3, 15),
      );
      final unrelated = await listRepository.createListInCategory(
        categoryName: 'Meals',
        name: 'Weekday',
      );
      await entryRepository.createEntry(
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
          const CsvImportEntry(
            reference: CsvListReference(
              categoryName: 'Reading',
              listName: 'Books',
            ),
            content: 'New chapter',
            date: null,
          ),
        ],
      );

      final firstPreview = await transferRepository.previewCsvImport(document);
      final firstResult = await transferRepository.importCsvEntries(document);
      final retryPreview = await transferRepository.previewCsvImport(document);
      final retryResult = await transferRepository.importCsvEntries(document);

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
      expect(await entryRepository.watchEntries(books.id).first, hasLength(2));
      expect(
        (await entryRepository.watchEntries(unrelated.id).first).single.content,
        'Keep this entry',
      );
    },
  );
}
