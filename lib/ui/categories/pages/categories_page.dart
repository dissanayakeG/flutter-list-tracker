import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/ui/common/dialogs/destructive_confirmation_dialog.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  bool _isDeleting = false;

  Future<void> _deleteCategory(Category category) async {
    final repository = ref.read(categoryRepositoryProvider);

    setState(() => _isDeleting = true);

    try {
      if (await repository.isCategoryInUse(category.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Delete or move this category’s lists before deleting it.',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) {
        return;
      }

      final confirmed = await DestructiveConfirmationDialog.show(
        context,
        title: 'Delete “${category.name}”?',
        message:
            'This permanently deletes this empty category. '
            'This action cannot be undone.',
      );
      if (!confirmed || !mounted) {
        return;
      }

      final success = await repository.deleteCategory(category.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Category deleted.'
                : 'The category is no longer available.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete category. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),

      body: categories.when(
        data: (categories) => _CategoryList(
          categories: categories,
          isDeleting: _isDeleting,
          onDelete: _deleteCategory,
        ),

        loading: () => const Center(child: CircularProgressIndicator()),

        error: (_, _) => const Center(
          child: _CategoryState(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load categories',
            message: 'Please try again.',
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/categories/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        tooltip: 'Add category',
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.isDeleting,
    required this.onDelete,
  });

  final List<Category> categories;
  final bool isDeleting;
  final Future<void> Function(Category category) onDelete;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _CategoryState(
        icon: Icons.category_outlined,
        title: 'No categories yet.',
        message: 'Add a category to keep your lists organized.',
      );
    }

    final alphabeticalCategories = [...categories]
      ..sort((first, second) => first.name.compareTo(second.name));

    return ListView.separated(
      key: const ValueKey('category-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      itemCount: alphabeticalCategories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = alphabeticalCategories[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.category_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('edit-category-${category.id}'),
                  onPressed: isDeleting
                      ? null
                      : () => context.push('/categories/${category.id}/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit category',
                ),

                IconButton(
                  key: ValueKey('delete-category-${category.id}'),
                  tooltip: 'Delete category',
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: isDeleting ? null : () => onDelete(category),
                  icon: const Icon(Icons.delete_outlined),
                ),
              ],
            ),
            title: Text(
              category.name,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryState extends StatelessWidget {
  const _CategoryState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Icon(icon, size: 32, color: colors.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
