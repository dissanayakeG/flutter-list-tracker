import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/category_repository.dart';
import 'package:list_tracker/data/repository/list_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/lists/pages/edit_list_page.dart';

void main() {
  testWidgets('prefills and updates an existing list', (tester) async {
    const reading = Category(
      id: 1,
      externalId: 'reading-category',
      name: 'Reading',
    );
    const plans = Category(id: 2, externalId: 'plans-category', name: 'Plans');
    final list = ListModel(
      id: 7,
      externalId: 'books-list',
      categoryId: reading.id,
      name: 'Books to finish',
      note: 'This month',
      createdAt: DateTime(2026),
    );
    final repository = _EditListRepository(
      list: list,
      categories: const [reading, plans],
    );

    await _pumpEditListPage(tester, repository, list.id);

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-list-name-field')),
          )
          .controller!
          .text,
      'Books to finish',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-list-note-field')),
          )
          .controller!
          .text,
      'This month',
    );
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const ValueKey('existing-category-dropdown')),
          )
          .value,
      reading.id,
    );

    await tester.tap(find.byKey(const ValueKey('existing-category-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plans').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-list-name-field')),
      'Weekend plans',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-list-note-field')),
      'Plan ahead',
    );
    await tester.tap(find.byKey(const ValueKey('save-list-button')));
    await tester.pumpAndSettle();

    expect(repository.updateRequest, (7, 2, 'Weekend plans', 'Plan ahead'));
    expect(find.text('List Detail'), findsOneWidget);
  });
}

Future<void> _pumpEditListPage(
  WidgetTester tester,
  _EditListRepository repository,
  int listId,
) async {
  final router = GoRouter(
    initialLocation: '/lists/$listId/edit',
    routes: [
      GoRoute(
        path: '/lists/:listId',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('List Detail'))),
      ),
      GoRoute(
        path: '/lists/:listId/edit',
        builder: (_, state) =>
            EditListPage(listId: int.parse(state.pathParameters['listId']!)),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(repository),
        listRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _EditListRepository implements CategoryRepository, ListRepository {
  _EditListRepository({required this.list, required List<Category> categories})
    : _categories = List.unmodifiable(categories);

  final ListModel list;
  final List<Category> _categories;
  (int, int, String, String?)? updateRequest;

  @override
  Stream<List<Category>> watchCategories() => Stream.value(_categories);

  @override
  Stream<ListWithCategory?> watchList(int id) {
    final category = _categories.singleWhere(
      (category) => category.id == list.categoryId,
    );
    return Stream.value(ListWithCategory(list: list, category: category));
  }

  @override
  Future<bool> updateList({
    required int id,
    required int categoryId,
    required String name,
    String? note,
  }) async {
    updateRequest = (id, categoryId, name, note);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
