import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/list_tracker_repository.dart';
import '../../data/repository/repository_providers.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final listSummaries = ref.watch(listSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('List Tracker')),
      body: Column(
        children: [
          _CategoryFilter(
            categories: categories,
            selectedCategoryId: _selectedCategoryId,
            onCategorySelected: (categoryId) {
              setState(() => _selectedCategoryId = categoryId);
            },
          ),
          Expanded(
            child: listSummaries.when(
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
      return Center(
        child: Text(
          hasActiveFilter ? 'No lists in this category.' : 'No lists yet.',
          textAlign: TextAlign.center,
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
        title: Text(summary.list.name),
        subtitle: Text(summary.category.name),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Unable to load lists: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
