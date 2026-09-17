/// Protects a CSV cell when common spreadsheet applications might interpret
/// it as a formula instead of text.
///
/// The policy prefixes formula-like values with an apostrophe and a zero-width
/// space. The zero-width space is already rejected from all user input, so the
/// marker cannot collide with valid user-entered text. The apostrophe prevents
/// spreadsheet formula evaluation, while the marker makes import reversal
/// unambiguous without changing the readable four-column CSV contract.
const csvSpreadsheetEscapeMarker = "'\u200B";

String protectCsvSpreadsheetCell(String value) {
  return _hasSpreadsheetFormulaPayload(value)
      ? '$csvSpreadsheetEscapeMarker$value'
      : value;
}

/// Restores a cell protected by [protectCsvSpreadsheetCell].
///
/// Ordinary literal apostrophes are never changed. The marker includes the
/// otherwise-invalid zero-width space, so only a protected app value matches.
String restoreCsvSpreadsheetCell(String value) {
  return value.startsWith(csvSpreadsheetEscapeMarker)
      ? value.substring(csvSpreadsheetEscapeMarker.length)
      : value;
}

bool _hasSpreadsheetFormulaPayload(String value) {
  var remaining = value.trimLeft();
  if (remaining.isEmpty) {
    return false;
  }
  return switch (remaining[0]) {
    '=' || '+' || '-' || '@' => true,
    _ => false,
  };
}
