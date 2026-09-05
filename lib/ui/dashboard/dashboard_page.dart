import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repository/list_repository.dart';
import '../../data/repository/repository_providers.dart';
import 'dashboard_transfer_actions.dart';
import 'widgets/dashboard_category_filter.dart';
import 'widgets/dashboard_intro.dart';
import 'widgets/dashboard_list_cards.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int? _selectedCategoryId;
  var _isExporting = false;
  var _isImporting = false;
  var _isDeleting = false;

  Future<void> _deleteList({required int listId}) async {
    final repository = ref.read(listRepositoryProvider);

    setState(() => _isDeleting = true);

    try {
      final success = await repository.deleteList(listId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'List deleted.'
                : 'Unable to delete list. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete list. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final listSummaries = ref.watch(listSummariesProvider);
    final transferActions = DashboardTransferActions(
      context: context,
      ref: ref,
      onImportingChanged: (isImporting) {
        if (mounted) {
          setState(() => _isImporting = isImporting);
        }
      },
      onExportingChanged: (isExporting) {
        if (mounted) {
          setState(() => _isExporting = isExporting);
        }
      },
    );

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
              onPressed: _isExporting ? null : transferActions.importCsv,
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
              onPressed: _isImporting ? null : transferActions.exportCsv,
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
            const DashboardIntro(),
            DashboardCategoryFilter(
              categories: categories,
              selectedCategoryId: _selectedCategoryId,
              onCategorySelected: (categoryId) {
                setState(() => _selectedCategoryId = categoryId);
              },
            ),
            Expanded(
              child: listSummaries.when(
                data: (summaries) => DashboardListCards(
                  summaries: _filterSummaries(summaries),
                  isDeleting: _isDeleting,
                  onDelete: _deleteList,
                  hasActiveFilter: _selectedCategoryId != null,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => DashboardLoadError(error: error),
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
}
