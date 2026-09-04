import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/repository_providers.dart';

const _categoryDropdownMenuMaxWidth = 280.0;
const _formMaxWidth = 640.0;

class EditListPage extends ConsumerWidget {
  const EditListPage({super.key, required this.listId});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listDetailAsync = ref.watch(listDetailProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit List'),
        leading: IconButton(
          tooltip: 'Back to List',
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
        child: listDetailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Error loading list: $error')),
          data: (listDetail) {
            if (listDetail == null) {
              return const Center(child: Text('List not found'));
            }

            return _EditListForm(list: listDetail.list);
          },
        ),
      ),
    );
  }
}

class _EditListForm extends ConsumerStatefulWidget {
  const _EditListForm({required this.list});

  final ListModel list;

  @override
  ConsumerState<_EditListForm> createState() => _EditListFormState();
}

class _EditListFormState extends ConsumerState<_EditListForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _listNameController;
  late final TextEditingController _noteController;

  late int? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _listNameController = TextEditingController(text: widget.list.name);
    _noteController = TextEditingController(text: widget.list.note ?? '');
    _selectedCategoryId = widget.list.categoryId;
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final formWidth = math.min(constraints.maxWidth, _formMaxWidth);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: formWidth,
            height: constraints.maxHeight,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'Edit List',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Update this list’s category, name, or note.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _CategoryField(
                    categories: categories,
                    selectedCategoryId: _selectedCategoryId,
                    enabled: !_isSaving,
                    onSelectedCategoryChanged: (categoryId) {
                      setState(() => _selectedCategoryId = categoryId);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('edit-list-name-field'),
                    controller: _listNameController,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'List Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _requiredTextValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('edit-list-note-field'),
                    controller: _noteController,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('save-list-button'),
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final repository = ref.read(listTrackerRepositoryProvider);
    setState(() => _isSaving = true);

    try {
      final updated = await repository.updateList(
        id: widget.list.id,
        categoryId: _selectedCategoryId!,
        name: _listNameController.text,
        note: _noteController.text,
      );
      if (!updated) {
        throw StateError('The list no longer exists.');
      }

      if (mounted) {
        context.go('/lists/${widget.list.id}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update the list. Try again.'),
          ),
        );
      }
    }
  }

  String? _requiredTextValidator(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required.'
        : null;
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.selectedCategoryId,
    required this.enabled,
    required this.onSelectedCategoryChanged,
  });

  final AsyncValue<List<Category>> categories;
  final int? selectedCategoryId;
  final bool enabled;
  final ValueChanged<int?> onSelectedCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return categories.when(
      data: (categories) => _buildCategoryInput(context, categories),
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => _buildCategoryInput(context, const []),
    );
  }

  Widget _buildCategoryInput(BuildContext context, List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),

        const SizedBox(height: 12),

        _ExistingCategoryDropdown(
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          enabled: enabled,
          onChanged: onSelectedCategoryChanged,
        ),
      ],
    );
  }
}

class _ExistingCategoryDropdown extends StatelessWidget {
  const _ExistingCategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.enabled,
    required this.onChanged,
  });

  final List<Category> categories;
  final int? selectedCategoryId;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = math.min(
          _categoryDropdownMenuMaxWidth,
          constraints.maxWidth,
        );

        return FormField<int>(
          initialValue: selectedCategoryId,
          validator: (value) => value == null ? 'Choose a category.' : null,
          builder: (field) {
            return InputDecorator(
              key: const ValueKey('existing-category-input'),
              decoration: const InputDecoration(
                labelText: 'Existing category',
                border: OutlineInputBorder(),
              ).copyWith(errorText: field.errorText),
              // The dropdown's hint occupies the field when no category is
              // selected, so the label must remain floating to avoid overlap.
              isEmpty: false,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: const ValueKey('existing-category-dropdown'),
                  value: selectedCategoryId,
                  isExpanded: true,
                  menuWidth: menuWidth,
                  hint: const Text('Choose a category'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) {
                          field.didChange(value);
                          onChanged(value);
                        }
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
