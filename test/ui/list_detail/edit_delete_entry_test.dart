import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/list_tracker_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/add_entry/add_entry_page.dart';
import 'package:list_tracker/ui/list_detail/list_detail_page.dart';
import 'package:go_router/go_router.dart';

void main() {
  const category = Category(
    id: 1,
    externalId: 'exercise-category',
    name: 'Exercise',
  );
  final list = ListModel(
    id: 1,
    externalId: 'morning-mobility',
    categoryId: category.id,
    name: 'Morning mobility',
    createdAt: DateTime(2026),
  );
  final summary = ListWithCategory(list: list, category: category);

  testWidgets('edits a pre-filled entry and returns to List Detail', (
    tester,
  ) async {
    final date = DateTime(2026, 3, 15);
    final entry = _entry(id: 1, content: 'Stretch for ten minutes', date: date);
    final repository = _EditableEntryRepository(
      summary: summary,
      entries: [entry],
    );
    addTearDown(repository.dispose);

    await _pumpListDetail(tester, repository);

    await tester.tap(find.byKey(const ValueKey('edit-entry-1')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Entry'), findsOneWidget);
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(AddEntryPage)),
    );
    expect(find.text(localizations.formatMediumDate(date)), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('entry-content-field')),
          )
          .controller!
          .text,
      'Stretch for ten minutes',
    );

    await tester.tap(find.byKey(const ValueKey('clear-entry-date')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('entry-content-field')),
      'Stretch for fifteen minutes',
    );
    await tester.tap(find.byKey(const ValueKey('save-entry-button')));
    await tester.pumpAndSettle();

    expect(repository.updatedEntryRequest, (
      1,
      'Stretch for fifteen minutes',
      null,
    ));
    expect(find.text('Stretch for fifteen minutes'), findsOneWidget);
  });

  testWidgets('confirms deletion before removing and refreshing entries', (
    tester,
  ) async {
    final entry = _entry(id: 1, content: 'Walk after lunch');
    final repository = _EditableEntryRepository(
      summary: summary,
      entries: [entry],
    );
    addTearDown(repository.dispose);

    await _pumpListDetail(tester, repository);

    await tester.tap(find.byKey(const ValueKey('delete-entry-1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete entry?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deletedEntryId, isNull);
    expect(find.text('Walk after lunch'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-entry-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-entry-button')));
    await tester.pumpAndSettle();

    expect(repository.deletedEntryId, entry.id);
    expect(find.text('Walk after lunch'), findsNothing);
    expect(find.text('No entries yet.'), findsOneWidget);
  });
}

Entry _entry({required int id, required String content, DateTime? date}) {
  return Entry(
    id: id,
    externalId: 'entry-$id',
    listId: 1,
    content: content,
    date: date,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Future<void> _pumpListDetail(
  WidgetTester tester,
  ListTrackerRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/lists/1',
    routes: [
      GoRoute(
        path: '/lists/:listId',
        builder: (_, state) =>
            ListDetailPage(listId: int.parse(state.pathParameters['listId']!)),
      ),
      GoRoute(
        path: '/lists/:listId/entries/:entryId/edit',
        builder: (_, state) => AddEntryPage(
          listId: int.parse(state.pathParameters['listId']!),
          entry: state.extra as Entry?,
        ),
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

class _EditableEntryRepository implements ListTrackerRepository {
  _EditableEntryRepository({
    required this.summary,
    required List<Entry> entries,
  }) : _entries = List.of(entries);

  final ListWithCategory summary;
  final List<Entry> _entries;
  final _entryChanges = StreamController<List<Entry>>.broadcast();
  (int, String, DateTime?)? updatedEntryRequest;
  int? deletedEntryId;

  @override
  Stream<ListWithCategory?> watchList(int id) =>
      Stream.value(id == summary.list.id ? summary : null);

  @override
  Stream<List<Entry>> watchEntries(int listId) async* {
    if (listId != summary.list.id) {
      yield const [];
      return;
    }

    yield List.unmodifiable(_entries);
    yield* _entryChanges.stream;
  }

  @override
  Future<bool> updateEntry({
    required int id,
    required String content,
    required DateTime? date,
  }) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return false;
    }

    updatedEntryRequest = (id, content, date);
    final entry = _entries[index];
    _entries[index] = Entry(
      id: entry.id,
      externalId: entry.externalId,
      listId: entry.listId,
      content: content,
      date: date,
      createdAt: entry.createdAt,
      updatedAt: DateTime(2026, 1, 2),
    );
    _entryChanges.add(List.unmodifiable(_entries));
    return true;
  }

  @override
  Future<bool> deleteEntry(int id) async {
    final countBeforeDelete = _entries.length;
    _entries.removeWhere((entry) => entry.id == id);
    if (_entries.length == countBeforeDelete) {
      return false;
    }

    deletedEntryId = id;
    _entryChanges.add(List.unmodifiable(_entries));
    return true;
  }

  Future<void> dispose() => _entryChanges.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
