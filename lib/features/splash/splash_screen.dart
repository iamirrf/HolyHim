import 'package:flutter/material.dart';
import '../../design/design.dart';

/// The first Flutter frame. It matches the native launch screen exactly:
/// the wordmark centred on First Watch charcoal, so launch has no seam.
class SplashScreen extends StatelessWidget {
  static const background = Color(0xFF0E1217);
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const ColoredBox(
      color: background,
      child: Center(child: Wordmark(size: 46, color: HolyTheme.photoInk)));
}
