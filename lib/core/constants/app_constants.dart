/// Product identity. Store prices are loaded from the localized StoreKit product.
abstract final class AppConstants {
  static const appName = 'HolyHer';
  static const tagline = 'A little faith. A little courage. Every day.';
  static const lifetimePriceLabel = r'$1.99';
  static const paywallTitle = 'A year of hope. Yours forever.';
  static const paywallSubtitle =
      '365 daily Bible lessons. One gentle step at a time.';
  static const pricingSummary = r'$1.99, one time, forever';
  static const lifetimeStart = 'Unlock forever — $lifetimePriceLabel';
  static const totalDays = 365;
  static const websiteUrl = 'https://holyher-app-production.web.app';
  static const privacyUrl = '$websiteUrl/privacy';
  static const termsUrl = '$websiteUrl/terms';
  static const supportUrl = '$websiteUrl/support';
  static const supportEmail = String.fromEnvironment('HOLYHER_SUPPORT_EMAIL');
  static const entitlementId = 'lifetime';
  static const productId = 'holyher_lifetime';
  static const revenueCatIosKey = String.fromEnvironment(
      'REVENUECAT_IOS_API_KEY',
      defaultValue: 'appl_RrNQZSCHRwuHEksPJVqfuVWBMMo');
}
