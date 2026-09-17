import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:list_tracker/features/lists/data/repositories/repository_providers.dart';

import 'csv_import_service.dart';

final csvFileOpenGatewayProvider = Provider<CsvFileOpenGateway>((ref) {
  return const FilePickerCsvFileOpenGateway();
});

final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  return RepositoryCsvImportService(
    repository: ref.watch(transferRepositoryProvider),
    fileOpenGateway: ref.watch(csvFileOpenGatewayProvider),
  );
});
