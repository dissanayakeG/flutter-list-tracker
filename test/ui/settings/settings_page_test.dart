import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/transfer/csv_export_providers.dart';
import 'package:list_tracker/data/transfer/csv_export_service.dart';
import 'package:list_tracker/ui/settings/settings_page.dart';

void main() {
  testWidgets('updates the shared theme mode when a selection changes', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );

    expect(find.byKey(const ValueKey('theme-choice-light')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-choice-dark')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-choice-system')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-choice-light')));
    await tester.pumpAndSettle();

    expect(container.read(appThemeModeProvider), ThemeMode.light);
  });

  testWidgets('renders on a narrow display with large system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('opens Category Management from Settings', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/categories',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Category Management'))),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage list categories'));
    await tester.pumpAndSettle();

    expect(find.text('Category Management'), findsOneWidget);
  });

  testWidgets('exports Lists from Settings', (tester) async {
    final container = ProviderContainer(
      overrides: [
        csvExportServiceProvider.overrideWithValue(_FakeCsvExportService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export lists'));
    await tester.pumpAndSettle();

    expect(find.text('CSV exported.'), findsOneWidget);
  });
}

class _FakeCsvExportService implements CsvExportService {
  @override
  Future<CsvExportResult> export() async => CsvExportResult.saved;
}
