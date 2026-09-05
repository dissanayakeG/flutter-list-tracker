import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/lists/widgets/list_entries.dart';

class ListDetailPage extends ConsumerWidget {
  const ListDetailPage({required this.listId, super.key});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listDetail = ref.watch(listDetailProvider(listId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: listDetail.when(
        data: (summary) {
          if (summary == null) {
            return const _ListNotFound();
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.category.name,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                summary.list.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          key: const ValueKey('add-entry-button'),
                          tooltip: 'Add entry',
                          onPressed: () =>
                              context.push('/lists/$listId/add-entry'),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: ListEntries(listId: listId)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListDetailLoadError(error: error),
      ),
    );
  }
}

class _ListNotFound extends StatelessWidget {
  const _ListNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'This list is no longer available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
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
