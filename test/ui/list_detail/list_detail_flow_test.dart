import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_3/data/local/app_database.dart';
import 'package:flutter_application_3/data/repository/list_tracker_repository.dart';
import 'package:flutter_application_3/data/repository/repository_providers.dart';
import 'package:flutter_application_3/ui/add_entry/add_entry_page.dart';
import 'package:flutter_application_3/ui/dashboard/dashboard_page.dart';
import 'package:flutter_application_3/ui/list_detail/list_detail_page.dart';
import 'package:go_router/go_router.dart';

void main() {
  const category = Category(id: 1, name: 'Exercise');

  final list = ListModel(
    id: 1,
    categoryId: category.id,
    name: 'Morning mobility',
    createdAt: DateTime(2026),
  );

  final summary = ListWithCategory(list: list, category: category);

  testWidgets('opens list detail when a dashboard card is tapped', (
    tester,
  ) async {
    final repository = _DetailRepository(summary: summary);

    await _pumpApp(tester, repository, initialLocation: '/');

    await tester.tap(find.text('Morning mobility'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-entry-button')), findsOneWidget);
    expect(find.text('No entries yet.'), findsOneWidget);
  });

  testWidgets('shows entries and saves a new one back to list detail', (
    tester,
  ) async {
    final existingEntry = Entry(
      id: 1,
      listId: list.id,
      content: 'Stretch for ten minutes',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final repository = _DetailRepository(
      summary: summary,
      entries: [existingEntry],
    );

    await _pumpApp(tester, repository, initialLocation: '/lists/1');

    expect(find.text('Morning mobility'), findsOneWidget);
    expect(find.text('Stretch for ten minutes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-content-field')),
      'Walk after lunch',
    );
    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();

    expect(repository.createdEntryRequest, (1, 'Walk after lunch'));
    expect(find.text('Morning mobility'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  ListTrackerRepository repository, {
  required String initialLocation,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
      GoRoute(
        path: '/lists/:listId',
        builder: (_, state) =>
            ListDetailPage(listId: int.parse(state.pathParameters['listId']!)),
      ),
      GoRoute(
        path: '/lists/:listId/add-entry',
        builder: (_, state) =>
            AddEntryPage(listId: int.parse(state.pathParameters['listId']!)),
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

class _DetailRepository implements ListTrackerRepository {
  _DetailRepository({required this.summary, List<Entry> entries = const []})
    : _entries = List.unmodifiable(entries);

  final ListWithCategory summary;
  final List<Entry> _entries;
  (int, String)? createdEntryRequest;

  @override
  Stream<List<Category>> watchCategories() => Stream.value([summary.category]);

  @override
  Stream<List<ListWithCategory>> watchLists() => Stream.value([summary]);

  @override
  Stream<ListWithCategory?> watchList(int id) =>
      Stream.value(id == summary.list.id ? summary : null);

  @override
  Stream<List<Entry>> watchEntries(int listId) =>
      Stream.value(listId == summary.list.id ? _entries : const []);

  @override
  Future<Entry> createEntry({
    required int listId,
    required String content,
  }) async {
    createdEntryRequest = (listId, content);
    return Entry(
      id: _entries.length + 1,
      listId: listId,
      content: content,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
