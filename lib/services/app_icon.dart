import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One Home Screen icon HolyHim offers. Made by tool/art/app_icons.py.
@immutable
class AppIconChoice {
  final String id;

  /// The asset catalog's alternate icon set; null is the primary icon.
  final String? iosName;
  final String name;
  final String group;
  const AppIconChoice(this.id, this.iosName, this.name, this.group);

  String get preview => 'assets/icons/$id.png';
}

/// Every icon, in the order the App icon screen shows them.
const appIcons = [
  AppIconChoice('first-light', null, 'First Light', 'Themes'),
  AppIconChoice('rose', 'AppIcon-Rose', 'Rosé', 'Themes'),
  AppIconChoice('lavender', 'AppIcon-Lavender', 'Lavender', 'Themes'),
  AppIconChoice('sunrise', 'AppIcon-Sunrise', 'Sunrise', 'Themes'),
  AppIconChoice('pearl', 'AppIcon-Pearl', 'Pearl', 'Themes'),
  AppIconChoice('olive-grove', 'AppIcon-OliveGrove', 'Olive Grove', 'Themes'),
  AppIconChoice('evening', 'AppIcon-Evening', 'Evening', 'Themes'),
  AppIconChoice('starlight', 'AppIcon-Starlight', 'Starlight', 'Themes'),
  AppIconChoice('dove', 'AppIcon-Dove', 'Dove', 'Symbols'),
  AppIconChoice('lily', 'AppIcon-Lily', 'Lily', 'Symbols'),
  AppIconChoice('cross-at-sunrise', 'AppIcon-CrossSunrise', 'Cross at Sunrise',
      'Symbols'),
  AppIconChoice(
      'olive-branch', 'AppIcon-OliveBranch', 'Olive Branch', 'Symbols'),
  AppIconChoice('candle', 'AppIcon-Candle', 'Candle', 'Symbols'),
  AppIconChoice(
      'christmas-star', 'AppIcon-ChristmasStar', 'Christmas Star', 'Seasons'),
  AppIconChoice(
      'easter-morning', 'AppIcon-EasterMorning', 'Easter Morning', 'Seasons'),
];

/// The icon that wears each theme's colours.
const _themeIcons = {
  'blush': 'first-light',
  'rose': 'rose',
  'lavender': 'lavender',
  'sunrise': 'sunrise',
  'pearl': 'pearl',
  'sage': 'olive-grove',
  'midnight-rose': 'evening',
  'starlight': 'starlight',
};

AppIconChoice appIconById(String id) =>
    appIcons.firstWhere((i) => i.id == id, orElse: () => appIcons.first);

/// The theme's matching icon.
AppIconChoice appIconForTheme(String themeId) =>
    appIconById(_themeIcons[themeId] ?? 'first-light');

/// The icon whose asset set iOS reports, or the primary icon.
AppIconChoice appIconByIosName(String? iosName) => appIcons
    .firstWhere((i) => i.iosName == iosName, orElse: () => appIcons.first);

/// Changes the Home Screen icon through the app's native channel. iOS
/// shows its own short note when the icon changes.
abstract final class AppIcons {
  static const _channel = MethodChannel('holyhim/app-icon');

  static Future<bool> supported() async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<AppIconChoice> current() async {
    try {
      return appIconByIosName(await _channel.invokeMethod<String>('current'));
    } catch (_) {
      return appIcons.first;
    }
  }

  /// Sets [icon] and returns the icon iOS now shows.
  static Future<AppIconChoice> set(AppIconChoice icon) async =>
      appIconByIosName(
          await _channel.invokeMethod<String>('set', icon.iosName));
}
