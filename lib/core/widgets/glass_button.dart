import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';

/// Shared blush action. Minimum height grows with system text scaling.
class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color textColor;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
