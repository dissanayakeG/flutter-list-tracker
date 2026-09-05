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

  test('updates and deletes an entry', () async {
    final list = await listRepository.createListInCategory(
      categoryName: 'Reading',
      name: 'Books to finish',
    );
    final entry = await entryRepository.createEntry(
      listId: list.id,
      content: '  The Left Hand of Darkness ',
      date: DateTime(2026, 3, 15, 18),
    );

    expect(entry.content, 'The Left Hand of Darkness');
    expect(entry.date, DateTime(2026, 3, 15));
    expect(
      await entryRepository.updateEntry(
        id: entry.id,
        content: 'Finished reading',
        date: null,
      ),
      isTrue,
    );

    final updatedEntry =
        (await entryRepository.watchEntries(list.id).first).single;
    expect(updatedEntry.content, 'Finished reading');
    expect(updatedEntry.date, isNull);
    expect(
      updatedEntry.updatedAt.isAfter(entry.updatedAt) ||
          updatedEntry.updatedAt.isAtSameMomentAs(entry.updatedAt),
      isTrue,
    );

    expect(await entryRepository.deleteEntry(entry.id), isTrue);
    expect(await entryRepository.watchEntries(list.id).first, isEmpty);
  });

  test('rejects blank entry content', () {
    expect(
      () => entryRepository.createEntry(listId: 1, content: ''),
      throwsArgumentError,
    );
  });
}
