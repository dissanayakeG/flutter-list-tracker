import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/list_tracker_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/main.dart';
import 'package:list_tracker/ui/dashboard/dashboard_page.dart';

void main() {
  testWidgets('shows list cards and filters them by category', (tester) async {
    const meals = Category(id: 1, name: 'Meal Plans');
    const exercise = Category(id: 2, name: 'Exercise');
    final repository = _FakeRepository(
      categories: const [meals, exercise],
      summaries: [
        ListWithCategory(
          list: ListModel(
            id: 1,
            categoryId: meals.id,
            name: 'Weekday meals',
            createdAt: DateTime(2026),
          ),
          category: meals,
        ),
        ListWithCategory(
          list: ListModel(
            id: 2,
            categoryId: exercise.id,
            name: 'Morning yoga',
            createdAt: DateTime(2026, 1, 2),
          ),
          category: exercise,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listTrackerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekday meals'), findsOneWidget);
    expect(find.text('Morning yoga'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Morning yoga'), findsOneWidget);
    expect(find.text('Weekday meals'), findsNothing);
  });

  testWidgets('shows an empty state and opens the Add New List form', (
    tester,
  ) async {
    final repository = _FakeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listTrackerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const ListTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No lists yet.'), findsOneWidget);

    await tester.tap(find.byTooltip('Add new list'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('list-name-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-category-field')), findsOneWidget);
  });
}

class _FakeRepository implements ListTrackerRepository {
  _FakeRepository({
    List<Category> categories = const [],
    List<ListWithCategory> summaries = const [],
  }) : _categories = List.unmodifiable(categories),
       _summaries = List.unmodifiable(summaries);

  final List<Category> _categories;
  final List<ListWithCategory> _summaries;

  @override
  Stream<List<Category>> watchCategories() => Stream.value(_categories);

  @override
  Stream<List<ListWithCategory>> watchLists() => Stream.value(_summaries);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
