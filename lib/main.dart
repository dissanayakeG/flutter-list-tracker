import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'ui/settings/settings_page.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: ListTrackerApp()));
}

class ListTrackerApp extends ConsumerWidget {
  const ListTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'List Tracker',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
