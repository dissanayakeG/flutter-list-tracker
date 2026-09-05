import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../repository/transfer_repository.dart';
import 'export_snapshot.dart';

const csvHeader = <String>['category', 'list', 'entry', 'date'];

abstract interface class CsvExportService {
  Future<CsvExportResult> export();
}

enum CsvExportResult { saved, cancelled }

abstract interface class CsvFileSaveGateway {
  Future<bool> saveCsv({required String fileName, required Uint8List bytes});
}

class FilePickerCsvFileSaveGateway implements CsvFileSaveGateway {
  const FilePickerCsvFileSaveGateway();

  @override
  Future<bool> saveCsv({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final location = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    return location != null;
  }
}

class RepositoryCsvExportService implements CsvExportService {
  RepositoryCsvExportService({
    required this.repository,
    required this.fileSaveGateway,
    CsvExportEncoder? encoder,
    DateTime Function()? now,
  }) : _encoder = encoder ?? const CsvExportEncoder(),
       _now = now ?? DateTime.now;

  final TransferRepository repository;
  final CsvFileSaveGateway fileSaveGateway;
  final CsvExportEncoder _encoder;
  final DateTime Function() _now;

  @override
  Future<CsvExportResult> export() async {
    final snapshot = await repository.getExportSnapshot();
    final contents = _encoder.encode(snapshot);
    final saved = await fileSaveGateway.saveCsv(
      fileName: suggestedCsvFileName(_now()),
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );
    return saved ? CsvExportResult.saved : CsvExportResult.cancelled;
  }
}

class CsvExportEncoder {
  const CsvExportEncoder();

  String encode(ListTrackerExportSnapshot snapshot) {
    final rows = <List<String>>[
      csvHeader,
      for (final category in snapshot.categories) [category.name, '', '', ''],
      for (final list in snapshot.lists) [list.categoryName, list.name, '', ''],
      for (final entry in snapshot.entries)
        [
          entry.categoryName,
          entry.listName,
          entry.content,
          entry.date == null ? '' : _dateOnly(entry.date!),
        ],
    ];

    return '\uFEFF${Csv(lineDelimiter: '\r\n').encode(rows)}';
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

String suggestedCsvFileName(DateTime value) {
  final date =
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
  return 'list-tracker-$date.csv';
}
