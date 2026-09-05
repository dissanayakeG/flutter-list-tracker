import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/ui/theme/app_theme.dart';

void main() {
  test('provides consistent light and dark Material 3 themes', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.useMaterial3, isTrue);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, isNot(light.colorScheme.secondary));
    expect(light.cardTheme.shape, isA<OutlinedBorder>());
    expect(light.inputDecorationTheme.filled, isTrue);
    expect(light.filledButtonTheme.style?.minimumSize, isNotNull);
  });

  testWidgets('keeps theme roles available in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: Text('List Tracker')),
      ),
    );

    final context = tester.element(find.text('List Tracker'));
    final theme = Theme.of(context);

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.onSurface, isNot(theme.colorScheme.surface));
    expect(theme.inputDecorationTheme.enabledBorder, isNotNull);
  });
}
