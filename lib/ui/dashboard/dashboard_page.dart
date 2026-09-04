import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/list_tracker_repository.dart';
import '../../data/repository/repository_providers.dart';
import '../../data/transfer/csv_export_providers.dart';
import '../../data/transfer/csv_export_service.dart';
import '../../data/transfer/csv_import_models.dart';
import '../../data/transfer/csv_import_providers.dart';
import '../../data/transfer/csv_import_service.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int? _selectedCategoryId;
  var _isExporting = false;
  var _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final listSummaries = ref.watch(listSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('List Tracker'),
        actions: [
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _isExporting ? null : _importCsv,
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import CSV',
            ),
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _isImporting ? null : _exportCsv,
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV',
            ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            const _DashboardIntro(),
            _CategoryFilter(
              categories: categories,
              selectedCategoryId: _selectedCategoryId,
              onCategorySelected: (categoryId) {
                setState(() => _selectedCategoryId = categoryId);
              },
            ),
            Expanded(
              ///If data has loaded, call data and build _ListCards.
              ///While loading, build a progress indicator.
              ///If loading failed, call error and build _LoadError
              child: listSummaries.when(
                ///When the data is ready, summaries is the actual list:
                data: (summaries) => _ListCards(
                  summaries: _filterSummaries(summaries),
                  hasActiveFilter: _selectedCategoryId != null,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _LoadError(error: error),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-list'),
        icon: const Icon(Icons.add),
        label: const Text('Add New List'),
        tooltip: 'Add new list',
      ),
    );
  }

  List<ListWithCategory> _filterSummaries(List<ListWithCategory> summaries) {
    final selectedCategoryId = _selectedCategoryId;
    if (selectedCategoryId == null) {
      return summaries;
    }
    return summaries
        .where((summary) => summary.category.id == selectedCategoryId)
        .toList(growable: false);
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final result = await ref.read(csvExportServiceProvider).export();
      if (!mounted) {
        return;
      }
      final message = switch (result) {
        CsvExportResult.saved => 'CSV exported.',
        CsvExportResult.cancelled => 'CSV export cancelled.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to export CSV. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importCsv() async {
    setState(() => _isImporting = true);
    try {
      final service = ref.read(csvImportServiceProvider);
      final preparation = await service.prepare();
      if (!mounted) {
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
        setState(() => _isImporting = false);
        await _showSetupDialog(preparation.preview);
        return;
      }

      final ready = preparation as CsvImportReady;
      setState(() => _isImporting = false);
      final shouldImport = await _showPreviewDialog(ready.preview);
      if (!mounted || !shouldImport) {
        return;
      }

      setState(() => _isImporting = true);
      try {
        final result = await service.importEntries(ready.document);
        if (!mounted) {
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
        if (mounted) {
          setState(() => _isImporting = false);
          await _showSetupDialog(error.preview);
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to import CSV. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final AsyncValue<List<Category>> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return categories.when(
      data: (categoryList) {
        if (categoryList.isEmpty) {
          return const SizedBox.shrink();
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All lists'),
                selected: selectedCategoryId == null,
                onSelected: (_) => onCategorySelected(null),
              ),
              const SizedBox(width: 8),
              for (final category in categoryList) ...[
                ChoiceChip(
                  label: Text(category.name),
                  selected: selectedCategoryId == category.id,
                  onSelected: (_) => onCategorySelected(category.id),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ListCards extends StatelessWidget {
  const _ListCards({required this.summaries, required this.hasActiveFilter});

  final List<ListWithCategory> summaries;
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Icon(
                          hasActiveFilter
                              ? Icons.filter_alt_off_outlined
                              : Icons.checklist_outlined,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      hasActiveFilter
                          ? 'No lists in this category.'
                          : 'No lists yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (!hasActiveFilter) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Create a list to start keeping track of what matters.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: summaries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ListCard(summary: summaries[index]),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.summary});

  final ListWithCategory summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/lists/${summary.list.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.checklist_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          summary.list.name,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            summary.category.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _DashboardIntro extends StatelessWidget {
  const _DashboardIntro();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your lists',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A simple place for the things you want to remember.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('Unable to load lists: $error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
