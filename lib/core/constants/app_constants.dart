/// App-wide copy. Single source of truth for names, taglines, prices.
abstract final class AppConstants {
  static const appName = 'HolyHer';
  static const tagline = 'God is within her, she will not fall.';
  // Locked pricing (2026-10-29, supersedes subscription pricing):
  // $1.99 lifetime, one time, forever. Owner will change pricing later.
  static const lifetimePriceLabel = r'$1.99';
  static const paywallTitle = 'Unlock HolyHer';
  static const paywallSubtitle = 'One message a day, every day.';
  static const pricingSummary = r'$1.99, one time, forever';
  static const lifetimeStart = 'Unlock forever — $lifetimePriceLabel';
  static const totalDays = 365;
}
