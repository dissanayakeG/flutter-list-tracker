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
  DateTime? _selectedDate;
  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.entry?.content);
    _selectedDate = _dateOnly(widget.entry?.date);
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
              const SizedBox(height: 16),
              _DateField(
                selectedDate: _selectedDate,
                enabled: !_isSaving,
                onSelectDate: _selectDate,
                onClearDate: () => setState(() => _selectedDate = null),
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
          date: _selectedDate,
        );
        if (!wasUpdated) {
          throw StateError('The entry no longer exists.');
        }
      } else {
        await repository.createEntry(
          listId: widget.listId,
          content: _contentController.text,
          date: _selectedDate,
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

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null && mounted) {
      setState(() => _selectedDate = _dateOnly(selectedDate));
    }
  }

  DateTime? _dateOnly(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateUtils.dateOnly(value);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.selectedDate,
    required this.enabled,
    required this.onSelectDate,
    required this.onClearDate,
  });

  final DateTime? selectedDate;
  final bool enabled;
  final VoidCallback onSelectDate;
  final VoidCallback onClearDate;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final label = selectedDate == null
        ? 'Select date (optional)'
        : localizations.formatMediumDate(selectedDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date (optional)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('entry-date-picker'),
                onPressed: enabled ? onSelectDate : null,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(label),
              ),
            ),
            if (selectedDate != null) ...[
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('clear-entry-date'),
                tooltip: 'Clear date',
                onPressed: enabled ? onClearDate : null,
                icon: const Icon(Icons.clear),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
