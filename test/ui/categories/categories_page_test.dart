import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/list_tracker_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/categories/categories_page.dart';
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
}

Future<void> _pumpCategoryFlow(
  WidgetTester tester, {
  required ListTrackerRepository repository,
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
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [listTrackerRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _CategoryRepository implements ListTrackerRepository {
  _CategoryRepository({List<Category> categories = const []})
    : _categories = [...categories];

  final List<Category> _categories;
  final _updates = StreamController<List<Category>>.broadcast();

  List<Category> get categories => List.unmodifiable(_categories);

  @override
  Stream<List<Category>> watchCategories() async* {
    yield categories;
    yield* _updates.stream;
  }

  @override
  Stream<List<ListWithCategory>> watchLists() => Stream.value(const []);

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

  void dispose() => _updates.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
