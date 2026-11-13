import 'package:flutter/material.dart';
import '../../design/design.dart';

/// The first Flutter frame. It matches the native launch screen exactly:
/// the ivory wordmark centred on deep plum, so launch has no visible seam.
class SplashScreen extends StatelessWidget {
  static const background = Color(0xFF2A1A20);
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const ColoredBox(
      color: background,
      child: Center(child: Wordmark(size: 46, color: HolyTheme.photoInk)));
}
