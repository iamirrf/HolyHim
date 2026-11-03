import 'package:flutter/material.dart';
import 'package:holyher/core/widgets/holy_ui.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color textColor;
  const GlassButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.textColor = const Color(0xFF98516A)});
  @override
  Widget build(BuildContext context) =>
      HolyButton(label: label, onPressed: onPressed);
}
