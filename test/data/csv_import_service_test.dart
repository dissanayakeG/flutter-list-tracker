import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/repository/transfer_repository.dart';
import 'package:list_tracker/data/transfer/csv_export_service.dart';
import 'package:list_tracker/data/transfer/csv_import_models.dart';
import 'package:list_tracker/data/transfer/csv_import_service.dart';

void main() {
  const parser = CsvImportParser();

  test('parses every readable CSV row shape and quoted Unicode text', () {
    final document = parser.parse(
      '\uFEFF${_encode([
        csvHeader,
        ['Meal Plans', '', '', ''],
        ['Meal Plans', 'Weekday, meals', '', ''],
        ['Meal Plans', 'Weekday, meals', 'කෑම, "healthy"\nfor tomorrow', '2026-03-15'],
        ['Reading', 'Books', 'Read a chapter', ''],
      ])}',
    );

    expect(document.categoryNames, ['Meal Plans', 'Reading']);
    expect(document.listReferences, [
      const CsvListReference(
        categoryName: 'Meal Plans',
        listName: 'Weekday, meals',
      ),
      const CsvListReference(categoryName: 'Reading', listName: 'Books'),
    ]);
    expect(document.entries, hasLength(2));
    expect(document.entries.first.content, 'කෑම, "healthy"\nfor tomorrow');
    expect(document.entries.first.date, DateTime(2026, 3, 15));
    expect(document.entries.last.date, isNull);
  });

  test('requires the exact four-column header', () {
    expect(
      () => parser.parse('Category,List,Entry,Date\r\n'),
      throwsA(
        isA<CsvImportFormatException>().having(
          (error) => error.message,
          'message',
          contains('Row 1 must be exactly'),
        ),
      ),
    );
    expect(
      () => parser.parse('sep=;\r\ncategory,list,entry,date\r\n'),
      throwsA(isA<CsvImportFormatException>()),
    );
  });

  test('preserves literal apostrophes in external CSV imports', () {
    final document = parser.parse(
      _encode([
        csvHeader,
        ['Reading', 'Books', "'=literal-marker", ''],
      ]),
    );

    expect(document.entries.single.content, "'=literal-marker");
  });

  test('reports the source row for invalid structural rows and dates', () {
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['', 'Books', '', ''],
      ]),
      'Row 2 needs a category.',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading', '', 'Read a chapter', ''],
      ]),
      'Row 2 has an entry without a list.',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading', 'Books', '', '2026-03-15'],
      ]),
      'Row 2 has a date without an entry.',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading', 'Books', 'Read a chapter', '2026-02-30'],
      ]),
      'Row 2 has an invalid date.',
    );
  });

  test('rejects malformed quoting and duplicate structural rows', () {
    expectInvalidCsv(
      parser,
      'category,list,entry,date\r\nReading,Books,"unfinished',
      'Row 2 has malformed CSV quoting.',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading', '', '', ''],
        ['Reading', '', '', ''],
      ]),
      'Row 3 repeats the category-only row',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading', 'Books', '', ''],
        ['Reading', 'Books', '', ''],
      ]),
      'Row 3 repeats the list-only row',
    );
  });

  test('rejects unsafe or oversized CSV fields with source row feedback', () {
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading\u0000', 'Books', 'Read a chapter', ''],
      ]),
      'Row 2 has an invalid category',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading', 'a' * 201, '', ''],
      ]),
      'Row 2 has an invalid list',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['Reading', 'Books', 'a' * 5001, ''],
      ]),
      'Row 2 has an invalid entry',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        ['!!!', 'Books', 'Read a chapter', ''],
      ]),
      'Row 2 has an invalid category',
    );
    expectInvalidCsv(
      parser,
      _encode([
        csvHeader,
        [r'NUL: \u0000', 'Books', 'Read a chapter', ''],
      ]),
      'Row 2 has an invalid category',
    );
  });

  test('rejects every blocked code-point notation in CSV names', () {
    const blockedNotations = [
      'U+0000',
      'U+001F',
      'U+007F',
      'U+0080',
      'U+009F',
      'U+200B',
      'U+202A',
      'U+202E',
      'U+2066',
      'U+2069',
    ];

    for (final notation in blockedNotations) {
      expectInvalidCsv(
        parser,
        _encode([
          csvHeader,
          ['Reserved $notation', 'Books', 'Read a chapter', ''],
        ]),
        'Row 2 has an invalid category',
      );
      expectInvalidCsv(
        parser,
        _encode([
          csvHeader,
          ['Reading', 'Reserved $notation', '', ''],
        ]),
        'Row 2 has an invalid list',
      );
    }
  });

  test(
    'rejects CSV files over the byte limit before repository access',
    () async {
      final repository = _ImportRepository();
      final service = RepositoryCsvImportService(
        repository: repository,
        fileOpenGateway: _BytesGateway(
          Uint8List.fromList(List.filled(maxCsvImportBytes + 1, 0x20)),
        ),
      );

      final preparation = await service.prepare();

      expect(preparation, isA<CsvImportInvalid>());
      expect((preparation as CsvImportInvalid).message, contains('too large'));
      expect(repository.previewRequests, 0);
    },
  );

  test('preparation treats a cancelled file picker as a no-op', () async {
    final repository = _ImportRepository();
    final service = RepositoryCsvImportService(
      repository: repository,
      fileOpenGateway: _BytesGateway(null),
    );

    expect(await service.prepare(), isA<CsvImportCancelled>());
    expect(repository.previewRequests, 0);
  });

  test(
    'preparation reports invalid UTF-8 without using the repository',
    () async {
      final repository = _ImportRepository();
      final service = RepositoryCsvImportService(
        repository: repository,
        fileOpenGateway: _BytesGateway(Uint8List.fromList([0xff])),
      );

      final preparation = await service.prepare();

      expect(preparation, isA<CsvImportInvalid>());
      expect((preparation as CsvImportInvalid).message, contains('UTF-8'));
      expect(repository.previewRequests, 0);
    },
  );

  test(
    'prepares setup problems and ready imports through the repository',
    () async {
      final documentBytes = Uint8List.fromList(
        utf8.encode(
          _encode([
            csvHeader,
            ['Reading', 'Books', 'Read a chapter', '2026-03-15'],
          ]),
        ),
      );
      final blockedRepository = _ImportRepository(
        preview: const CsvImportPreview(
          missingCategories: ['Reading'],
          listsToCreate: [],
          ambiguousLists: [],
          entriesToAdd: 0,
          entriesToSkip: 0,
        ),
      );
      final blockedService = RepositoryCsvImportService(
        repository: blockedRepository,
        fileOpenGateway: _BytesGateway(documentBytes),
      );

      final blocked = await blockedService.prepare();

      expect(blocked, isA<CsvImportNeedsSetup>());
      expect(blockedRepository.previewRequests, 1);

      final readyRepository = _ImportRepository(
        preview: const CsvImportPreview(
          missingCategories: [],
          listsToCreate: [],
          ambiguousLists: [],
          entriesToAdd: 1,
          entriesToSkip: 0,
        ),
        importResult: const CsvImportResult(
          createdLists: 0,
          addedEntries: 1,
          skippedEntries: 0,
        ),
      );
      final readyService = RepositoryCsvImportService(
        repository: readyRepository,
        fileOpenGateway: _BytesGateway(documentBytes),
      );

      final ready = await readyService.prepare();

      expect(ready, isA<CsvImportReady>());
      final result = await readyService.importEntries(
        (ready as CsvImportReady).document,
      );
      expect(readyRepository.importRequests, 1);
      expect(result.addedEntries, 1);
    },
  );
}

