import 'package:csv/csv.dart';
import 'package:list_tracker/core/validation/repository_validation.dart';

class VocabularyWordDraft {
  const VocabularyWordDraft({required this.word, required this.meaning});

  final String word;
  final String meaning;
}

class VocabularyBatchFormatException implements Exception {
  const VocabularyBatchFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VocabularyBatchParser {
  const VocabularyBatchParser();

  List<VocabularyWordDraft> parse(String source) {
    final rows = source.split(RegExp(r'\r?\n'));
    final drafts = <VocabularyWordDraft>[];
    final duplicateKeys = <(String, String)>{};

    for (var index = 0; index < rows.length; index++) {
      final line = rows[index];
      if (line.trim().isEmpty) {
        continue;
      }
      final rowNumber = index + 1;
      _validateLineSyntax(line, rowNumber);
      late List<dynamic> row;
      try {
        final decoded = Csv(autoDetect: false).decode(line);
        if (decoded.length != 1) {
          throw const FormatException();
        }
        row = decoded.single;
      } catch (_) {
        throw VocabularyBatchFormatException(
          'Line $rowNumber has malformed CSV quoting.',
        );
      }
      if (row.length != 2) {
        throw VocabularyBatchFormatException(
          'Line $rowNumber must contain a word and meaning separated by one comma.',
        );
      }

      final word = _validateField(
        row[0].toString(),
        rowNumber: rowNumber,
        field: 'word',
        maxLength: vocabularyWordMaxLength,
      );
      final meaning = _validateField(
        row[1].toString(),
        rowNumber: rowNumber,
        field: 'meaning',
        maxLength: vocabularyMeaningMaxLength,
      );
      if (!duplicateKeys.add((word, meaning))) {
        throw VocabularyBatchFormatException(
          'Line $rowNumber repeats the word and meaning from an earlier line.',
        );
      }
      drafts.add(VocabularyWordDraft(word: word, meaning: meaning));
    }

    if (drafts.isEmpty) {
      throw const VocabularyBatchFormatException('Enter at least one word.');
    }
    return List.unmodifiable(drafts);
  }

  String _validateField(
    String value, {
    required int rowNumber,
    required String field,
    required int maxLength,
  }) {
    try {
      return normalizeRequiredText(
        value,
        fieldName: field,
        maxLength: maxLength,
      );
    } on InputValidationException catch (error) {
      final needsField = error.message == 'must not be blank.';
      throw VocabularyBatchFormatException(
        needsField
            ? 'Line $rowNumber needs a $field.'
            : 'Line $rowNumber has an invalid $field: ${error.message}',
      );
    }
  }

  void _validateLineSyntax(String line, int rowNumber) {
    var inQuotes = false;
    var atFieldStart = true;
    var afterClosingQuote = false;
    for (var index = 0; index < line.length; index++) {
      final character = line[index];
      if (inQuotes) {
        if (character == '"') {
          if (index + 1 < line.length && line[index + 1] == '"') {
            index += 1;
          } else {
            inQuotes = false;
            afterClosingQuote = true;
          }
        }
        continue;
      }
      if (afterClosingQuote) {
        if (character == ',') {
          atFieldStart = true;
          afterClosingQuote = false;
          continue;
        }
        throw VocabularyBatchFormatException(
          'Line $rowNumber has malformed CSV quoting.',
        );
      }
      if (character == '"') {
        if (!atFieldStart) {
          throw VocabularyBatchFormatException(
            'Line $rowNumber has malformed CSV quoting.',
          );
        }
        inQuotes = true;
        atFieldStart = false;
      } else if (character == ',') {
        atFieldStart = true;
      } else {
        atFieldStart = false;
      }
    }
    if (inQuotes) {
      throw VocabularyBatchFormatException(
        'Line $rowNumber has malformed CSV quoting.',
      );
    }
  }
}
