import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    final menu = tester.widget<PopupMenuButton<ThemeMode>>(
      find.byKey(const ValueKey('theme-mode-menu')),
    );
    final colors = Theme.of(
      tester.element(find.byKey(const ValueKey('theme-mode-menu'))),
    ).colorScheme;

    expect(menu.color, colors.surfaceContainerHigh);
    expect(menu.position, PopupMenuPosition.under);

    await tester.tap(find.byKey(const ValueKey('theme-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<ThemeMode>).first);
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
}
