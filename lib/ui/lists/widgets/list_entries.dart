import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/common/dialogs/destructive_confirmation_dialog.dart';

class ListEntries extends ConsumerWidget {
  const ListEntries({required this.listId, super.key});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(listId));

    return entries.when(
      data: (entryList) {
        if (entryList.isEmpty) {
          return const _EntriesEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: entryList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _EntryCard(entry: entryList[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListDetailLoadError(error: error),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          widget.entry.content,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: widget.entry.date == null
            ? null
            : Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(widget.entry.date!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
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
    final shouldDelete = await DestructiveConfirmationDialog.show(
      context,
      title: 'Delete entry?',
      message: 'This entry will be permanently removed.',
      confirmButtonKey: const ValueKey('confirm-delete-entry-button'),
    );

    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final wasDeleted = await ref
          .read(entryRepositoryProvider)
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

class ListDetailLoadError extends StatelessWidget {
  const ListDetailLoadError({required this.error, super.key});

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
              Text(
                'Unable to load this list: $error',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntriesEmptyState extends StatelessWidget {
  const _EntriesEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Icon(
                  Icons.notes_outlined,
                  size: 32,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No entries yet.',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add the first entry to start building this list.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
