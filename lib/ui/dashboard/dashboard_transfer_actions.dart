import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/transfer/csv_export_providers.dart';
import '../../data/transfer/csv_export_service.dart';
import '../../data/transfer/csv_import_models.dart';
import '../../data/transfer/csv_import_providers.dart';
import '../../data/transfer/csv_import_service.dart';

/// Coordinates Dashboard-only CSV dialogs, feedback, and busy indicators.
///
/// CSV parsing, encoding, and persistence remain in the transfer layer. This
/// object keeps presentation orchestration out of [DashboardPage].
class DashboardTransferActions {
  const DashboardTransferActions({
    required this.context,
    required this.ref,
    required this.onImportingChanged,
    required this.onExportingChanged,
  });

  final BuildContext context;
  final WidgetRef ref;
  final ValueChanged<bool> onImportingChanged;
  final ValueChanged<bool> onExportingChanged;

  Future<void> exportCsv() async {
    _setExporting(true);
    try {
      final result = await ref.read(csvExportServiceProvider).export();
      if (!context.mounted) {
        return;
      }
      final message = switch (result) {
        CsvExportResult.saved => 'CSV exported.',
        CsvExportResult.cancelled => 'CSV export cancelled.',
      };
      _showSnackBar(message);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      _showSnackBar('Unable to export CSV. Please try again.');
    } finally {
      _setExporting(false);
    }
  }

  Future<void> importCsv() async {
    _setImporting(true);
    try {
      final service = ref.read(csvImportServiceProvider);
      final preparation = await service.prepare();
      if (!context.mounted) {
        return;
      }

      if (preparation is CsvImportCancelled) {
        return;
      }
      if (preparation is CsvImportInvalid) {
        _showSnackBar('Invalid CSV: ${preparation.message}');
        return;
      }
      if (preparation is CsvImportNeedsSetup) {
        _setImporting(false);
        await _showSetupDialog(preparation.preview);
        return;
      }

      final ready = preparation as CsvImportReady;
      _setImporting(false);
      final shouldImport = await _showPreviewDialog(ready.preview);
      if (!context.mounted || !shouldImport) {
        return;
      }

      _setImporting(true);
      try {
        final result = await service.importEntries(ready.document);
        if (!context.mounted) {
          return;
        }
        final createdListsMessage = result.createdLists == 0
            ? ''
            : 'Created ${result.createdLists} '
                  '${result.createdLists == 1 ? 'list' : 'lists'}; ';
        _showSnackBar(
          '${createdListsMessage}Imported ${result.addedEntries} entries; '
          'skipped ${result.skippedEntries}.',
        );
      } on CsvImportPreflightException catch (error) {
        if (context.mounted) {
          _setImporting(false);
          await _showSetupDialog(error.preview);
        }
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      _showSnackBar('Unable to import CSV. Please try again.');
    } finally {
      _setImporting(false);
    }
  }

  Future<bool> _showPreviewDialog(CsvImportPreview preview) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import CSV'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.listsToCreate.isNotEmpty) ...[
                    Text(
                      'Lists to create: '
                      '${preview.listsToCreate.map((item) => item.displayName).join(', ')}',
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Entries to add: ${preview.entriesToAdd}\n'
                    'Exact entries to skip: ${preview.entriesToSkip}',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Import entries'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSetupDialog(CsvImportPreview preview) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import setup needed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create the missing Categories or resolve duplicate Lists, '
                'then try this import again.',
              ),
              if (preview.missingCategories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Missing categories: ${preview.missingCategories.join(', ')}',
                ),
              ],
              if (preview.ambiguousLists.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ambiguous lists: '
                  '${preview.ambiguousLists.map((item) => item.displayName).join(', ')}',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _setImporting(bool value) {
    if (context.mounted) {
      onImportingChanged(value);
    }
  }

  void _setExporting(bool value) {
    if (context.mounted) {
      onExportingChanged(value);
    }
  }

  void _showSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
