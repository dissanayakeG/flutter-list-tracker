import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/local/app_database.dart';
import 'ui/add_list/add_list_page.dart';
import 'ui/add_entry/add_entry_page.dart';
import 'ui/categories/categories_page.dart';
import 'ui/dashboard/dashboard_page.dart';
import 'ui/list_detail/list_detail_page.dart';

void main() {
  runApp(const ProviderScope(child: ListTrackerApp()));
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
    GoRoute(path: '/add-list', builder: (_, _) => const AddListPage()),
    GoRoute(path: '/categories', builder: (_, _) => const CategoriesPage()),
    GoRoute(
      path: '/categories/add',
      builder: (_, _) => const AddCategoryPage(),
    ),
    GoRoute(
      path: '/lists/:listId',
      builder: (_, state) =>
          ListDetailPage(listId: int.parse(state.pathParameters['listId']!)),
    ),
    GoRoute(
      path: '/lists/:listId/add-entry',
      builder: (_, state) =>
          AddEntryPage(listId: int.parse(state.pathParameters['listId']!)),
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

class ListTrackerApp extends StatelessWidget {
  const ListTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'List Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 6, 207, 221),
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
