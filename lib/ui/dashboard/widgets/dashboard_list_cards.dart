import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repository/list_repository.dart';
import '../../common/dialogs/destructive_confirmation_dialog.dart';

class DashboardListCards extends StatelessWidget {
  const DashboardListCards({
    required this.summaries,
    required this.isDeleting,
    required this.onDelete,
    required this.hasActiveFilter,
    super.key,
  });

  final List<ListWithCategory> summaries;
  final bool isDeleting;
  final void Function({required int listId}) onDelete;
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
      itemBuilder: (context, index) => DashboardListCard(
        summary: summaries[index],
        isDeleting: isDeleting,
        onDelete: onDelete,
      ),
    );
  }
}

class DashboardListCard extends StatelessWidget {
  const DashboardListCard({
    required this.summary,
    required this.isDeleting,
    required this.onDelete,
    super.key,
  });

  final ListWithCategory summary;
  final bool isDeleting;
  final void Function({required int listId}) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: isDeleting
            ? null
            : () => context.push('/lists/${summary.list.id}'),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit list',
              onPressed: isDeleting
                  ? null
                  : () => context.push('/lists/${summary.list.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete list',
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: isDeleting ? null : () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: 'Delete “${summary.list.name}”?',
      message:
          'This permanently deletes the list and every entry in it. '
          'This action cannot be undone.',
    );

    if (confirmed) {
      onDelete(listId: summary.list.id);
    }
  }
}

class DashboardLoadError extends StatelessWidget {
  const DashboardLoadError({required this.error, super.key});

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
