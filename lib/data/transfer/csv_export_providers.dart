import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/repository_providers.dart';
import 'csv_export_service.dart';

final csvFileSaveGatewayProvider = Provider<CsvFileSaveGateway>((ref) {
  return const FilePickerCsvFileSaveGateway();
});

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return RepositoryCsvExportService(
    repository: ref.watch(listTrackerRepositoryProvider),
    fileSaveGateway: ref.watch(csvFileSaveGatewayProvider),
  );
});
