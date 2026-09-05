import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../repository/repository_validation.dart';
import '../repository/transfer_repository.dart';
import 'csv_export_service.dart';
import 'csv_import_models.dart';
import 'csv_spreadsheet_protection.dart';

abstract interface class CsvImportService {
  Future<CsvImportPreparation> prepare();
  Future<CsvImportResult> importEntries(CsvImportDocument document);
}

sealed class CsvImportPreparation {
  const CsvImportPreparation();
}

class CsvImportCancelled extends CsvImportPreparation {
  const CsvImportCancelled();
}

class CsvImportInvalid extends CsvImportPreparation {
  const CsvImportInvalid(this.message);

  final String message;
}

class CsvImportNeedsSetup extends CsvImportPreparation {
  const CsvImportNeedsSetup(this.preview);

  final CsvImportPreview preview;
}

class CsvImportReady extends CsvImportPreparation {
  const CsvImportReady({required this.document, required this.preview});

  final CsvImportDocument document;
  final CsvImportPreview preview;
}

abstract interface class CsvFileOpenGateway {
  Future<Uint8List?> openCsv();
}

class FilePickerCsvFileOpenGateway implements CsvFileOpenGateway {
  const FilePickerCsvFileOpenGateway();

  @override
  Future<Uint8List?> openCsv() async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (selection == null) {
      return null;
    }
    return selection.readAsBytes();
  }
}

class RepositoryCsvImportService implements CsvImportService {
  RepositoryCsvImportService({
    required this.repository,
    required this.fileOpenGateway,
    CsvImportParser? parser,
  }) : _parser = parser ?? const CsvImportParser();

  final TransferRepository repository;
  final CsvFileOpenGateway fileOpenGateway;
  final CsvImportParser _parser;

  @override
  Future<CsvImportPreparation> prepare() async {
    final bytes = await fileOpenGateway.openCsv();
    if (bytes == null) {
      return const CsvImportCancelled();
    }
    if (bytes.length > maxCsvImportBytes) {
      return const CsvImportInvalid(
        'The CSV file is too large. The maximum size is 5 MB.',
      );
    }

    late CsvImportDocument document;
    try {
      document = _parser.parse(utf8.decode(bytes));
    } on CsvImportFormatException catch (error) {
      return CsvImportInvalid(error.message);
    } on FormatException {
      return const CsvImportInvalid('The file must be valid UTF-8 CSV.');
    }

    final preview = await repository.previewCsvImport(document);
    if (preview.hasBlockingReferences) {
      return CsvImportNeedsSetup(preview);
    }
    return CsvImportReady(document: document, preview: preview);
  }

  @override
  Future<CsvImportResult> importEntries(CsvImportDocument document) {
    return repository.importCsvEntries(document);
  }
}

class CsvImportParser {
  const CsvImportParser();

  CsvImportDocument parse(String contents) {
    final source = contents.startsWith(csvUtf8Bom)
        ? contents.substring(1)
        : contents;
    if (source.startsWith('sep=')) {
      throw const CsvImportFormatException(
        'Row 1 must be exactly: category,list,entry,date.',
      );
    }
    late List<List<dynamic>> rows;
    try {
      _validateCsvSyntax(source);
      rows = Csv(autoDetect: false).decode(source);
    } on CsvImportFormatException {
      rethrow;
    } catch (_) {
      throw const CsvImportFormatException('The CSV file is malformed.');
    }

    if (rows.isEmpty || !_isExpectedHeader(rows.first)) {
      throw const CsvImportFormatException(
        'Row 1 must be exactly: category,list,entry,date.',
      );
    }
    if (rows.length - 1 > maxCsvImportDataRows) {
      throw const CsvImportFormatException(
        'The CSV file contains too many data rows. The maximum is 10,000.',
      );
    }

    final categoryNames = <String>{};
    final listReferences = <CsvListReference>{};
    final entries = <CsvImportEntry>[];
    final structuralCategories = <String>{};
    final structuralLists = <CsvListReference>{};

    for (var index = 1; index < rows.length; index++) {
      final rowNumber = index + 1;
      final row = rows[index];
      if (row.length != csvHeader.length) {
        throw CsvImportFormatException(
          'Row $rowNumber must have exactly ${csvHeader.length} columns.',
        );
      }

      final categoryName = _validatedField(
        row[0],
        rowNumber: rowNumber,
        fieldName: 'category',
        maxLength: categoryNameMaxLength,
        isName: true,
      );
      final listName = _optionalValidatedField(
        row[1],
        rowNumber: rowNumber,
        fieldName: 'list',
        maxLength: listNameMaxLength,
        isName: true,
      );
      final content = _optionalValidatedField(
        row[2],
        rowNumber: rowNumber,
        fieldName: 'entry',
        maxLength: entryContentMaxLength,
        allowLineBreaks: true,
      );
      final dateText = _field(row[3]);

      if (content.isEmpty && dateText.isNotEmpty) {
        throw CsvImportFormatException(
          'Row $rowNumber has a date without an entry.',
        );
      }
      if (content.isNotEmpty && listName.isEmpty) {
        throw CsvImportFormatException(
          'Row $rowNumber has an entry without a list.',
        );
      }

      categoryNames.add(categoryName);
      if (listName.isEmpty) {
        if (!structuralCategories.add(categoryName)) {
          throw CsvImportFormatException(
            'Row $rowNumber repeats the category-only row for "$categoryName".',
          );
        }
        continue;
      }

      final reference = CsvListReference(
        categoryName: categoryName,
        listName: listName,
      );
      listReferences.add(reference);
      if (content.isEmpty) {
        if (!structuralLists.add(reference)) {
          throw CsvImportFormatException(
            'Row $rowNumber repeats the list-only row for "${reference.displayName}".',
          );
        }
        continue;
      }

      entries.add(
        CsvImportEntry(
          reference: reference,
          content: content,
          date: _parseDate(dateText, rowNumber),
        ),
      );
    }

    return CsvImportDocument(
      categoryNames: categoryNames.toList(growable: false),
      listReferences: listReferences.toList(growable: false),
      entries: List.unmodifiable(entries),
    );
  }

