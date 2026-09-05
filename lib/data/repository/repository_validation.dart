const categoryNameMaxLength = 100;
const listNameMaxLength = 200;
const listNoteMaxLength = 2000;
const entryContentMaxLength = 5000;
const entryDateMinYear = 1900;
const entryDateMaxYear = 2100;

class InputValidationException implements Exception {
  const InputValidationException(this.fieldName, this.message);

  final String fieldName;
  final String message;

  @override
  String toString() => message;
}

String requiredText(
  String value,
  String fieldName, {
  int maxLength = entryContentMaxLength,
  bool allowLineBreaks = false,
}) {
  try {
    return normalizeRequiredText(
      value,
      fieldName: fieldName,
      maxLength: maxLength,
      allowLineBreaks: allowLineBreaks,
    );
  } on InputValidationException catch (error) {
    throw ArgumentError.value(value, fieldName, error.message);
  }
}

String requiredName(
  String value, {
  required String fieldName,
  required int maxLength,
}) {
  try {
    return normalizeName(value, fieldName: fieldName, maxLength: maxLength);
  } on InputValidationException catch (error) {
    throw ArgumentError.value(value, fieldName, error.message);
  }
}

String? optionalText(
  String? value, {
  String fieldName = 'value',
  int maxLength = entryContentMaxLength,
  bool allowLineBreaks = false,
}) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final normalizedValue = value.trim();

  try {
    return normalizeText(
      normalizedValue,
      fieldName: fieldName,
      maxLength: maxLength,
      allowLineBreaks: allowLineBreaks,
    );
  } on InputValidationException catch (error) {
    throw ArgumentError.value(value, fieldName, error.message);
  }
}

String normalizeRequiredText(
  String value, {
  required String fieldName,
  required int maxLength,
  bool allowLineBreaks = false,
}) {
  final normalizedValue = value.trim();
  if (normalizedValue.isEmpty) {
    throw InputValidationException(fieldName, 'must not be blank.');
  }
  return normalizeText(
    normalizedValue,
    fieldName: fieldName,
    maxLength: maxLength,
    allowLineBreaks: allowLineBreaks,
  );
}

String normalizeText(
  String value, {
  required String fieldName,
  required int maxLength,
  bool allowLineBreaks = false,
}) {
  _validateUtf16(value, fieldName);
  final length = value.runes.length;
  if (length > maxLength) {
    throw InputValidationException(
      fieldName,
      'must be $maxLength characters or fewer.',
    );
  }

  for (final codePoint in value.runes) {
    final isLineBreak = codePoint == 0x0a || codePoint == 0x0d;
    final isTab = codePoint == 0x09;
    final isAsciiControl = codePoint < 0x20 || codePoint == 0x7f;
    final isC1Control = codePoint >= 0x80 && codePoint <= 0x9f;
    final isZeroWidthSpace = codePoint == 0x200b;
    final isBidiOverride =
        codePoint >= 0x202a && codePoint <= 0x202e ||
        codePoint >= 0x2066 && codePoint <= 0x2069;

    if ((isAsciiControl &&
            !(allowLineBreaks && isLineBreak) &&
            !(allowLineBreaks && isTab)) ||
        isC1Control ||
        isZeroWidthSpace ||
        isBidiOverride) {
      throw InputValidationException(
        fieldName,
        'contains unsupported control characters.',
      );
    }
  }

  return value;
}

String normalizeName(
  String value, {
  required String fieldName,
  required int maxLength,
}) {
  final normalizedValue = normalizeRequiredText(
    value,
    fieldName: fieldName,
    maxLength: maxLength,
  );
  if (!RegExp(r'\p{L}|\p{N}', unicode: true).hasMatch(normalizedValue)) {
    throw InputValidationException(
      fieldName,
      'must contain at least one letter or number.',
    );
  }
  if (_containsForbiddenCodePointNotation(normalizedValue)) {
    throw InputValidationException(
      fieldName,
      'contains a blocked control-code notation.',
    );
  }
  return normalizedValue;
}

bool _containsForbiddenCodePointNotation(String value) {
  final notation = RegExp(r'(?:\\u|u\+)([0-9a-f]{4,6})', caseSensitive: false);
  for (final match in notation.allMatches(value)) {
    final codePoint = int.parse(match.group(1)!, radix: 16);
    if (_isForbiddenNameCodePoint(codePoint)) {
      return true;
    }
  }
  return false;
}

bool _isForbiddenNameCodePoint(int codePoint) {
  return codePoint <= 0x1f ||
      codePoint == 0x7f ||
      codePoint >= 0x80 && codePoint <= 0x9f ||
      codePoint == 0x200b ||
      codePoint >= 0x202a && codePoint <= 0x202e ||
      codePoint >= 0x2066 && codePoint <= 0x2069;
}

void _validateUtf16(String value, String fieldName) {
  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    final isHighSurrogate = codeUnit >= 0xd800 && codeUnit <= 0xdbff;
    final isLowSurrogate = codeUnit >= 0xdc00 && codeUnit <= 0xdfff;
    if (isHighSurrogate) {
      if (index + 1 >= value.length) {
        throw InputValidationException(fieldName, 'contains invalid Unicode.');
      }
      final nextCodeUnit = value.codeUnitAt(index + 1);
      if (nextCodeUnit < 0xdc00 || nextCodeUnit > 0xdfff) {
        throw InputValidationException(fieldName, 'contains invalid Unicode.');
      }
      index += 1;
    } else if (isLowSurrogate) {
      throw InputValidationException(fieldName, 'contains invalid Unicode.');
    }
  }
}

String? validateRequiredText({
  required String? value,
  required String label,
  required String fieldName,
  required int maxLength,
  bool allowLineBreaks = false,
}) {
  if (value == null || value.trim().isEmpty) {
    final article = RegExp(r'^[aeiou]', caseSensitive: false).hasMatch(label)
        ? 'an'
        : 'a';
    return 'Enter $article $label.';
  }
  try {
    normalizeRequiredText(
      value,
      fieldName: fieldName,
      maxLength: maxLength,
      allowLineBreaks: allowLineBreaks,
    );
  } on InputValidationException catch (error) {
    return error.message[0].toUpperCase() + error.message.substring(1);
  }
  return null;
}

String? validateName({
  required String? value,
  required String label,
  required String fieldName,
  required int maxLength,
}) {
  if (value == null || value.trim().isEmpty) {
    return 'Enter a $label.';
  }
  try {
    normalizeName(value, fieldName: fieldName, maxLength: maxLength);
  } on InputValidationException catch (error) {
    return error.message[0].toUpperCase() + error.message.substring(1);
  }
  return null;
}

String? validateOptionalText({
  required String? value,
  required String label,
  required String fieldName,
  required int maxLength,
  bool allowLineBreaks = false,
}) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    normalizeText(
      value.trim(),
      fieldName: fieldName,
      maxLength: maxLength,
      allowLineBreaks: allowLineBreaks,
    );
  } on InputValidationException catch (error) {
    return error.message[0].toUpperCase() + error.message.substring(1);
  }
  return null;
}

DateTime? dateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  if (value.year < entryDateMinYear || value.year > entryDateMaxYear) {
    throw ArgumentError.value(
      value,
      'date',
      'must be between $entryDateMinYear and $entryDateMaxYear.',
    );
  }
  return DateTime(value.year, value.month, value.day);
}
