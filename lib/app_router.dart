import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/ui/categories/pages/add_category_page.dart';
import 'package:list_tracker/ui/categories/pages/categories_page.dart';
import 'package:list_tracker/ui/categories/pages/edit_category_page.dart';
import 'package:list_tracker/ui/entries/pages/add_entry_page.dart';
import 'package:list_tracker/ui/entries/pages/edit_entry_page.dart';
import 'package:list_tracker/ui/lists/pages/add_list_page.dart';
import 'package:list_tracker/ui/lists/pages/edit_list_page.dart';
import 'package:list_tracker/ui/lists/pages/list_detail_page.dart';
import 'package:list_tracker/ui/settings/settings_page.dart';
import 'package:list_tracker/ui/dashboard/dashboard_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/add-list', builder: (_, _) => const AddListPage()),
      GoRoute(path: '/categories', builder: (_, _) => const CategoriesPage()),
      GoRoute(
        path: '/categories/add',
        builder: (_, _) => const AddCategoryPage(),
      ),
      GoRoute(
        path: '/categories/:categoryId/edit',
        builder: (_, state) => EditCategoryPage(
          categoryId: int.parse(state.pathParameters['categoryId']!),
        ),
      ),
      GoRoute(
        path: '/lists/:listId',
        builder: (_, state) =>
            ListDetailPage(listId: int.parse(state.pathParameters['listId']!)),
      ),
      GoRoute(
        path: '/lists/:listId/edit',
        builder: (_, state) =>
            EditListPage(listId: int.parse(state.pathParameters['listId']!)),
      ),
      GoRoute(
        path: '/lists/:listId/add-entry',
        builder: (_, state) =>
            AddEntryPage(listId: int.parse(state.pathParameters['listId']!)),
      ),
      GoRoute(
        path: '/lists/:listId/entries/:entryId/edit',
        builder: (_, state) => EditEntryPage(
          listId: int.parse(state.pathParameters['listId']!),
          entry: state.extra as Entry?,
        ),
      ),
    ],
  );
}
