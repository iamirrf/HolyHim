import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/glass_button.dart';
import 'package:holyher/services/paywall_service.dart';

/// $1.99 lifetime purchase, HARD paywall during onboarding: no skip,
/// no close button. Onboarding leads here; home unlocks after purchase.
/// Locked pricing (2026-10-29, supersedes subscription pricing):
/// $1.99, one time, forever. Owner will change pricing later.
/// v1 unlocks locally; the store purchase seam lives in
/// paywall_service.dart. Restore Purchases must be wired to RevenueCat
/// before App Store submission (see paywall_service.dart).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _starting = false;
  bool _restoring = false;
  String? _restoreMessage;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  AppConstants.paywallTitle,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConstants.lifetimePriceLabel,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const Text(
                  'One time. Forever.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  AppConstants.paywallSubtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.accent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lifetime',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pay once, keep HolyHer forever.',
                              style: TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        r'$1.99',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const _Benefit(text: 'Every daily message, all 365 days'),
                const _Benefit(text: 'No subscription. No renewals.'),
                const _Benefit(text: 'Your streak and progress, kept for you'),
                const SizedBox(height: 40),
                GlassButton(
                  label: _starting
                      ? 'Unlocking…'
                      : AppConstants.lifetimeStart,
                  onPressed: _starting
                      ? null
                      : () async {
                          setState(() => _starting = true);
                          await ref.read(paywallProvider.notifier).unlock();
                        },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _restoring
                      ? null
                      : () async {
                          setState(() {
                            _restoring = true;
                            _restoreMessage = null;
                          });
                          final restored = await ref
                              .read(paywallProvider.notifier)
                              .restore();
                          if (mounted) {
                            setState(() {
                              _restoring = false;
                              _restoreMessage = restored
                                  ? null
                                  : 'No previous purchase found on this device.';
                            });
                          }
                        },
                  child: Text(_restoring ? 'Restoring…' : 'Restore Purchases'),
                ),
                if (_restoreMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _restoreMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final String text;

  const _Benefit({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
