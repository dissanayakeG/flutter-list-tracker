import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/list_tracker_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/data/transfer/csv_export_providers.dart';
import 'package:list_tracker/data/transfer/csv_export_service.dart';
import 'package:list_tracker/main.dart';
import 'package:list_tracker/ui/dashboard/dashboard_page.dart';

void main() {
  testWidgets('shows list cards and filters them by category', (tester) async {
    const meals = Category(
      id: 1,
      externalId: 'meal-category',
      name: 'Meal Plans',
    );
    const exercise = Category(
      id: 2,
      externalId: 'exercise-category',
      name: 'Exercise',
    );
    final repository = _FakeRepository(
      categories: const [meals, exercise],
      summaries: [
        ListWithCategory(
          list: ListModel(
            id: 1,
            externalId: 'weekday-meals',
            categoryId: meals.id,
            name: 'Weekday meals',
            createdAt: DateTime(2026),
          ),
          category: meals,
        ),
        ListWithCategory(
          list: ListModel(
            id: 2,
            externalId: 'morning-yoga',
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

  testWidgets('exports CSV and reports the successful save', (tester) async {
    final exporter = _FakeCsvExportService(CsvExportResult.saved);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listTrackerRepositoryProvider.overrideWithValue(_FakeRepository()),
          csvExportServiceProvider.overrideWithValue(exporter),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export CSV'));
    await tester.pumpAndSettle();

    expect(exporter.exportCalls, 1);
    expect(find.text('CSV exported.'), findsOneWidget);
  });

  testWidgets('reports a cancelled or failed CSV export', (tester) async {
    final cancelledExporter = _FakeCsvExportService(CsvExportResult.cancelled);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listTrackerRepositoryProvider.overrideWithValue(_FakeRepository()),
          csvExportServiceProvider.overrideWithValue(cancelledExporter),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export CSV'));
    await tester.pumpAndSettle();

    expect(find.text('CSV export cancelled.'), findsOneWidget);
  });

  testWidgets('reports a failed CSV export', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listTrackerRepositoryProvider.overrideWithValue(_FakeRepository()),
          csvExportServiceProvider.overrideWithValue(
            _ThrowingCsvExportService(),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export CSV'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to export CSV. Please try again.'),
      findsOneWidget,
    );
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

class _FakeCsvExportService implements CsvExportService {
  _FakeCsvExportService(this.result);

  final CsvExportResult result;
  var exportCalls = 0;

  @override
  Future<CsvExportResult> export() async {
    exportCalls += 1;
    return result;
  }
}

class _ThrowingCsvExportService implements CsvExportService {
  @override
  Future<CsvExportResult> export() => Future.error(StateError('save failed'));
}
