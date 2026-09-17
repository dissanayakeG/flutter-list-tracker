import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/category_repository.dart';
import 'package:list_tracker/data/repository/list_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_providers.dart';
import 'package:list_tracker/ui/dashboard/dashboard_page.dart';
import 'package:list_tracker/ui/navigation/main_navigation_page.dart';

void main() {
  testWidgets(
    'shows list cards, filters them, and has no transfer app-bar actions',
    (tester) async {
      const meals = Category(id: 1, externalId: 'meals', name: 'Meals');
      const exercise = Category(
        id: 2,
        externalId: 'exercise',
        name: 'Exercise',
      );
      final repository = _FakeRepository(
        categories: const [meals, exercise],
        summaries: [
          ListWithCategory(
            list: ListModel(
              id: 1,
              externalId: 'weekday',
              categoryId: meals.id,
              name: 'Weekday meals',
              createdAt: DateTime(2026),
            ),
            category: meals,
          ),
          ListWithCategory(
            list: ListModel(
              id: 2,
              externalId: 'yoga',
              categoryId: exercise.id,
              name: 'Morning yoga',
              createdAt: DateTime(2026),
            ),
            category: exercise,
          ),
        ],
      );

      await _pump(tester, repository);

      expect(find.text('Weekday meals'), findsOneWidget);
      expect(find.text('Morning yoga'), findsOneWidget);
      expect(find.byTooltip('Import CSV'), findsNothing);
      expect(find.byTooltip('Export CSV'), findsNothing);
      expect(find.byTooltip('Settings'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Exercise'));
      await tester.pumpAndSettle();

      expect(find.text('Weekday meals'), findsNothing);
      expect(find.text('Morning yoga'), findsOneWidget);
    },
  );

  testWidgets('renders at narrow width with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(_FakeRepository()),
          listRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows Home, Lists, Languages, and Settings as the primary destinations',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(_FakeRepository()),
            listRepositoryProvider.overrideWithValue(_FakeRepository()),
            languagesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: MainNavigationPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Lists'), findsAtLeastNWidgets(1));
      expect(find.text('Languages'), findsAtLeastNWidgets(1));
      expect(find.text('Settings'), findsOneWidget);
    },
  );
}

Future<void> _pump(WidgetTester tester, _FakeRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(repository),
        listRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: DashboardPage()),
    ),
  );
  await tester.pump();
}

class _FakeRepository implements CategoryRepository, ListRepository {
  _FakeRepository({this.categories = const [], this.summaries = const []});

  final List<Category> categories;
  final List<ListWithCategory> summaries;

  @override
  Stream<List<Category>> watchCategories() => Stream.value(categories);

  @override
  Stream<List<ListWithCategory>> watchLists() => Stream.value(summaries);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
