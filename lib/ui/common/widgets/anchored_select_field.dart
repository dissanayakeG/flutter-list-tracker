import 'package:flutter/material.dart';

class AnchoredSelectItem<T> {
  const AnchoredSelectItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// A form selector whose menu is deliberately anchored below its input.
class AnchoredSelectField<T> extends StatelessWidget {
  const AnchoredSelectField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelText,
    super.key,
    this.hintText,
    this.validator,
    this.enabled = true,
    this.hasValue = true,
  });

  final T? value;
  final List<AnchoredSelectItem<T>> items;
  final ValueChanged<T>? onChanged;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<T>? validator;
  final bool enabled;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = !hasValue
        ? null
        : items
              .where((item) => item.value == value)
              .map((item) => item.label)
              .firstOrNull;
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (field) => LayoutBuilder(
        builder: (context, constraints) => MenuAnchor(
          alignmentOffset: const Offset(0, 4),
          crossAxisUnconstrained: false,
          style: MenuStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 4),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          menuChildren: [
            for (final item in items)
              SizedBox(
                width: constraints.maxWidth,
                child: MenuItemButton(
                  onPressed: enabled
                      ? () {
                          field.didChange(item.value);
                          onChanged?.call(item.value);
                        }
                      : null,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
          builder: (context, controller, child) => InputDecorator(
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              border: const OutlineInputBorder(),
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            // The placeholder is rendered as the field's child. Keep the
            // label floating while it is visible so the two never share a
            // baseline inside the input.
            isEmpty: false,
            child: InkWell(
              onTap: !enabled
                  ? null
                  : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
              child: Text(selectedLabel ?? hintText ?? ''),
            ),
          ),
        ),
      ),
    );
  }
}
