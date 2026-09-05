import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repository/repository_providers.dart';
import '../widgets/entry_form.dart';

class AddEntryPage extends ConsumerWidget {
  const AddEntryPage({required this.listId, super.key});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Entry'),
        leading: IconButton(
          tooltip: 'Back to List Detail',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/lists/$listId');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: EntryForm(
          heading: 'Add an entry',
          description: 'Capture a thought, task, or note for this list.',
          saveLabel: 'Save',
          onSave: (content, date) async {
            await ref
                .read(entryRepositoryProvider)
                .createEntry(listId: listId, content: content, date: date);
            if (context.mounted) {
              context.go('/lists/$listId');
            }
          },
        ),
      ),
    );
  }
}
