import 'package:flutter/material.dart';

class DestructiveConfirmationDialog extends StatelessWidget {
  const DestructiveConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
    this.confirmButtonKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Key? confirmButtonKey;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    Key? confirmButtonKey,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DestructiveConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmButtonKey: confirmButtonKey,
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: colors.error),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: confirmButtonKey,
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
