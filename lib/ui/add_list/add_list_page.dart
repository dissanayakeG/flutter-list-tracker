import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/repository_providers.dart';

enum _CategoryMode { existing, newCategory }

class AddListPage extends ConsumerStatefulWidget {
  const AddListPage({super.key});

  @override
  ConsumerState<AddListPage> createState() => _AddListPageState();
}

class _AddListPageState extends ConsumerState<AddListPage> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  final _noteController = TextEditingController();
  final _newCategoryController = TextEditingController();

  _CategoryMode _categoryMode = _CategoryMode.newCategory;
  int? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void dispose() {
    _listNameController.dispose();
    _noteController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New List'),
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CategoryField(
                categories: categories,
                categoryMode: _categoryMode,
                selectedCategoryId: _selectedCategoryId,
                newCategoryController: _newCategoryController,
                enabled: !_isSaving,
                onCategoryModeChanged: (mode) {
                  setState(() {
                    _categoryMode = mode;
                    _selectedCategoryId = null;
                  });
                },
                onSelectedCategoryChanged: (categoryId) {
                  setState(() => _selectedCategoryId = categoryId);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('list-name-field'),
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
                key: const ValueKey('note-field'),
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
                label: Text(_isSaving ? 'Saving...' : 'Save'),
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

    final repository = ref.read(listTrackerRepositoryProvider);
    setState(() => _isSaving = true);

    try {
      if (_categoryMode == _CategoryMode.existing) {
        await repository.createList(
          categoryId: _selectedCategoryId!,
          name: _listNameController.text,
          note: _noteController.text,
        );
      } else {
        await repository.createListInCategory(
          categoryName: _newCategoryController.text,
          name: _listNameController.text,
          note: _noteController.text,
        );
      }

      if (mounted) {
        context.go('/');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the list. Try again.')),
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
    required this.categoryMode,
    required this.selectedCategoryId,
    required this.newCategoryController,
    required this.enabled,
    required this.onCategoryModeChanged,
    required this.onSelectedCategoryChanged,
  });

  final AsyncValue<List<Category>> categories;
  final _CategoryMode categoryMode;
  final int? selectedCategoryId;
  final TextEditingController newCategoryController;
  final bool enabled;
  final ValueChanged<_CategoryMode> onCategoryModeChanged;
  final ValueChanged<int?> onSelectedCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return categories.when(
      data: _buildCategoryInput,
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => _buildCategoryInput(const []),
    );
  }

  Widget _buildCategoryInput(List<Category> categories) {
    if (categories.isEmpty) {
      return _NewCategoryField(
        controller: newCategoryController,
        enabled: enabled,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category'),
        const SizedBox(height: 8),
        SegmentedButton<_CategoryMode>(
          key: const ValueKey('category-mode-selector'),
          segments: const [
            ButtonSegment(
              value: _CategoryMode.existing,
              label: Text('Existing'),
              icon: Icon(Icons.folder_outlined),
            ),
            ButtonSegment(
              value: _CategoryMode.newCategory,
              label: Text('New category'),
              icon: Icon(Icons.create_new_folder_outlined),
            ),
          ],
          selected: {categoryMode},
          onSelectionChanged: enabled
              ? (selection) => onCategoryModeChanged(selection.first)
              : null,
        ),
        const SizedBox(height: 12),
        if (categoryMode == _CategoryMode.existing)
          DropdownButtonFormField<int>(
            key: const ValueKey('existing-category-dropdown'),
            initialValue: selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Existing category',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Choose a category'),
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: enabled ? onSelectedCategoryChanged : null,
            validator: (value) => value == null ? 'Choose a category.' : null,
          )
        else
          _NewCategoryField(
            controller: newCategoryController,
            enabled: enabled,
          ),
      ],
    );
  }
}

class _NewCategoryField extends StatelessWidget {
  const _NewCategoryField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey('new-category-field'),
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'New category',
        border: OutlineInputBorder(),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Enter a category.' : null,
    );
  }
}
