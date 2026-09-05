import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/category_repository.dart';
import 'package:list_tracker/data/repository/list_repository.dart';

void main() {
  late AppDatabase database;
  late DriftCategoryRepository categoryRepository;
  late DriftListRepository listRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    categoryRepository = DriftCategoryRepository(database);
    listRepository = DriftListRepository(database, categoryRepository);
  });

  tearDown(() => database.close());

  test('creates and reuses normalized categories', () async {
    final first = await categoryRepository.createOrGetCategory(
      name: ' Meal Plans ',
    );
    final second = await categoryRepository.createOrGetCategory(
      name: 'Meal Plans',
    );

    expect(second.id, first.id);
    expect(second.name, 'Meal Plans');
    expect(await categoryRepository.getCategories(), [first]);
  });

  test(
    'updates categories and prevents deleting categories that contain lists',
    () async {
      final reading = await categoryRepository.createOrGetCategory(
        name: 'Reading',
      );
      final empty = await categoryRepository.createOrGetCategory(name: 'Empty');

      expect(
        await categoryRepository.updateCategory(
          id: reading.id,
          name: '  Books  ',
        ),
        isTrue,
      );
      expect((await categoryRepository.getCategory(reading.id))!.name, 'Books');
      expect(await categoryRepository.isCategoryInUse(reading.id), isFalse);

      await listRepository.createList(categoryId: reading.id, name: 'To read');
      expect(await categoryRepository.isCategoryInUse(reading.id), isTrue);
      expect(await categoryRepository.deleteCategory(reading.id), isFalse);
      expect(await categoryRepository.getCategory(reading.id), isNotNull);

      expect(await categoryRepository.deleteCategory(empty.id), isTrue);
      expect(await categoryRepository.getCategory(empty.id), isNull);
    },
  );

  test('rejects blank category names', () {
    expect(
      () => categoryRepository.createOrGetCategory(name: '  '),
      throwsArgumentError,
    );
  });
}