String _encode(List<List<String>> rows) {
  return Csv(lineDelimiter: '\r\n').encode(rows);
}

void expectInvalidCsv(
  CsvImportParser parser,
  String contents,
  String expectedMessage,
) {
  expect(
    () => parser.parse(contents),
    throwsA(
      isA<CsvImportFormatException>().having(
        (error) => error.message,
        'message',
        contains(expectedMessage),
      ),
    ),
  );
}

class _BytesGateway implements CsvFileOpenGateway {
  const _BytesGateway(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> openCsv() async => bytes;
}

class _ImportRepository implements TransferRepository {
  _ImportRepository({
    this.preview = const CsvImportPreview(
      missingCategories: [],
      listsToCreate: [],
      ambiguousLists: [],
      entriesToAdd: 0,
      entriesToSkip: 0,
    ),
    this.importResult = const CsvImportResult(
      createdLists: 0,
      addedEntries: 0,
      skippedEntries: 0,
    ),
  });

  final CsvImportPreview preview;
  final CsvImportResult importResult;
  var previewRequests = 0;
  var importRequests = 0;

  @override
  Future<CsvImportPreview> previewCsvImport(CsvImportDocument document) async {
    previewRequests += 1;
    return preview;
  }

  @override
  Future<CsvImportResult> importCsvEntries(CsvImportDocument document) async {
    importRequests += 1;
    return importResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
