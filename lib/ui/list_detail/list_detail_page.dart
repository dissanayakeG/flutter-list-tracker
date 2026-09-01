import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/repository_providers.dart';

class ListDetailPage extends ConsumerWidget {
  const ListDetailPage({required this.listId, super.key});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listDetail = ref.watch(listDetailProvider(listId));

    return Scaffold(
      appBar: AppBar(),
      body: listDetail.when(
        data: (summary) {
          if (summary == null) {
            return const _ListNotFound();
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary.list.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('add-entry-button'),
                      tooltip: 'Add entry',
                      onPressed: () => context.push('/lists/$listId/add-entry'),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(child: _Entries(listId: listId)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(error: error),
      ),
    );
  }
}

class _Entries extends ConsumerWidget {
  const _Entries({required this.listId});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(listId));

    return entries.when(
      data: (entryList) {
        if (entryList.isEmpty) {
          return const Center(child: Text('No entries yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: entryList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _EntryCard(entry: entryList[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _LoadError(error: error),
    );
  }
}

class _EntryCard extends ConsumerStatefulWidget {
  const _EntryCard({required this.entry});

  final Entry entry;

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.entry.content),
        subtitle: widget.entry.date == null
            ? null
            : Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(widget.entry.date!),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('edit-entry-${widget.entry.id}'),
              tooltip: 'Edit entry',
              onPressed: _isDeleting
                  ? null
                  : () => context.push(
                      '/lists/${widget.entry.listId}/entries/${widget.entry.id}/edit',
                      extra: widget.entry,
                    ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: ValueKey('delete-entry-${widget.entry.id}'),
              tooltip: 'Delete entry',
              onPressed: _isDeleting ? null : _confirmAndDelete,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This entry will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-entry-button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final wasDeleted = await ref
          .read(listTrackerRepositoryProvider)
          .deleteEntry(widget.entry.id);
      if (!wasDeleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The entry is no longer available.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete the entry. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

class _ListNotFound extends StatelessWidget {
  const _ListNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This list is no longer available.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Dashboard'),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Unable to load this list: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
