import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/categories/widgets/category_name_field.dart';

class AddCategoryPage extends ConsumerStatefulWidget {
  const AddCategoryPage({super.key});

  @override
  ConsumerState<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends ConsumerState<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  var _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Category')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Create a category',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 6),

              Text(
                'Use categories to keep related lists together.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              CategoryNameField(
                fieldKey: const ValueKey('category-name-field'),
                controller: _nameController,
                enabled: !_isSaving,
                autofocus: true,
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                key: const ValueKey('save-category-button'),
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

    setState(() => _isSaving = true);
    try {
      await ref
          .read(categoryRepositoryProvider)
          .createOrGetCategory(name: _nameController.text);
      if (mounted) {
        context.pop();
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
