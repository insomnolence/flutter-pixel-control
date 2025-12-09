import 'package:flutter/material.dart';

void showStyledSnackBar(BuildContext context, {
  required String message,
  IconData? icon,
  Color? backgroundColor,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: StyledSnackBar(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        action: action,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 4), // Increased duration for actions
    ),
  );
}

class StyledSnackBar extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final SnackBarAction? action;

  const StyledSnackBar({
    super.key,
    required this.message,
    this.icon,
    this.backgroundColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final color = backgroundColor ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.8),
            color.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action!.onPressed,
              child: Text(
                action!.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}