  bool _isExpectedHeader(List<dynamic> row) {
    if (row.length != csvHeader.length) {
      return false;
    }
    for (var index = 0; index < csvHeader.length; index++) {
      if (row[index] != csvHeader[index]) {
        return false;
      }
    }
    return true;
  }

  String _field(dynamic value) {
    final text = value.toString();
    final restored = restoreCsvSpreadsheetCell(text);
    return restored.trim();
  }

  String _validatedField(
    dynamic value, {
    required int rowNumber,
    required String fieldName,
    required int maxLength,
    bool allowLineBreaks = false,
    bool isName = false,
  }) {
    try {
      return isName
          ? normalizeName(
              _field(value),
              fieldName: fieldName,
              maxLength: maxLength,
            )
          : normalizeRequiredText(
              _field(value),
              fieldName: fieldName,
              maxLength: maxLength,
              allowLineBreaks: allowLineBreaks,
            );
    } on InputValidationException catch (error) {
      if (error.message == 'must not be blank.') {
        throw CsvImportFormatException('Row $rowNumber needs a $fieldName.');
      }
      throw CsvImportFormatException(
        'Row $rowNumber has an invalid $fieldName: ${error.message}',
      );
    }
  }

  String _optionalValidatedField(
    dynamic value, {
    required int rowNumber,
    required String fieldName,
    required int maxLength,
    bool allowLineBreaks = false,
    bool isName = false,
  }) {
    final normalized = _field(value);
    if (normalized.isEmpty) {
      return '';
    }
    try {
      return isName
          ? normalizeName(
              normalized,
              fieldName: fieldName,
              maxLength: maxLength,
            )
          : normalizeText(
              normalized,
              fieldName: fieldName,
              maxLength: maxLength,
              allowLineBreaks: allowLineBreaks,
            );
    } on InputValidationException catch (error) {
      throw CsvImportFormatException(
        'Row $rowNumber has an invalid $fieldName: ${error.message}',
      );
    }
  }

  void _validateCsvSyntax(String source) {
    var inQuotes = false;
    var atFieldStart = true;
    var afterClosingQuote = false;
    var rowNumber = 1;

    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (inQuotes) {
        if (character == '\r' || character == '\n') {
          if (character == '\r' &&
              index + 1 < source.length &&
              source[index + 1] == '\n') {
            index += 1;
          }
          rowNumber += 1;
        } else if (character == '"') {
          if (index + 1 < source.length && source[index + 1] == '"') {
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
        if (character == '\r' || character == '\n') {
          if (character == '\r' &&
              index + 1 < source.length &&
              source[index + 1] == '\n') {
            index += 1;
          }
          rowNumber += 1;
          atFieldStart = true;
          afterClosingQuote = false;
          continue;
        }
        throw CsvImportFormatException(
          'Row $rowNumber has malformed CSV quoting.',
        );
      }

      if (character == '"') {
        if (!atFieldStart) {
          throw CsvImportFormatException(
            'Row $rowNumber has malformed CSV quoting.',
          );
        }
        inQuotes = true;
        atFieldStart = false;
      } else if (character == ',') {
        atFieldStart = true;
      } else if (character == '\r' || character == '\n') {
        if (character == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index += 1;
        }
        rowNumber += 1;
        atFieldStart = true;
      } else {
        atFieldStart = false;
      }
    }

    if (inQuotes) {
      throw CsvImportFormatException(
        'Row $rowNumber has malformed CSV quoting.',
      );
    }
  }

  DateTime? _parseDate(String value, int rowNumber) {
    if (value.isEmpty) {
      return null;
    }
    final format = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final date = format.hasMatch(value) ? DateTime.tryParse(value) : null;
    if (date == null ||
        date.year < entryDateMinYear ||
        date.year > entryDateMaxYear ||
        date.year.toString().padLeft(4, '0') != value.substring(0, 4) ||
        date.month.toString().padLeft(2, '0') != value.substring(5, 7) ||
        date.day.toString().padLeft(2, '0') != value.substring(8, 10)) {
      throw CsvImportFormatException(
        'Row $rowNumber has an invalid date. Use YYYY-MM-DD.',
      );
    }
    return DateTime(date.year, date.month, date.day);
  }
}
