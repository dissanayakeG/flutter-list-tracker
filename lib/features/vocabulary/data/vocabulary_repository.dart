import 'package:drift/drift.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/repository_validation.dart';

import 'vocabulary_batch_parser.dart';

class VocabularyWordWithContext {
  const VocabularyWordWithContext({
    required this.word,
    required this.category,
    required this.subcategory,
  });

  final VocabularyWord word;
  final VocabularyCategory category;
  final VocabularySubcategory? subcategory;
}

abstract interface class VocabularyRepository {
  Stream<List<Language>> watchLanguages();
  Stream<List<VocabularyCategory>> watchCategories();
  Stream<List<VocabularySubcategory>> watchSubcategories(int categoryId);
  Stream<List<VocabularyWordWithContext>> watchWordsForLanguage(int languageId);

  Future<Language> createLanguage(String name);
  Future<bool> updateLanguage({required int id, required String name});
  Future<VocabularyCategory> createCategory({required String name});
  Future<bool> updateCategory({required int id, required String name});
  Future<VocabularySubcategory> createSubcategory({
    required int categoryId,
    required String name,
  });
  Future<bool> updateSubcategory({required int id, required String name});
  Future<int> createWords({
    required int languageId,
    required int categoryId,
    required int? subcategoryId,
    required List<VocabularyWordDraft> drafts,
  });
  Future<bool> updateWord({
    required int id,
    required int languageId,
    required int categoryId,
    required int? subcategoryId,
    required String word,
    required String meaning,
  });
  Future<bool> setWordCompleted({required int id, required bool isCompleted});
}

