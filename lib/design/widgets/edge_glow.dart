import 'package:flutter/material.dart';
import 'rose_edge_glow.dart';

class EdgeGlow extends StatelessWidget {
  final Widget child;
  final double radius, energy;
  const EdgeGlow(
      {super.key, required this.child, this.radius = 28, this.energy = 0});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(children: [
        child,
        Positioned.fill(
            child: RoseEdgeGlow(
                corners: BorderRadius.circular(radius),
                energy: energy,
                scale: .5,
                intensity: .7))
      ]));
}
