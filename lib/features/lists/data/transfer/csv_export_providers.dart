import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:list_tracker/features/lists/data/repositories/repository_providers.dart';

import 'csv_export_service.dart';

final csvFileSaveGatewayProvider = Provider<CsvFileSaveGateway>((ref) {
  return const FilePickerCsvFileSaveGateway();
});

///This Riverpod provider supplies an object that has the CsvExportService type.
///CsvExportService is the contract
///RepositoryCsvExportService is the implementation
final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return RepositoryCsvExportService(
    repository: ref.watch(transferRepositoryProvider),
    fileSaveGateway: ref.watch(csvFileSaveGatewayProvider),
  );
});

/*
Dashboard
  → requests CsvExportService

CsvExportService
  → gets data
  → encodes CSV
  → asks gateway to save

FilePicker gateway
  → handles platform-specific file saving
*/
