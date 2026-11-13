import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../common.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Atmosphere(
      theme: HolyThemes.byId('charcoal'),
      child: Scaffold(
          body: Center(
              child: Reveal(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(
                  color: rose.withValues(alpha: .16),
                  blurRadius: 80,
                  spreadRadius: 25)
            ]),
            child: Image.asset('assets/brand/holyhim-mark.png', width: 86)),
        const SizedBox(height: 24),
        const Brand(),
        const SizedBox(height: 14),
        Text('Be strong and courageous.',
            style: HolyTypography.reading.copyWith(fontSize: 17))
      ])))));
}
