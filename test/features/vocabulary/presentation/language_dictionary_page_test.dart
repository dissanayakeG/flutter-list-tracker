import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/core/database/app_database.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_providers.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_repository.dart';
import 'package:list_tracker/features/vocabulary/presentation/pages/language_pages.dart';

void main() {
  testWidgets(
    'groups words under their category General group without delete controls',
    (tester) async {
      final repository = _FakeVocabularyRepository(
        words: [
          VocabularyWordWithContext(
            word: VocabularyWord(
              id: 1,
              externalId: 'noche',
              languageId: 1,
              categoryId: 1,
              subcategoryId: null,
              word: 'noche',
              meaning: 'night, evening',
              isCompleted: false,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
            category: VocabularyCategory(
              id: 1,
              externalId: 'spanish-nouns',
              name: 'Nouns',
              createdAt: DateTime(2026),
            ),
            subcategory: null,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vocabularyRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: LanguageDictionaryPage(languageId: 1)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nouns'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('noche — night, evening'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byTooltip('Delete noche'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(repository.completedWordIds, [1]);
    },
  );
}

class _FakeVocabularyRepository implements VocabularyRepository {
  _FakeVocabularyRepository({required this.words});

  final List<VocabularyWordWithContext> words;
  final completedWordIds = <int>[];

  @override
  Stream<List<Language>> watchLanguages() => Stream.value([
    Language(
      id: 1,
      externalId: 'spanish',
      name: 'Spanish',
      createdAt: DateTime(2026),
    ),
  ]);

  @override
  Stream<List<VocabularyCategory>> watchCategories() => Stream.value([]);

  @override
  Stream<List<VocabularySubcategory>> watchSubcategories(int categoryId) =>
      Stream.value([]);

  @override
  Stream<List<VocabularyWordWithContext>> watchWordsForLanguage(
    int languageId,
  ) => Stream.value(words);

  @override
  Future<bool> setWordCompleted({
    required int id,
    required bool isCompleted,
  }) async {
    completedWordIds.add(id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
