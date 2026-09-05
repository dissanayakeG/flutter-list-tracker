import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/category_repository.dart';
import 'package:list_tracker/data/repository/entry_repository.dart';
import 'package:list_tracker/data/repository/list_repository.dart';

void main() {
  late AppDatabase database;
  late DriftCategoryRepository categoryRepository;
  late DriftListRepository listRepository;
  late DriftEntryRepository entryRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    categoryRepository = DriftCategoryRepository(database);
    listRepository = DriftListRepository(database, categoryRepository);
    entryRepository = DriftEntryRepository(database);
  });

  tearDown(() => database.close());

  test(
    'creates a list with its category and exposes the joined summary',
    () async {
      final list = await listRepository.createListInCategory(
        categoryName: 'Exercise Routines',
        name: 'Morning mobility',
        note: ' 15 minutes ',
      );

      final summary = await listRepository.watchList(list.id).first;
      final allLists = await listRepository.watchLists().first;

      expect(summary, isNotNull);
      expect(summary!.category.name, 'Exercise Routines');
      expect(summary.list.name, 'Morning mobility');
      expect(summary.list.note, '15 minutes');
      expect(allLists.single.list, summary.list);
    },
  );

  test('updates a list name, note, and category', () async {
    final reading = await categoryRepository.createOrGetCategory(
      name: 'Reading',
    );
    final plans = await categoryRepository.createOrGetCategory(name: 'Plans');
    final list = await listRepository.createList(
      categoryId: reading.id,
      name: 'Books to finish',
      note: 'This month',
    );

    expect(
      await listRepository.updateList(
        id: list.id,
        categoryId: plans.id,
        name: '  Weekend plans ',
        note: '  Plan ahead ',
      ),
      isTrue,
    );

    final updated = await listRepository.watchList(list.id).first;
    expect(updated!.category.id, plans.id);
    expect(updated.list.name, 'Weekend plans');
    expect(updated.list.note, 'Plan ahead');
    expect(
      await listRepository.updateList(
        id: 999,
        categoryId: plans.id,
        name: 'Missing',
      ),
      isFalse,
    );
  });

  test('deletes a list and cascades deletion to its entries', () async {
    final list = await listRepository.createListInCategory(
      categoryName: 'Reading',
      name: 'Books to finish',
    );
    await entryRepository.createEntry(
      listId: list.id,
      content: 'Read a chapter',
      date: null,
    );

    expect(await listRepository.deleteList(list.id), isTrue);
    expect(await listRepository.watchList(list.id).first, isNull);
    expect(await entryRepository.watchEntries(list.id).first, isEmpty);
    expect(await listRepository.deleteList(list.id), isFalse);
  });

  test('does not create a category when its list cannot be created', () async {
    await expectLater(
      listRepository.createListInCategory(categoryName: 'Reading', name: ' '),
      throwsArgumentError,
    );

    expect(await categoryRepository.getCategories(), isEmpty);
  });

  test('rejects blank list names', () {
    expect(
      () => listRepository.createList(categoryId: 1, name: ' '),
      throwsArgumentError,
    );
  });
}
