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
  });

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
