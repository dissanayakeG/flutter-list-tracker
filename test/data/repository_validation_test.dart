import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/repository/repository_validation.dart';

void main() {
  test('accepts Unicode, punctuation, and SQL-like text as data', () {
    expect(
      requiredText(
        '''O'Brien's list; DROP TABLE entries; 日本語''',
        'name',
        maxLength: listNameMaxLength,
      ),
      '''O'Brien's list; DROP TABLE entries; 日本語''',
    );
  });

  test('normalizes surrounding whitespace and allows entry line breaks', () {
    expect(
      requiredText(
        '  First line\nSecond line  ',
        'content',
        maxLength: entryContentMaxLength,
        allowLineBreaks: true,
      ),
      'First line\nSecond line',
    );
  });

  test('rejects oversized and unsafe text at the repository boundary', () {
    expect(
      () => requiredText(
        'a' * (categoryNameMaxLength + 1),
        'name',
        maxLength: categoryNameMaxLength,
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          requiredText('Books\u0000', 'name', maxLength: categoryNameMaxLength),
      throwsArgumentError,
    );
    expect(
      () =>
          requiredText('Books\u202e', 'name', maxLength: categoryNameMaxLength),
      throwsArgumentError,
    );
    expect(
      () => requiredText(
        String.fromCharCodes([0xd800]),
        'name',
        maxLength: categoryNameMaxLength,
      ),
      throwsArgumentError,
    );
    expect(
      () => requiredName(
        '!!!',
        fieldName: 'name',
        maxLength: categoryNameMaxLength,
      ),
      throwsArgumentError,
    );
    expect(
      () => requiredName(
        r'NUL: \u0000',
        fieldName: 'name',
        maxLength: categoryNameMaxLength,
      ),
      throwsArgumentError,
    );
    expect(
      () => requiredName(
        'Books\u200b',
        fieldName: 'name',
        maxLength: categoryNameMaxLength,
      ),
      throwsArgumentError,
    );
  });

  test(
    'rejects every blocked code point and its literal notation in names',
    () {
      const blockedCodePoints = [
        0x0000,
        0x001f,
        0x007f,
        0x0080,
        0x009f,
        0x200b,
        0x202a,
        0x202e,
        0x2066,
        0x2069,
      ];

      for (final codePoint in blockedCodePoints) {
        final notation = 'U+${codePoint.toRadixString(16).padLeft(4, '0')}';
        expect(
          () => requiredName(
            'Reserved ${String.fromCharCode(codePoint)}',
            fieldName: 'name',
            maxLength: categoryNameMaxLength,
          ),
          throwsArgumentError,
          reason: 'actual $notation must be rejected',
        );
        expect(
          () => requiredName(
            'Reserved $notation',
            fieldName: 'name',
            maxLength: categoryNameMaxLength,
          ),
          throwsArgumentError,
          reason: 'literal $notation must be rejected',
        );
      }
    },
  );

  test('form validators report invalid optional and required text', () {
    expect(
      validateRequiredText(
        value: '  ',
        label: 'category name',
        fieldName: 'category name',
        maxLength: categoryNameMaxLength,
      ),
      'Enter a category name.',
    );
    expect(
      validateName(
        value: '!!!',
        label: 'category name',
        fieldName: 'category name',
        maxLength: categoryNameMaxLength,
      ),
      contains('letter or number'),
    );
    expect(
      validateOptionalText(
        value: 'a' * (listNoteMaxLength + 1),
        label: 'note',
        fieldName: 'note',
        maxLength: listNoteMaxLength,
        allowLineBreaks: true,
      ),
      contains('characters or fewer'),
    );
    expect(
      validateRequiredText(
        value: 'Read\u0000',
        label: 'entry',
        fieldName: 'entry',
        maxLength: entryContentMaxLength,
        allowLineBreaks: true,
      ),
      contains('control characters'),
    );
  });
}
