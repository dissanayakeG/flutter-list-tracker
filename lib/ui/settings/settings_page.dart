import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'list_transfer_actions.dart';
import '../../data/repository/repository_providers.dart';

final appThemeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final subscription = ref
        .watch(preferenceRepositoryProvider)
        .watchThemeMode()
        .listen((value) {
          final next = ThemeMode.values.byName(value);
          if (state != next) state = next;
        });
    ref.onDispose(subscription.cancel);
    return ThemeMode.dark;
  }

  void update(ThemeMode themeMode) {
    state = themeMode;
    unawaited(
      ref.read(preferenceRepositoryProvider).saveThemeMode(themeMode.name),
    );
  }
}

String _themeModeLabel(ThemeMode themeMode) => switch (themeMode) {
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
  ThemeMode.system => 'System',
};

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _isImporting = false;
  var _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final themeMode = ref.watch(appThemeModeProvider);
    final transferActions = ListTransferActions(
      context: context,
      ref: ref,
      onImportingChanged: (value) {
        if (mounted) setState(() => _isImporting = value);
      },
      onExportingChanged: (value) {
        if (mounted) setState(() => _isExporting = value);
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            _ThemeSelectionTile(
              colors: colors,
              themeMode: themeMode,
              onSelected: (value) {
                ref.read(appThemeModeProvider.notifier).update(value);
              },
            ),
            const Divider(),
            const _SettingsSectionTitle('Lists'),
            _SettingsActionTile(
              title: 'Import lists',
              icon: Icons.file_upload_outlined,
              isBusy: _isImporting,
              onTap: _isExporting ? null : transferActions.importCsv,
            ),
            _SettingsActionTile(
              title: 'Export lists',
              icon: Icons.file_download_outlined,
              isBusy: _isExporting,
              onTap: _isImporting ? null : transferActions.exportCsv,
            ),
            const _NavigationSettingsTile(
              title: 'Manage list categories',
              icon: Icons.category_outlined,
              route: '/categories',
            ),
            const Divider(),
            const _SettingsSectionTitle('Languages'),
            const _NavigationSettingsTile(
              title: 'Language categories',
              icon: Icons.account_tree_outlined,
              route: '/language-categories',
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSelectionTile extends StatelessWidget {
  const _ThemeSelectionTile({
    required this.colors,
    required this.themeMode,
    required this.onSelected,
  });

  final ColorScheme colors;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: ThemeMode.values
                .map(
                  (mode) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: mode == ThemeMode.system ? 0 : 8,
                      ),
                      child: _ThemeChoice(
                        mode: mode,
                        selected: mode == themeMode,
                        onTap: () => onSelected(mode),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('theme-choice-${mode.name}'),
    color: selected
        ? Theme.of(context).colorScheme.secondaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(switch (mode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
            const SizedBox(height: 4),
            Text(
              _themeModeLabel(mode),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.title,
    required this.icon,
    required this.isBusy,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: isBusy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: isBusy ? null : onTap,
    );
  }
}

class _NavigationSettingsTile extends StatelessWidget {
  const _NavigationSettingsTile({
    required this.title,
    required this.icon,
    required this.route,
  });

  final String title;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
