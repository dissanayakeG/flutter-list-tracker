import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:list_tracker/data/repository/repository_validation.dart';

class CategoryNameField extends StatelessWidget {
  const CategoryNameField({
    required this.controller,
    required this.enabled,
    required this.fieldKey,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final Key fieldKey;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      autofocus: autofocus,
      maxLength: categoryNameMaxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      buildCounter: (
        _, {
        required currentLength,
        required maxLength,
        required isFocused,
      }) => null,
      decoration: const InputDecoration(
        labelText: 'Category Name',
        border: OutlineInputBorder(),
      ),
      validator: (value) => validateRequiredText(
        value: value,
        label: 'category name',
        fieldName: 'category name',
        maxLength: categoryNameMaxLength,
      ),
    );
  }
}
