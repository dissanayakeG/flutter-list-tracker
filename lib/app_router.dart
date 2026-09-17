import 'package:go_router/go_router.dart';
import 'package:list_tracker/core/database/app_database.dart';
import 'package:list_tracker/features/lists/presentation/categories/pages/add_category_page.dart';
import 'package:list_tracker/features/lists/presentation/categories/pages/categories_page.dart';
import 'package:list_tracker/features/lists/presentation/categories/pages/edit_category_page.dart';
import 'package:list_tracker/features/lists/presentation/entries/pages/add_entry_page.dart';
import 'package:list_tracker/features/lists/presentation/entries/pages/edit_entry_page.dart';
import 'package:list_tracker/features/lists/presentation/lists/pages/add_list_page.dart';
import 'package:list_tracker/features/lists/presentation/lists/pages/edit_list_page.dart';
import 'package:list_tracker/features/lists/presentation/lists/pages/list_detail_page.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_repository.dart';
import 'package:list_tracker/features/vocabulary/presentation/pages/language_pages.dart';
import 'package:list_tracker/app/navigation/main_navigation_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const MainNavigationPage()),
      GoRoute(
        path: '/languages',
        builder: (_, _) => const MainNavigationPage(initialIndex: 2),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const MainNavigationPage(initialIndex: 3),
      ),
      GoRoute(
        path: '/languages/add',
        builder: (_, _) => const AddLanguagePage(),
      ),
      GoRoute(
        path: '/languages/:languageId',
        builder: (_, state) => LanguageDictionaryPage(
          languageId: int.parse(state.pathParameters['languageId']!),
        ),
      ),
      GoRoute(
        path: '/languages/:languageId/edit',
        builder: (_, state) => EditLanguagePage(
          languageId: int.parse(state.pathParameters['languageId']!),
        ),
      ),
      GoRoute(
        path: '/languages/:languageId/add-words',
        builder: (_, state) => AddWordsPage(
          initialLanguageId: int.parse(state.pathParameters['languageId']!),
        ),
      ),
      GoRoute(
        path: '/languages/:languageId/words/:wordId/edit',
        builder: (_, state) => EditVocabularyWordPage(
          item: state.extra as VocabularyWordWithContext,
        ),
      ),
      GoRoute(
        path: '/language-categories',
        builder: (_, _) => const VocabularyCategoryManagementPage(),
      ),
      GoRoute(
        path: '/language-categories/:categoryId',
        builder: (_, state) => VocabularySubcategoryManagementPage(
          category: state.extra as VocabularyCategory,
        ),
      ),
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
