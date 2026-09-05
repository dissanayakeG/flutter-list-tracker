import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/categories/widgets/category_name_field.dart';

class EditCategoryPage extends ConsumerWidget {
  const EditCategoryPage({super.key, required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Category')),
      body: SafeArea(
        child: categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text('Unable to load this category. Please try again.'),
          ),
          data: (categories) {
            final category = _findCategory(categories, categoryId);
            if (category == null) {
              return const Center(child: Text('Category not found.'));
            }

            return _EditCategoryForm(category: category);
          },
        ),
      ),
    );
  }
}

Category? _findCategory(List<Category> categories, int categoryId) {
  for (final category in categories) {
    if (category.id == categoryId) {
      return category;
    }
  }
  return null;
}

class _EditCategoryForm extends ConsumerStatefulWidget {
  const _EditCategoryForm({required this.category});

  final Category category;

  @override
  ConsumerState<_EditCategoryForm> createState() => _EditCategoryFormState();
}

class _EditCategoryFormState extends ConsumerState<_EditCategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Edit category',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),

          Text(
            'Rename this category without changing the lists inside it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          CategoryNameField(
            fieldKey: const ValueKey('edit-category-name-field'),
            controller: _nameController,
            enabled: !_isSaving,
            autofocus: true,
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            key: const ValueKey('save-edited-category-button'),
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
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await ref
          .read(categoryRepositoryProvider)
          .updateCategory(id: widget.category.id, name: _nameController.text);
      if (!mounted) {
        return;
      }
      if (updated) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The category is no longer available.')),
        );
        setState(() => _isSaving = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save the category. Try again.'),
          ),
        );
      }
    }
  }
}
