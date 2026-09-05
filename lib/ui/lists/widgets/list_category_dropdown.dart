import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:list_tracker/data/local/app_database.dart';

const _categoryDropdownMenuMaxWidth = 280.0;

class ExistingListCategoryDropdown extends StatelessWidget {
  const ExistingListCategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.enabled,
    required this.onChanged,
    super.key,
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
