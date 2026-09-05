import 'package:flutter/material.dart';

/// The shared input and validation surface used by the Add and Edit entry
/// flows. Route pages supply only their copy and persistence action.
class EntryForm extends StatefulWidget {
  const EntryForm({
    required this.heading,
    required this.description,
    required this.saveLabel,
    required this.onSave,
    this.initialContent = '',
    this.initialDate,
    super.key,
  });

  final String heading;
  final String description;
  final String saveLabel;
  final String initialContent;
  final DateTime? initialDate;
  final Future<void> Function(String content, DateTime? date) onSave;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contentController;
  DateTime? _selectedDate;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _selectedDate = _dateOnly(widget.initialDate);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            widget.heading,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            widget.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
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
          _EntryDateField(
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
            label: Text(_isSaving ? 'Saving...' : widget.saveLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(_contentController.text, _selectedDate);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the entry. Try again.')),
      );
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

class _EntryDateField extends StatelessWidget {
  const _EntryDateField({
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
        Text(
          'Date (optional)',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
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
