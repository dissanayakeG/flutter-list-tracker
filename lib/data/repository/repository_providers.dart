import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import 'list_tracker_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final listTrackerRepositoryProvider = Provider<ListTrackerRepository>((ref) {
  return DriftListTrackerRepository(ref.watch(appDatabaseProvider));
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(listTrackerRepositoryProvider).watchCategories();
});

final listSummariesProvider = StreamProvider<List<ListWithCategory>>((ref) {
  return ref.watch(listTrackerRepositoryProvider).watchLists();
});

final listDetailProvider = StreamProvider.family<ListWithCategory?, int>(
  (ref, listId) => ref.watch(listTrackerRepositoryProvider).watchList(listId),
);

final entriesProvider = StreamProvider.family<List<Entry>, int>(
  (ref, listId) =>
      ref.watch(listTrackerRepositoryProvider).watchEntries(listId),
);
