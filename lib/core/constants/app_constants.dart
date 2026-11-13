abstract final class AppConstants {
  static const versionName = '1.0.0',
      buildNumber = '1',
      versionLabel = '1.0.0 (1)',
      wireVersion = '1.0.0+1';
  static const appName = 'HolyHim',
      totalDays = 365,
      tagline = 'A word to stand on, every morning.';
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
