import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/repository_providers.dart';

class AddEntryPage extends ConsumerStatefulWidget {
  const AddEntryPage({required this.listId, this.entry, super.key});

  final int listId;
  final Entry? entry;

  @override
  ConsumerState<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends ConsumerState<AddEntryPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contentController;
  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.entry?.content);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Entry' : 'Add Entry')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const ValueKey('entry-content-field'),
                controller: _contentController,
                enabled: !_isSaving,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Entry',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an entry.'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('save-entry-button'),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isEditing
                      ? 'Save changes'
                      : 'Save',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = ref.read(listTrackerRepositoryProvider);
      if (widget.entry case final entry?) {
        final wasUpdated = await repository.updateEntry(
          id: entry.id,
          content: _contentController.text,
        );
        if (!wasUpdated) {
          throw StateError('The entry no longer exists.');
        }
      } else {
        await repository.createEntry(
          listId: widget.listId,
          content: _contentController.text,
        );
      }
      if (mounted) {
        context.go('/lists/${widget.listId}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the entry. Try again.')),
        );
      }
    }
  }
}
