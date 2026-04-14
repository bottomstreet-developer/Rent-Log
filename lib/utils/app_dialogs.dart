import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      content: Text(
        content,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF8A8A8A),
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: Color(0xFF8A8A8A)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
