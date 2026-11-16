abstract final class AppConstants {
  static const versionName = '2.0.0',
      buildNumber = '8',
      versionLabel = '2.0.0 (8)',
      wireVersion = '2.0.0+8';
  static const appName = 'HolyHim',
      totalDays = 365,
      tagline = 'A quiet word with God, every morning.';
  static const websiteUrl = 'https://holyhim-app-production.web.app';
  static const privacyUrl = '$websiteUrl/privacy',
      termsUrl = '$websiteUrl/terms',
      supportUrl = '$websiteUrl/support';

  /// HolyHim's numeric App Store ID, so a shared keepsake opens the
  /// listing directly. A build can still override it.
  static const appStoreId =
      String.fromEnvironment('APP_STORE_ID', defaultValue: '');
  static const shareUrl = appStoreId == ''
      ? websiteUrl
      : 'https://apps.apple.com/app/id$appStoreId';
}
