import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_3/data/local/app_database.dart';
import 'package:flutter_application_3/data/repository/list_tracker_repository.dart';

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
