import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

String _themeModeLabel(ThemeMode themeMode) => switch (themeMode) {
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
  ThemeMode.system => 'System',
};

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Theme'),
              trailing: PopupMenuButton<ThemeMode>(
                key: const ValueKey('theme-mode-menu'),
                tooltip: 'Choose theme',
                initialValue: themeMode,
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: colors.surfaceContainerHigh,
                surfaceTintColor: Colors.transparent,
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) {
                  ref.read(appThemeModeProvider.notifier).update(value);
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: ThemeMode.light,
                    checked: themeMode == ThemeMode.light,
                    child: Text('Light'),
                  ),
                  CheckedPopupMenuItem(
                    value: ThemeMode.dark,
                    checked: themeMode == ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                  CheckedPopupMenuItem(
                    value: ThemeMode.system,
                    checked: themeMode == ThemeMode.system,
                    child: Text('System'),
                  ),
                ],
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _themeModeLabel(themeMode),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colors.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.expand_more,
                            color: colors.onSecondaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
