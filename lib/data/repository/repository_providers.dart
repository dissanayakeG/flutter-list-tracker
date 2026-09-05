import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import 'category_repository.dart';
import 'entry_repository.dart';
import 'list_repository.dart';
import 'transfer_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return DriftCategoryRepository(ref.watch(appDatabaseProvider));
});

final listRepositoryProvider = Provider<ListRepository>((ref) {
  return DriftListRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(categoryRepositoryProvider),
  );
});

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return DriftEntryRepository(ref.watch(appDatabaseProvider));
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return DriftTransferRepository(ref.watch(appDatabaseProvider));
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

final listSummariesProvider = StreamProvider<List<ListWithCategory>>((ref) {
  return ref.watch(listRepositoryProvider).watchLists();
});

final listDetailProvider = StreamProvider.family<ListWithCategory?, int>(
  (ref, listId) => ref.watch(listRepositoryProvider).watchList(listId),
);

final entriesProvider = StreamProvider.family<List<Entry>, int>(
  (ref, listId) => ref.watch(entryRepositoryProvider).watchEntries(listId),
);
