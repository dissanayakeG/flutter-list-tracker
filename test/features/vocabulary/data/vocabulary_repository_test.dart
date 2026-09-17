import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_batch_parser.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_repository.dart';

void main() {
  late AppDatabase database;
  late DriftVocabularyRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftVocabularyRepository(database);
  });

  tearDown(() => database.close());

  test('shares category names across languages', () async {
    await repository.createLanguage('Spanish');
    final french = await repository.createLanguage('French');
    final spanishNouns = await repository.createCategory(name: 'Nouns');

    expect(spanishNouns.name, 'Nouns');
    expect(await repository.watchCategories().first, [spanishNouns]);
    await expectLater(
      repository.createCategory(name: 'Nouns'),
      throwsA(isA<Exception>()),
    );
    expect(french.name, 'French');
  });

  test('keeps general words under their required category', () async {
    final language = await repository.createLanguage('Spanish');
    final nouns = await repository.createCategory(name: 'Nouns');
    final nature = await repository.createSubcategory(
      categoryId: nouns.id,
      name: 'Nature',
    );

    await repository.createWords(
      languageId: language.id,
      categoryId: nouns.id,
      subcategoryId: null,
      drafts: const [VocabularyWordDraft(word: 'noche', meaning: 'night')],
    );
    await repository.createWords(
      languageId: language.id,
      categoryId: nouns.id,
      subcategoryId: nature.id,
      drafts: const [VocabularyWordDraft(word: 'árbol', meaning: 'tree')],
    );

    final words = await repository.watchWordsForLanguage(language.id).first;
    expect(words, hasLength(2));
    expect(
      words.where((item) => item.word.word == 'noche').single.subcategory,
      isNull,
    );
    expect(
      words.where((item) => item.word.word == 'árbol').single.subcategory!.name,
      'Nature',
    );
  });

  test(
    'rejects a subcategory from a different category without partial writes',
    () async {
      final language = await repository.createLanguage('Spanish');
      final nouns = await repository.createCategory(name: 'Nouns');
      final verbs = await repository.createCategory(name: 'Verbs');
      final routine = await repository.createSubcategory(
        categoryId: verbs.id,
        name: 'Routine',
      );

      await expectLater(
        repository.createWords(
          languageId: language.id,
          categoryId: nouns.id,
          subcategoryId: routine.id,
          drafts: const [
            VocabularyWordDraft(word: 'desayuna', meaning: 'breakfasts'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        await repository.watchWordsForLanguage(language.id).first,
        isEmpty,
      );
    },
  );

  test(
    'parses quoted comma meanings and rejects duplicate submitted pairs',
    () {
      const parser = VocabularyBatchParser();
      final draft = parser.parse('noche,"night, evening"').single;
      expect(draft.word, 'noche');
      expect(draft.meaning, 'night, evening');
      expect(
        () => parser.parse('hola,hello\nhola,hello'),
        throwsA(isA<VocabularyBatchFormatException>()),
      );
    },
  );
}
