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

/// Every icon, in the order the App icon screen shows them: the cross in
/// each theme's colours. The symbols and seasons join when their drawings
/// are made (tool/art/app_icons.py lists them; --check keeps this in step).
const appIcons = [
  AppIconChoice('first-watch', null, 'First Watch', 'Themes'),
  AppIconChoice('limestone', 'AppIcon-Limestone', 'Limestone', 'Themes'),
  AppIconChoice('iron', 'AppIcon-Iron', 'Iron', 'Themes'),
  AppIconChoice('ember', 'AppIcon-Ember', 'Ember', 'Themes'),
  AppIconChoice('cedar', 'AppIcon-Cedar', 'Cedar', 'Themes'),
  AppIconChoice('midnight', 'AppIcon-Midnight', 'Midnight', 'Themes'),
  AppIconChoice('sandstone', 'AppIcon-Sandstone', 'Sandstone', 'Themes'),
  AppIconChoice('slate', 'AppIcon-Slate', 'Slate', 'Themes'),
];

/// The icon that wears each theme's colours, by stored theme ID.
const _themeIcons = {
  'blush': 'first-watch',
  'rose': 'limestone',
  'lavender': 'iron',
  'sunrise': 'ember',
  'sage': 'cedar',
  'midnight-rose': 'midnight',
  'pearl': 'sandstone',
  'starlight': 'slate',
};

AppIconChoice appIconById(String id) =>
    appIcons.firstWhere((i) => i.id == id, orElse: () => appIcons.first);

/// The theme's matching icon.
AppIconChoice appIconForTheme(String themeId) =>
    appIconById(_themeIcons[themeId] ?? 'first-watch');

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
