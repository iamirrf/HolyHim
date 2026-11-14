import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../art_catalog.dart';
import 'package:flutter/services.dart';

/// Asset names share the inspected library and milestone manifest.
abstract final class HolyArtAssets {
  static const scenes = {
    'welcome-peace',
    'welcome-minute',
    'welcome-growth',
    'onboarding-heart',
    'onboarding-promise',
    'saved-empty',
    'growth-empty',
    'celebration'
  };
  static const _days = {
    1,
    3,
    7,
    14,
    21,
    30,
    50,
    75,
    100,
    150,
    200,
    250,
    300,
    365
  };
  static const _streaks = {7, 30, 100};
  static final _manifests = Expando<Future<Set<String>>>();
  static final _resolved = Expando<Set<String>>();
  static bool? knownContains(AssetBundle bundle, String path) =>
      _resolved[bundle]?.contains(path);

  static String? scenePath(String id) => HolyArtCatalog.scenes.containsKey(id)
      ? 'assets/art/library/${HolyArtCatalog.scenes[id]}.webp'
      : null;

  /// Domain IDs stay readable; packaged milestones use three-digit numbers.
  static String? badgePath(String? id) {
    if (id == 'first-saved') return 'assets/art/badges/first-saved.png';
    if (id == 'promise' || id == 'promise-kept') {
      return 'assets/art/badges/promise-kept.png';
    }
    final match = RegExp(r'^(days|streak)-(\d{1,3})$').firstMatch(id ?? '');
    if (match == null) return null;
    final number = int.parse(match[2]!);
    // The thirty-day milestone shares the thirty-straight medallion.
    final prefix = match[1] == 'days' && number == 30 ? 'streak' : match[1]!;
    if (!(prefix == 'days' ? _days : _streaks).contains(number)) return null;
    return 'assets/art/badges/$prefix-${number.toString().padLeft(3, '0')}.png';
  }

  /// Check the manifest first rather
  /// than asking Image.asset to report a missing file on every screen.
  static Future<bool> contains(AssetBundle bundle, String path) {
    final known = knownContains(bundle, path);
    if (known != null) return SynchronousFuture(known);
    final manifest = _manifests[bundle] ??=
        AssetManifest.loadFromAssetBundle(bundle).then<Set<String>>((manifest) {
      final assets = manifest.listAssets().toSet();
      _resolved[bundle] = assets;
      return assets;
    }, onError: (Object _) {
      final empty = <String>{};
      _resolved[bundle] = empty;
      return empty;
    });
    return manifest.then((assets) => assets.contains(path));
  }
}

class BundledArt extends StatelessWidget {
  final String? asset;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;
  final Widget Function(Widget image)? imageBuilder;
  const BundledArt(
      {super.key,
      required this.asset,
      required this.fallback,
      this.fit = BoxFit.cover,
      this.alignment = Alignment.center,
      this.imageBuilder});

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null) return fallback;
    final bundle = DefaultAssetBundle.of(context);
    Widget image() {
      final child = Image.asset(path,
          bundle: bundle,
          fit: fit,
          alignment: alignment,
          excludeFromSemantics: true,
          gaplessPlayback: true,
          errorBuilder: (_, error, stack) => fallback);
      return imageBuilder?.call(child) ?? child;
    }

    final known = HolyArtAssets.knownContains(bundle, path);
    if (known != null) return known ? image() : fallback;
    return FutureBuilder<bool>(
        future: HolyArtAssets.contains(bundle, path),
        builder: (context, available) =>
            available.data == true ? image() : fallback);
  }
}
