import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:list_tracker/core/database/app_database.dart';
import 'package:list_tracker/features/lists/data/repositories/repository_providers.dart';

import 'vocabulary_repository.dart';

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return DriftVocabularyRepository(ref.watch(appDatabaseProvider));
});

final languagesProvider = StreamProvider<List<Language>>((ref) {
  return ref.watch(vocabularyRepositoryProvider).watchLanguages();
});

final vocabularyCategoriesProvider = StreamProvider<List<VocabularyCategory>>(
  (ref) => ref.watch(vocabularyRepositoryProvider).watchCategories(),
);

final vocabularySubcategoriesProvider =
    StreamProvider.family<List<VocabularySubcategory>, int>((ref, categoryId) {
      return ref
          .watch(vocabularyRepositoryProvider)
          .watchSubcategories(categoryId);
    });

final vocabularyWordsProvider =
    StreamProvider.family<List<VocabularyWordWithContext>, int>(
      (ref, languageId) => ref
          .watch(vocabularyRepositoryProvider)
          .watchWordsForLanguage(languageId),
    );
