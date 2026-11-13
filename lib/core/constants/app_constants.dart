abstract final class AppConstants {
  static const versionName = '2.0.0',
      buildNumber = '6',
      versionLabel = '2.0.0 (6)',
      wireVersion = '2.0.0+6';
  static const appName = 'HolyHim',
      totalDays = 365,
      tagline = 'A quiet word with God, every morning.';
  static const websiteUrl = 'https://holyhim-app-production.web.app';
  static const privacyUrl = '$websiteUrl/privacy',
      termsUrl = '$websiteUrl/terms',
      supportUrl = '$websiteUrl/support';

  /// Set once App Store Connect assigns the numeric app ID. Until then
  /// shared keepsakes point to the website, which links to the store.
  static const appStoreId = String.fromEnvironment('APP_STORE_ID');
  static const shareUrl = appStoreId == ''
      ? websiteUrl
      : 'https://apps.apple.com/app/id$appStoreId';
}
