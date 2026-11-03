import 'package:holyher/core/constants/build_info.dart';
import 'package:holyher/core/theme/holy_typography.dart';

/// Product identity for the free HolyHer 365 edition.
abstract final class AppConstants {
  static String get versionName =>
      HolyTypography.nativeResolution?['appVersion'] as String? ??
      AppBuildInfo.name;
  static String get buildNumber =>
      HolyTypography.nativeResolution?['appBuild'] as String? ??
      AppBuildInfo.build;
  static String get versionLabel => '$versionName ($buildNumber)';
  static String get wireVersion => '$versionName+$buildNumber';
  static const appName = 'HolyHer';
  static const tagline = 'Walk with God, one day at a time.';
  static const totalDays = 365;
  static const websiteUrl = 'https://holyher-app-production.web.app';
  static const privacyUrl = '$websiteUrl/privacy';
  static const termsUrl = '$websiteUrl/terms';
  static const supportUrl = '$websiteUrl/support';
  static const supportEmail = String.fromEnvironment('HOLYHER_SUPPORT_EMAIL');
}
