import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _themeMenuMaxWidth = 160.0;
const _pageHorizontalGutter = 20.0;

final appThemeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void update(ThemeMode themeMode) {
    state = themeMode;
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final availableMenuWidth = math.max(
      0.0,
      MediaQuery.sizeOf(context).width - (_pageHorizontalGutter * 2),
    );
    final menuWidth = math.min(_themeMenuMaxWidth, availableMenuWidth);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                menuWidth: menuWidth,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(appThemeModeProvider.notifier).update(value);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
