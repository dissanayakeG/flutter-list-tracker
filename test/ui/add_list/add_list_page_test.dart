import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/list_tracker_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/add_list/add_list_page.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('returns to Dashboard with the AppBar back action', (
    tester,
  ) async {
    final repository = _RecordingRepository();

    await _pumpAddListPage(tester, repository);

    await tester.tap(find.byTooltip('Back to Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('saves a list in a selected existing category', (tester) async {
    const reading = Category(
      id: 1,
      externalId: 'reading-category',
      name: 'Reading',
    );
    final repository = _RecordingRepository(categories: const [reading]);

    await _pumpAddListPage(tester, repository);

    await tester.tap(find.text('Existing'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<InputDecorator>(
            find.byKey(const ValueKey('existing-category-input')),
          )
          .isEmpty,
      isFalse,
    );

    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const ValueKey('existing-category-dropdown')),
          )
          .menuWidth,
      280,
    );

    await tester.tap(find.byKey(const ValueKey('existing-category-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('list-name-field')),
      'Books to finish',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-field')),
      'This month',
    );
    await tester.tap(find.byKey(const ValueKey('save-list-button')));
    await tester.pumpAndSettle();

    expect(repository.existingCategoryRequest, (
      1,
      'Books to finish',
      'This month',
    ));
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('creates a category and list from the form', (tester) async {
    final repository = _RecordingRepository();

    await _pumpAddListPage(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey('new-category-field')),
      'Meal Plans',
    );
    await tester.enterText(
      find.byKey(const ValueKey('list-name-field')),
      'Weekday meals',
    );
    await tester.tap(find.byKey(const ValueKey('save-list-button')));
    await tester.pumpAndSettle();

    expect(repository.newCategoryRequest, ('Meal Plans', 'Weekday meals', ''));
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('adapts category controls to narrow screens and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const reading = Category(
      id: 1,
      externalId: 'reading-category',
      name: 'Reading',
    );
    await _pumpAddListPage(
      tester,
      _RecordingRepository(categories: const [reading]),
      textScaler: TextScaler.linear(1.5),
    );

    expect(
      tester
          .widget<SegmentedButton>(
            find.byKey(const ValueKey('category-mode-selector')),
          )
          .direction,
      Axis.vertical,
    );

    await tester.tap(find.text('Existing'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const ValueKey('existing-category-dropdown')),
          )
          .menuWidth,
      280,
    );
  });
}

Future<void> _pumpAddListPage(
  WidgetTester tester,
  ListTrackerRepository repository, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final router = GoRouter(
    initialLocation: '/add-list',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Dashboard'))),
      ),
      GoRoute(path: '/add-list', builder: (_, _) => const AddListPage()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [listTrackerRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingRepository implements ListTrackerRepository {
  _RecordingRepository({List<Category> categories = const []})
    : _categories = List.unmodifiable(categories);

  final List<Category> _categories;
  (int, String, String?)? existingCategoryRequest;
  (String, String, String?)? newCategoryRequest;

  @override
  Stream<List<Category>> watchCategories() => Stream.value(_categories);

  @override
  Future<ListModel> createList({
    required int categoryId,
    required String name,
    String? note,
  }) async {
    existingCategoryRequest = (categoryId, name, note);
    return ListModel(
      id: 1,
      externalId: 'recorded-list',
      categoryId: categoryId,
      name: name,
      note: note,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<ListModel> createListInCategory({
    required String categoryName,
    required String name,
    String? note,
  }) async {
    newCategoryRequest = (categoryName, name, note);
    return ListModel(
      id: 1,
      externalId: 'recorded-new-list',
      categoryId: 1,
      name: name,
      note: note,
      createdAt: DateTime(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
