import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/entry_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/entries/pages/add_entry_page.dart';
import 'package:list_tracker/ui/entries/pages/edit_entry_page.dart';
import 'package:list_tracker/ui/entries/widgets/entry_form.dart';

void main() {
  testWidgets('Add Entry saves through the shared form with an optional date', (
    tester,
  ) async {
    final repository = _FakeEntryRepository();
    final selectedDate = DateTime(2026, 3, 15);

    await _pumpEntryRouter(
      tester,
      repository,
      initialLocation: '/lists/1/add-entry',
    );

    expect(find.byType(AddEntryPage), findsOneWidget);
    expect(find.byType(EditEntryPage), findsNothing);
    expect(find.byType(EntryForm), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-date-picker')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(selectedDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('entry-content-field')),
      'Walk after lunch',
    );
    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();

    expect(repository.createdEntryRequest, (
      1,
      'Walk after lunch',
      selectedDate,
    ));
    expect(
      find.byKey(const ValueKey('list-detail-placeholder')),
      findsOneWidget,
    );
  });

  testWidgets('Edit Entry pre-fills and updates through the shared form', (
    tester,
  ) async {
    final date = DateTime(2026, 3, 15);
    final repository = _FakeEntryRepository();
    final entry = Entry(
      id: 4,
      externalId: 'entry-4',
      listId: 1,
      content: 'Stretch for ten minutes',
      date: date,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await _pumpEntryRouter(
      tester,
      repository,
      initialLocation: '/lists/1/entries/4/edit',
      entry: entry,
    );

    expect(find.byType(AddEntryPage), findsNothing);
    expect(find.byType(EditEntryPage), findsOneWidget);
    expect(find.byType(EntryForm), findsOneWidget);
    expect(find.text('Edit Entry'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('entry-content-field')),
          )
          .controller!
          .text,
      entry.content,
    );
    expect(find.byKey(const ValueKey('clear-entry-date')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-entry-date')));
    await tester.enterText(
      find.byKey(const ValueKey('entry-content-field')),
      'Stretch for fifteen minutes',
    );
    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();

    expect(repository.updatedEntryRequest, (
      4,
      'Stretch for fifteen minutes',
      null,
    ));
    expect(
      find.byKey(const ValueKey('list-detail-placeholder')),
      findsOneWidget,
    );
  });

  testWidgets('an entry is required in either route flow', (tester) async {
    final repository = _FakeEntryRepository();

    await _pumpEntryRouter(
      tester,
      repository,
      initialLocation: '/lists/1/add-entry',
    );

    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter an entry.'), findsOneWidget);
    expect(repository.createdEntryRequest, isNull);
  });

  testWidgets('an edit route without extra preserves the Add Entry fallback', (
    tester,
  ) async {
    final repository = _FakeEntryRepository();

    await _pumpEntryRouter(
      tester,
      repository,
      initialLocation: '/lists/1/entries/4/edit',
    );

    expect(find.byType(EditEntryPage), findsOneWidget);
    expect(find.byType(AddEntryPage), findsOneWidget);
    expect(find.text('Add Entry'), findsOneWidget);
  });
}

Future<void> _pumpEntryRouter(
  WidgetTester tester,
  EntryRepository repository, {
  required String initialLocation,
  Entry? entry,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/lists/:listId',
        builder: (_, _) => const Scaffold(
          body: SizedBox(key: ValueKey('list-detail-placeholder')),
        ),
      ),
      GoRoute(
        path: '/lists/:listId/add-entry',
        builder: (_, state) =>
            AddEntryPage(listId: int.parse(state.pathParameters['listId']!)),
      ),
      GoRoute(
        path: '/lists/:listId/entries/:entryId/edit',
        builder: (_, state) => EditEntryPage(
          listId: int.parse(state.pathParameters['listId']!),
          entry: entry,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeEntryRepository implements EntryRepository {
  (int, String, DateTime?)? createdEntryRequest;
  (int, String, DateTime?)? updatedEntryRequest;

  @override
  Future<Entry> createEntry({
    required int listId,
    required String content,
    DateTime? date,
  }) async {
    createdEntryRequest = (listId, content, date);
    return Entry(
      id: 1,
      externalId: 'created-entry',
      listId: listId,
      content: content,
      date: date,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<bool> updateEntry({
    required int id,
    required String content,
    required DateTime? date,
  }) async {
    updatedEntryRequest = (id, content, date);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
