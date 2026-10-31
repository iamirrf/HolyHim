import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/features/support/support_screens.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/paywall_service.dart';
import 'package:holyher/services/profile_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Future<void> _restore() async {
    final restored = await ref.read(paywallProvider.notifier).restore();
    if (!mounted) return;
    if (restored) {
      showNotice(context, 'Your lifetime access has been restored.');
    } else if (ref.read(purchaseProvider).error == null) {
      showNotice(
          context, 'No lifetime purchase was found for this store account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchase = ref.watch(purchaseProvider);
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);
    return PopScope(
        canPop: false,
        child: HolyScaffold(
            body: ReadingWidth(
                maxWidth: 640,
                child: LayoutBuilder(builder: (context, box) {
                  final natural = box.maxHeight < 600 ||
                      MediaQuery.textScalerOf(context).scale(16) > 25;
                  final content = <Widget>[
                    Row(children: [
                      const Expanded(child: Eyebrow('Your year of faith')),
                      Flexible(
                          child: TextButton(
                              onPressed: purchase.loading ? null : _restore,
                              child: const Text('Restore purchases',
                                  style: TextStyle(fontSize: 11))))
                    ]),
                    const SizedBox(height: 12),
                    const Center(child: HolyMark(size: 78)),
                    const SizedBox(height: 22),
                    Text(
                        profile.name.isEmpty
                            ? 'A little faith.\nA lifetime to carry it.'
                            : '${profile.name}, make room\nfor a little faith.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 14),
                    const Text(
                        '365 moments with God.\nOne simple purchase. Yours to return to.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.8,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 25),
                    GlassSurface(
                        highlighted: true,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow('HolyHer · Lifetime'),
                              const SizedBox(height: 16),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                        child: Text(purchase.price,
                                            style: const TextStyle(
                                                fontSize: 43,
                                                fontWeight: FontWeight.w500,
                                                height: 1.15,
                                                letterSpacing: -1.5,
                                                color: AppColors.accentDark))),
                                    const SizedBox(width: 12),
                                    const Flexible(
                                        child: Padding(
                                            padding: EdgeInsets.only(bottom: 5),
                                            child: Text('One time.\nForever.',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    height: 1.7,
                                                    color: AppColors
                                                        .textSecondary))))
                                  ]),
                              const SizedBox(height: 21),
                              const Divider(),
                              const SizedBox(height: 18),
                              const _Benefit(
                                  Icons.auto_stories_outlined,
                                  '365 thoughtfully written lessons',
                                  'One new message each day, with every past lesson ready to revisit.'),
                              const _Benefit(
                                  Icons.style_outlined,
                                  'Five beautiful learning cards',
                                  'Verse, Confidence, Reason, Hope, and Carry.'),
                              const _Benefit(
                                  Icons.spa_outlined,
                                  'A rhythm that feels like yours',
                                  'Personal application, reminders, and progress across devices.'),
                              const _Benefit(
                                  Icons.cloud_download_outlined,
                                  'A little peace, wherever you are',
                                  'Revisit unlocked lessons offline. New days and saved progress update when you reconnect.'),
                            ])),
                    if (natural && purchase.error != null)
                      InlineMessage(purchase.error!, error: true),
                    if (natural && auth.error != null)
                      InlineMessage(auth.error!, error: true),
                    TextButton(
                        onPressed: purchase.loading || auth.loading
                            ? null
                            : () => ref.read(authProvider.notifier).signOut(),
                        child: const Text('Switch account',
                            style: TextStyle(fontSize: 11))),
                  ];
                  final actions = Padding(
                      padding: const EdgeInsets.fromLTRB(27, 16, 27, 3),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (purchase.error != null)
                          InlineMessage(purchase.error!, error: true),
                        if (auth.error != null)
                          InlineMessage(auth.error!, error: true),
                        HolyButton(
                            label: 'Unlock forever · ${purchase.price}',
                            icon: Icons.lock_open_rounded,
                            busy: purchase.loading,
                            onPressed: purchase.loading
                                ? null
                                : () => ref
                                    .read(paywallProvider.notifier)
                                    .unlock()),
                        const SizedBox(height: 12),
                        const Text(
                            'One-time lifetime purchase. No recurring charge.\nPayment is confirmed through the App Store.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                height: 1.8,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 3),
                        const LegalFooter(),
                      ]));
                  if (natural) {
                    return ListView(
                        padding: const EdgeInsets.fromLTRB(27, 16, 27, 20),
                        children: [
                          ...content,
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(children: [
                                HolyButton(
                                    label: 'Unlock forever · ${purchase.price}',
                                    busy: purchase.loading,
                                    onPressed: purchase.loading
                                        ? null
                                        : () => ref
                                            .read(paywallProvider.notifier)
                                            .unlock()),
                                const SizedBox(height: 15),
                                const Text(
                                    'One-time lifetime purchase. No recurring charge.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 10,
                                        height: 1.8,
                                        color: AppColors.textSecondary)),
                                const LegalFooter()
                              ]))
                        ]);
                  }
                  return Column(children: [
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.fromLTRB(27, 16, 27, 5),
                            children: content)),
                    actions
                  ]);
                }))));
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Benefit(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: AppColors.accent),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, height: 1.5)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11, height: 1.7, color: AppColors.textSecondary))
        ]))
      ]));
}
