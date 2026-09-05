import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/category_repository.dart';
import 'package:list_tracker/data/repository/list_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/categories/pages/add_category_page.dart';
import 'package:list_tracker/ui/categories/pages/categories_page.dart';
import 'package:list_tracker/ui/categories/pages/edit_category_page.dart';
import 'package:list_tracker/ui/dashboard/dashboard_page.dart';
import 'package:list_tracker/ui/settings/settings_page.dart';

void main() {
  testWidgets('opens Category Management from Settings', (tester) async {
    final repository = _CategoryRepository();
    addTearDown(repository.dispose);

    await _pumpCategoryFlow(tester, repository: repository);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('No categories yet.'), findsOneWidget);
  });

  testWidgets('shows Categories alphabetically and opens Add Category', (
    tester,
  ) async {
    final repository = _CategoryRepository(
      categories: const [
        Category(id: 1, externalId: 'exercise', name: 'Exercise'),
        Category(id: 2, externalId: 'reading', name: 'Reading'),
      ],
    );
    addTearDown(repository.dispose);

    await _pumpCategoryFlow(
      tester,
      repository: repository,
      initialLocation: '/categories',
    );

    final categoryNames = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(categoryNames, ['Exercise', 'Reading']);

    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    expect(find.text('Add Category'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-name-field')), findsOneWidget);
  });

  testWidgets('validates, saves a normalized category, and avoids duplicates', (
    tester,
  ) async {
    final repository = _CategoryRepository();
    addTearDown(repository.dispose);

    await _pumpCategoryFlow(
      tester,
      repository: repository,
      initialLocation: '/categories',
    );

    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-category-button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a category name.'), findsOneWidget);
    expect(repository.categories, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('category-name-field')),
      '  Meal Plans  ',
    );
    await tester.tap(find.byKey(const ValueKey('save-category-button')));
    await tester.pumpAndSettle();

    expect(repository.categories.single.name, 'Meal Plans');
    expect(find.text('Meal Plans'), findsOneWidget);

    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-name-field')),
      'Meal Plans',
    );
    await tester.tap(find.byKey(const ValueKey('save-category-button')));
    await tester.pumpAndSettle();

    expect(repository.categories, hasLength(1));
    expect(find.text('Meal Plans'), findsOneWidget);
  });

  testWidgets('prefills and updates an existing category', (tester) async {
    const reading = Category(
      id: 1,
      externalId: 'reading-category',
      name: 'Reading',
    );
    final repository = _CategoryRepository(categories: const [reading]);
    addTearDown(repository.dispose);

    await _pumpCategoryFlow(
      tester,
      repository: repository,
      initialLocation: '/categories',
    );

    await tester.tap(find.byKey(const ValueKey('edit-category-1')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-category-name-field')),
          )
          .controller!
          .text,
      'Reading',
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit-category-name-field')),
      'Books',
    );
    await tester.tap(find.byKey(const ValueKey('save-edited-category-button')));
    await tester.pumpAndSettle();

    expect(repository.categories.single.name, 'Books');
    expect(find.text('Books'), findsOneWidget);
  });

  testWidgets('does not offer deletion for a category that contains lists', (
    tester,
  ) async {
    const reading = Category(
      id: 1,
      externalId: 'reading-category',
      name: 'Reading',
    );
    final repository = _CategoryRepository(
      categories: const [reading],
      usedCategoryIds: const {1},
    );
    addTearDown(repository.dispose);

    await _pumpCategoryFlow(
      tester,
      repository: repository,
      initialLocation: '/categories',
    );
    await tester.tap(find.byKey(const ValueKey('delete-category-1')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Delete or move this category’s lists before deleting it.'),
      findsOneWidget,
    );
    expect(repository.deletedCategoryIds, isEmpty);
  });

  testWidgets('confirms and deletes an empty category with error colors', (
    tester,
  ) async {
    const reading = Category(
      id: 1,
      externalId: 'reading-category',
      name: 'Reading',
    );
    final repository = _CategoryRepository(categories: const [reading]);
    addTearDown(repository.dispose);

    await _pumpCategoryFlow(
      tester,
      repository: repository,
      initialLocation: '/categories',
    );
    final colors = Theme.of(tester.element(find.byType(CategoriesPage)))
        .colorScheme;

    await tester.tap(find.byKey(const ValueKey('delete-category-1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Reading”?'), findsOneWidget);

    final deleteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(deleteButton.style!.backgroundColor!.resolve({}), colors.error);
    expect(deleteButton.style!.foregroundColor!.resolve({}), colors.onError);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedCategoryIds, [reading.id]);
    expect(find.text('No categories yet.'), findsOneWidget);
    expect(find.text('Category deleted.'), findsOneWidget);
  });
}

Future<void> _pumpCategoryFlow(
  WidgetTester tester, {
  required CategoryRepository repository,
  String initialLocation = '/',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/categories', builder: (_, _) => const CategoriesPage()),
      GoRoute(
        path: '/categories/add',
        builder: (_, _) => const AddCategoryPage(),
      ),
      GoRoute(
        path: '/categories/:categoryId/edit',
        builder: (_, state) => EditCategoryPage(
          categoryId: int.parse(state.pathParameters['categoryId']!),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(repository),
        listRepositoryProvider.overrideWithValue(_EmptyListRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _CategoryRepository implements CategoryRepository {
  _CategoryRepository({
    List<Category> categories = const [],
    Set<int> usedCategoryIds = const {},
  }) : _categories = [...categories],
       _usedCategoryIds = Set.of(usedCategoryIds);

  final List<Category> _categories;
  final Set<int> _usedCategoryIds;
  final _updates = StreamController<List<Category>>.broadcast();
  final deletedCategoryIds = <int>[];

  List<Category> get categories => List.unmodifiable(_categories);

  @override
  Stream<List<Category>> watchCategories() async* {
    yield categories;
    yield* _updates.stream;
  }

  @override
  Future<Category> createOrGetCategory({required String name}) async {
    final normalizedName = name.trim();
    final existing = _categories.where(
      (category) => category.name == normalizedName,
    );
    if (existing.isNotEmpty) {
      return existing.single;
    }

    final category = Category(
      id: _categories.length + 1,
      externalId: 'category-${_categories.length + 1}',
      name: normalizedName,
    );
    _categories.add(category);
    _updates.add(categories);
    return category;
  }

  @override
  Future<bool> updateCategory({required int id, required String name}) async {
    final index = _categories.indexWhere((category) => category.id == id);
    if (index == -1) {
      return false;
    }

    final category = _categories[index];
    _categories[index] = Category(
      id: category.id,
      externalId: category.externalId,
      name: name.trim(),
    );
    _updates.add(categories);
    return true;
  }

  @override
  Future<bool> isCategoryInUse(int id) async => _usedCategoryIds.contains(id);

  @override
  Future<bool> deleteCategory(int id) async {
    if (_usedCategoryIds.contains(id)) {
      return false;
    }

    final countBeforeDelete = _categories.length;
    _categories.removeWhere((category) => category.id == id);
    if (_categories.length == countBeforeDelete) {
      return false;
    }

    deletedCategoryIds.add(id);
    _updates.add(categories);
    return true;
  }

  void dispose() => _updates.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyListRepository implements ListRepository {
  @override
  Stream<List<ListWithCategory>> watchLists() => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
