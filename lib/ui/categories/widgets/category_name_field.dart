import 'package:flutter/material.dart';

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
      decoration: const InputDecoration(
        labelText: 'Category Name',
        border: OutlineInputBorder(),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Enter a category name.'
          : null,
    );
  }
}