class DriftVocabularyRepository implements VocabularyRepository {
  DriftVocabularyRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Language>> watchLanguages() {
    final query = _database.select(_database.languages)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  @override
  Stream<List<VocabularyCategory>> watchCategories() {
    final query = _database.select(_database.vocabularyCategories)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  @override
  Stream<List<VocabularySubcategory>> watchSubcategories(int categoryId) {
    final query = _database.select(_database.vocabularySubcategories)
      ..where((table) => table.categoryId.equals(categoryId))
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  @override
  Stream<List<VocabularyWordWithContext>> watchWordsForLanguage(
    int languageId,
  ) {
    final query =
        _database.select(_database.vocabularyWords).join([
            innerJoin(
              _database.vocabularyCategories,
              _database.vocabularyCategories.id.equalsExp(
                _database.vocabularyWords.categoryId,
              ),
            ),
            leftOuterJoin(
              _database.vocabularySubcategories,
              _database.vocabularySubcategories.id.equalsExp(
                _database.vocabularyWords.subcategoryId,
              ),
            ),
          ])
          ..where(_database.vocabularyWords.languageId.equals(languageId))
          ..orderBy([
            OrderingTerm.asc(_database.vocabularyCategories.name),
            OrderingTerm.asc(_database.vocabularySubcategories.name),
            OrderingTerm.asc(_database.vocabularyWords.word),
          ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => VocabularyWordWithContext(
              word: row.readTable(_database.vocabularyWords),
              category: row.readTable(_database.vocabularyCategories),
              subcategory: row.readTableOrNull(
                _database.vocabularySubcategories,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Language> createLanguage(String name) async {
    final id = await _database
        .into(_database.languages)
        .insert(
          LanguagesCompanion.insert(
            name: requiredName(
              name,
              fieldName: 'language',
              maxLength: languageNameMaxLength,
            ),
          ),
        );
    return (_database.select(
      _database.languages,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  @override
  Future<bool> updateLanguage({required int id, required String name}) async {
    final count =
        await (_database.update(
          _database.languages,
        )..where((table) => table.id.equals(id))).write(
          LanguagesCompanion(
            name: Value(
              requiredName(
                name,
                fieldName: 'language',
                maxLength: languageNameMaxLength,
              ),
            ),
          ),
        );
    return count == 1;
  }

  @override
  Future<VocabularyCategory> createCategory({required String name}) async {
    final id = await _database
        .into(_database.vocabularyCategories)
        .insert(
          VocabularyCategoriesCompanion.insert(
            name: requiredName(
              name,
              fieldName: 'category',
              maxLength: vocabularyCategoryNameMaxLength,
            ),
          ),
        );
    return (_database.select(
      _database.vocabularyCategories,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  @override
  Future<bool> updateCategory({required int id, required String name}) async {
    final count =
        await (_database.update(
          _database.vocabularyCategories,
        )..where((table) => table.id.equals(id))).write(
          VocabularyCategoriesCompanion(
            name: Value(
              requiredName(
                name,
                fieldName: 'category',
                maxLength: vocabularyCategoryNameMaxLength,
              ),
            ),
          ),
        );
    return count == 1;
  }

  @override
  Future<VocabularySubcategory> createSubcategory({
    required int categoryId,
    required String name,
  }) async {
    final id = await _database
        .into(_database.vocabularySubcategories)
        .insert(
          VocabularySubcategoriesCompanion.insert(
            categoryId: categoryId,
            name: requiredName(
              name,
              fieldName: 'subcategory',
              maxLength: vocabularySubcategoryNameMaxLength,
            ),
          ),
        );
    return (_database.select(
      _database.vocabularySubcategories,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  @override
  Future<bool> updateSubcategory({
    required int id,
    required String name,
  }) async {
    final count =
        await (_database.update(
          _database.vocabularySubcategories,
        )..where((table) => table.id.equals(id))).write(
          VocabularySubcategoriesCompanion(
            name: Value(
              requiredName(
                name,
                fieldName: 'subcategory',
                maxLength: vocabularySubcategoryNameMaxLength,
              ),
            ),
          ),
        );
    return count == 1;
  }

  @override
  Future<int> createWords({
    required int languageId,
    required int categoryId,
    required int? subcategoryId,
    required List<VocabularyWordDraft> drafts,
  }) {
    return _database.transaction(() async {
      await _validateDestination(
        languageId: languageId,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
      );
      if (drafts.isEmpty) {
        throw ArgumentError.value(drafts, 'drafts', 'must not be empty.');
      }
      final normalized = <VocabularyWordDraft>[];
      final seen = <(String, String)>{};
      for (final draft in drafts) {
        final word = requiredText(
          draft.word,
          'word',
          maxLength: vocabularyWordMaxLength,
        );
        final meaning = requiredText(
          draft.meaning,
          'meaning',
          maxLength: vocabularyMeaningMaxLength,
        );
        if (!seen.add((word, meaning))) {
          throw ArgumentError.value(
            drafts,
            'drafts',
            'contains duplicate pairs.',
          );
        }
        await _ensureWordDoesNotExist(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          word: word,
          meaning: meaning,
        );
        normalized.add(VocabularyWordDraft(word: word, meaning: meaning));
      }
      await _database.batch((batch) {
        batch.insertAll(
          _database.vocabularyWords,
          normalized
              .map(
                (draft) => VocabularyWordsCompanion.insert(
                  languageId: languageId,
                  categoryId: categoryId,
                  subcategoryId: Value(subcategoryId),
                  word: draft.word,
                  meaning: draft.meaning,
                ),
              )
              .toList(growable: false),
        );
      });
      return normalized.length;
    });
  }

  @override
  Future<bool> updateWord({
    required int id,
    required int languageId,
    required int categoryId,
    required int? subcategoryId,
    required String word,
    required String meaning,
  }) async {
    await _validateDestination(
      languageId: languageId,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
    );
    final count =
        await (_database.update(
          _database.vocabularyWords,
        )..where((table) => table.id.equals(id))).write(
          VocabularyWordsCompanion(
            languageId: Value(languageId),
            categoryId: Value(categoryId),
            subcategoryId: Value(subcategoryId),
            word: Value(
              requiredText(word, 'word', maxLength: vocabularyWordMaxLength),
            ),
            meaning: Value(
              requiredText(
                meaning,
                'meaning',
                maxLength: vocabularyMeaningMaxLength,
              ),
            ),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return count == 1;
  }

  @override
  Future<bool> setWordCompleted({
    required int id,
    required bool isCompleted,
  }) async {
    final count =
        await (_database.update(
          _database.vocabularyWords,
        )..where((table) => table.id.equals(id))).write(
          VocabularyWordsCompanion(
            isCompleted: Value(isCompleted),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return count == 1;
  }

  Future<void> _validateDestination({
    required int languageId,
    required int categoryId,
    required int? subcategoryId,
  }) async {
    final language = await (_database.select(
      _database.languages,
    )..where((table) => table.id.equals(languageId))).getSingleOrNull();
    if (language == null) {
      throw ArgumentError.value(languageId, 'languageId', 'does not exist.');
    }
    final category = await (_database.select(
      _database.vocabularyCategories,
    )..where((table) => table.id.equals(categoryId))).getSingleOrNull();
    if (category == null) {
      throw ArgumentError.value(categoryId, 'categoryId', 'does not exist.');
    }
    if (subcategoryId == null) {
      return;
    }
    final subcategory = await (_database.select(
      _database.vocabularySubcategories,
    )..where((table) => table.id.equals(subcategoryId))).getSingleOrNull();
    if (subcategory == null || subcategory.categoryId != category.id) {
      throw ArgumentError.value(
        subcategoryId,
        'subcategoryId',
        'must belong to the selected category.',
      );
    }
  }

  Future<void> _ensureWordDoesNotExist({
    required int categoryId,
    required int? subcategoryId,
    required String word,
    required String meaning,
  }) async {
    final query = _database.select(_database.vocabularyWords)
      ..where(
        (table) =>
            table.categoryId.equals(categoryId) &
            table.word.equals(word) &
            table.meaning.equals(meaning),
      );
    if (subcategoryId == null) {
      query.where((table) => table.subcategoryId.isNull());
    } else {
      query.where((table) => table.subcategoryId.equals(subcategoryId));
    }
    if (await query.getSingleOrNull() != null) {
      throw ArgumentError('A matching word already exists in this group.');
    }
  }
}
