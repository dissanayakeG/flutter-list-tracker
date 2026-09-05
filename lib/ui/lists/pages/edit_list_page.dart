import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/data/repository/repository_validation.dart';
import 'package:list_tracker/ui/lists/widgets/list_category_dropdown.dart';

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
                    maxLength: listNameMaxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    buildCounter: (
                      _, {
                      required currentLength,
                      required maxLength,
                      required isFocused,
                    }) => null,
                    decoration: const InputDecoration(
                      labelText: 'List Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => validateRequiredText(
                      value: value,
                      label: 'list name',
                      fieldName: 'list name',
                      maxLength: listNameMaxLength,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('edit-list-note-field'),
                    controller: _noteController,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    maxLength: listNoteMaxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    buildCounter: (
                      _, {
                      required currentLength,
                      required maxLength,
                      required isFocused,
                    }) => null,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => validateOptionalText(
                      value: value,
                      label: 'note',
                      fieldName: 'note',
                      maxLength: listNoteMaxLength,
                      allowLineBreaks: true,
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

    final repository = ref.read(listRepositoryProvider);
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

        ExistingListCategoryDropdown(
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          enabled: enabled,
          onChanged: onSelectedCategoryChanged,
        ),
      ],
    );
  }
}
