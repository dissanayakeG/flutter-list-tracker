String requiredText(String value, String fieldName) {
  final normalizedValue = value.trim();
  if (normalizedValue.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be blank');
  }
  return normalizedValue;
}

String? optionalText(String? value) {
  final normalizedValue = value?.trim();
  return normalizedValue == null || normalizedValue.isEmpty
      ? null
      : normalizedValue;
}

DateTime? dateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateTime(value.year, value.month, value.day);
}
