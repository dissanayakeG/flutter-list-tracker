import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/repository/transfer_repository.dart';
import 'package:list_tracker/data/transfer/csv_export_service.dart';
import 'package:list_tracker/data/transfer/export_snapshot.dart';

void main() {
  test('encodes the readable header and every row shape losslessly', () {
    final snapshot = ListTrackerExportSnapshot(
      categories: [const ExportCategory(name: 'Meal Plans')],
      lists: [
        const ExportList(categoryName: 'Meal Plans', name: 'Weekday, meals'),
      ],
      entries: [
        ExportEntry(
          categoryName: 'Meal Plans',
          listName: 'Weekday, meals',
          content: 'Soup, salad, and "bread"\nEnjoy!',
          date: DateTime(2026, 3, 15),
        ),
      ],
    );

    final contents = const CsvExportEncoder().encode(snapshot);
    final rows = Csv().decode(contents.substring(1));

    expect(contents, startsWith('\uFEFF'));
    expect(contents, contains('\r\n'));
    expect(rows.first, csvHeader);
    expect(rows.every((row) => row.length == csvHeader.length), isTrue);
    expect(rows[1], ['Meal Plans', '', '', '']);
    expect(rows[2], ['Meal Plans', 'Weekday, meals', '', '']);
    expect(rows[3], [
      'Meal Plans',
      'Weekday, meals',
      'Soup, salad, and "bread"\nEnjoy!',
      '2026-03-15',
    ]);
  });

  test('preserves empty lists and optional values', () {
    final contents = const CsvExportEncoder().encode(
      ListTrackerExportSnapshot(
        categories: const [ExportCategory(name: 'Exercise')],
        lists: [
          const ExportList(categoryName: 'Exercise', name: 'Morning mobility'),
        ],
        entries: const [],
      ),
    );
    final rows = Csv().decode(contents.substring(1));

    expect(rows, hasLength(3));
    expect(rows[1], ['Exercise', '', '', '']);
    expect(rows[2], ['Exercise', 'Morning mobility', '', '']);
  });

  test('saves CSV bytes with a date-based suggested filename', () async {
    final repository = _SnapshotRepository(_snapshot());
    final fileSaveGateway = _RecordingFileSaveGateway(saved: true);
    final service = RepositoryCsvExportService(
      repository: repository,
      fileSaveGateway: fileSaveGateway,
      now: () => DateTime(2026, 3, 4),
    );

    final result = await service.export();
    final savedContents = utf8.decode(fileSaveGateway.bytes!);
    final rows = Csv().decode(
      savedContents.startsWith('\uFEFF')
          ? savedContents.substring(1)
          : savedContents,
    );

    expect(result, CsvExportResult.saved);
    expect(repository.snapshotRequests, 1);
    expect(fileSaveGateway.fileName, 'list-tracker-2026-03-04.csv');
    expect(fileSaveGateway.bytes!.take(3), [0xef, 0xbb, 0xbf]);
    expect(rows.first, csvHeader);
    expect(rows, hasLength(4));
  });

  test(
    'reports a cancelled save without claiming an export succeeded',
    () async {
      final service = RepositoryCsvExportService(
        repository: _SnapshotRepository(_snapshot()),
        fileSaveGateway: _RecordingFileSaveGateway(saved: false),
      );

      expect(await service.export(), CsvExportResult.cancelled);
    },
  );
}

ListTrackerExportSnapshot _snapshot() {
  return ListTrackerExportSnapshot(
    categories: const [ExportCategory(name: 'Reading')],
    lists: [const ExportList(categoryName: 'Reading', name: 'Books')],
    entries: [
      ExportEntry(
        categoryName: 'Reading',
        listName: 'Books',
        content: 'Read a chapter',
        date: null,
      ),
    ],
  );
}

class _SnapshotRepository implements TransferRepository {
  _SnapshotRepository(this.snapshot);

  final ListTrackerExportSnapshot snapshot;
  var snapshotRequests = 0;

  @override
  Future<ListTrackerExportSnapshot> getExportSnapshot() async {
    snapshotRequests += 1;
    return snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingFileSaveGateway implements CsvFileSaveGateway {
  _RecordingFileSaveGateway({required this.saved});

  final bool saved;
  String? fileName;
  Uint8List? bytes;

  @override
  Future<bool> saveCsv({
    required String fileName,
    required Uint8List bytes,
  }) async {
    this.fileName = fileName;
    this.bytes = bytes;
    return saved;
  }
}
