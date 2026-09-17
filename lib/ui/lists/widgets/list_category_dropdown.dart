import 'package:flutter/material.dart';

import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/ui/common/widgets/anchored_select_field.dart';

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
    return AnchoredSelectField<int>(
      key: const ValueKey('existing-category-input'),
      value: selectedCategoryId,
      labelText: 'Existing category',
      hintText: 'Choose a category',
      enabled: enabled,
      validator: (value) => value == null ? 'Choose a category.' : null,
      items: [
        for (final category in categories)
          AnchoredSelectItem(value: category.id, label: category.name),
      ],
      onChanged: onChanged,
    );
  }
}
