import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/app_database.dart';
import '../../../data/repository/repository_providers.dart';
import 'add_entry_page.dart';
import '../widgets/entry_form.dart';

class EditEntryPage extends ConsumerWidget {
  const EditEntryPage({required this.listId, required this.entry, super.key});

  final int listId;
  final Entry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = this.entry;
    if (entry == null) {
      return AddEntryPage(listId: listId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Entry'),
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
          heading: 'Update your entry',
          description: 'Keep the details current so your list stays useful.',
          initialContent: entry.content,
          initialDate: entry.date,
          saveLabel: 'Save changes',
          onSave: (content, date) async {
            final wasUpdated = await ref
                .read(entryRepositoryProvider)
                .updateEntry(id: entry.id, content: content, date: date);
            if (!wasUpdated) {
              throw StateError('The entry no longer exists.');
            }
            if (context.mounted) {
              context.go('/lists/$listId');
            }
          },
        ),
      ),
    );
  }
}
