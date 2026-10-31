import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';

void openScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
Future<void> openExternal(BuildContext context, String address) async {
  final uri = Uri.tryParse(address);
  try {
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {/* The in-app information remains available. */}
  if (context.mounted) {
    showNotice(
        context, 'This link could not be opened. Please try again later.');
  }
}

class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          runSpacing: 0,
          children: [
            TextButton(
                onPressed: () => openScreen(context, const PrivacyScreen()),
                child: const Text('Privacy',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary))),
            TextButton(
                onPressed: () => openScreen(context, const TermsScreen()),
                child: const Text('Terms',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary))),
            TextButton(
                onPressed: () => openScreen(context, const HelpScreen()),
                child: const Text('Help',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary))),
          ]);
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => HolyScaffold(
      title: 'About HolyHer',
      body: ReadingWidth(
          child: ListView(padding: const EdgeInsets.all(26), children: [
        const Align(alignment: Alignment.centerLeft, child: HolyMark(size: 96)),
        const SizedBox(height: 28),
        const PageHeading(
            eyebrow: 'Faith for the everyday',
            title: 'A small moment.\nA steady companion.',
            subtitle:
                'HolyHer makes room for one Bible message each day, with confidence grounded in scripture and a reflection to carry into ordinary life.'),
        const SizedBox(height: 28),
        GlassSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('The daily practice'),
          const SizedBox(height: 18),
          Text('Verse. Confidence. Reason. Hope. Carry.',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          const Text(
              '365 lessons, in a deliberate order. One new lesson each calendar day, with earlier lessons available to revisit. Your questionnaire shapes the way you apply the lesson; every reader receives the same ordered scripture journey.',
              style: TextStyle(fontSize: 14, height: 1.8)),
          const SizedBox(height: 18),
          const Text(
              'Bible quotations are identified by translation. Devotional reflections are original writing and are labeled separately from scripture.',
              style: TextStyle(
                  fontSize: 13, height: 1.8, color: AppColors.textSecondary))
        ])),
        const SectionLabel('Made with care'),
        const Text('HolyHer · Version 1.0\nCodellion LLC',
            style: TextStyle(
                fontSize: 13, height: 1.9, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        HolyButton(
            label: 'Visit HolyHer',
            secondary: true,
            icon: Icons.open_in_new_rounded,
            onPressed: () => openExternal(context, AppConstants.websiteUrl)),
        const SizedBox(height: 20),
        const LegalFooter(),
      ])));
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  static const _answers = [
    (
      'How does my daily journey work?',
      'Day 1 becomes available when your journey begins. One further lesson opens each calendar day in your journey’s timezone. You can revisit earlier lessons and complete any unlocked lesson you missed.'
    ),
    (
      'Do I need to finish all five cards?',
      'Read Verse, Confidence, Reason, Hope, and Carry. The Complete button appears on the final card. Your progress is saved when you complete the lesson.'
    ),
    (
      'What does my focus change?',
      'Your focus adds an application question on the Carry card. Your reading familiarity and routine choices shape helpful guidance. The scripture and ordered 365 lessons stay the same for everyone.'
    ),
    (
      'Can I read offline?',
      'The lesson library is included with the app. After signing in and verifying your purchase online, your unlocked lessons remain readable offline. Reconnect to open new daily lessons and sync completed messages.'
    ),
    (
      'How do I restore my purchase?',
      'Choose Restore purchases from the paywall or Settings while using the Apple Account that bought HolyHer. A completed lifetime purchase does not expire.'
    ),
    (
      'Why is my reminder off?',
      'Reminders are optional and need notification permission. Choose a reminder in Settings. If permission was denied, enable notifications for HolyHer in your device’s Settings.'
    ),
    (
      'How do I delete my account?',
      'Open Profile → Settings → Delete account. This removes your cloud profile and saved progress. Account deletion does not refund a purchase; Apple handles refunds.'
    ),
  ];
  @override
  Widget build(BuildContext context) => HolyScaffold(
      title: 'Help & support',
      body: ReadingWidth(
          child: ListView(padding: const EdgeInsets.all(26), children: [
        const PageHeading(
            eyebrow: 'A little help',
            title: 'Find your way.',
            subtitle: 'A few answers to make your daily rhythm feel simple.'),
        const SizedBox(height: 26),
        for (final answer in _answers)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassSurface(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  radius: 24,
                  child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(answer.$1,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.5)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(answer.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.8,
                                color: AppColors.textSecondary))
                      ]))),
        const SectionLabel('Still need a hand?'),
        MenuRow(
            title: 'HolyHer support',
            subtitle: 'Visit our support page',
            icon: Icons.support_agent_rounded,
            onTap: () => openExternal(context, AppConstants.supportUrl)),
        if (AppConstants.supportEmail.isNotEmpty)
          MenuRow(
              title: 'Email support',
              subtitle: AppConstants.supportEmail,
              icon: Icons.mail_outline_rounded,
              onTap: () => openExternal(context,
                  'mailto:${AppConstants.supportEmail}?subject=HolyHer%20support')),
      ])));
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalScreen(
          title: 'Privacy',
          eyebrow: 'Your private journey',
          introduction:
              'Here is how HolyHer handles the information used by the app.',
          url: AppConstants.privacyUrl,
          sections: [
            (
              'Your account and progress',
              'Your sign-in provider supplies your account identifier and account details such as email or name. Your private profile includes the answers you choose to give during setup, your preferences, journey start, and lesson completion history. These are stored locally and synced to your account using Firebase.'
            ),
            (
              'Purchases',
              'Apple processes the payment. RevenueCat verifies purchase status so HolyHer can provide and restore lifetime access. HolyHer does not receive your payment-card details.'
            ),
            (
              'Optional reminders',
              'If you choose a reminder and grant permission, HolyHer schedules local notifications on your device. You can switch them off in HolyHer Settings or in your device’s notification settings.'
            ),
            (
              'Your choices',
              'You can edit your name, setup answers, and reminder preferences in Settings. Delete account removes the account and its cloud profile and progress. Signing out removes access to that account’s locally displayed journey.'
            ),
            (
              'More information',
              'The full privacy policy explains our service providers, retention, account deletion, and how to contact us. You can open it below.'
            ),
          ]);
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LegalScreen(
          title: 'Terms',
          eyebrow: 'Using HolyHer',
          introduction:
              'Please read the full terms before using HolyHer or making a purchase.',
          url: AppConstants.termsUrl,
          sections: [
            (
              'Your daily journey',
              'HolyHer provides devotional reading and reflection. The lessons offer religious encouragement and personal reflection. Devotional writing is labeled separately from Bible quotations.'
            ),
            (
              'Lifetime access',
              'A lifetime purchase is a one-time purchase of access to HolyHer’s lesson library. The offer and price shown by the App Store apply at checkout. There is no recurring subscription for this purchase.'
            ),
            (
              'Your account',
              'Keep your sign-in details secure. You are responsible for the activity on your account. You can remove your account and cloud progress from Settings.'
            ),
            (
              'Purchases and support',
              'Apple processes App Store payments and refund requests. Use Restore purchases to check an existing purchase. Contact HolyHer support for help with the app.'
            ),
            (
              'Full agreement',
              'The full terms below govern the service, including permitted use, ownership, availability, limitations, and contact details.'
            ),
          ]);
}

class _LegalScreen extends StatelessWidget {
  final String title;
  final String eyebrow;
  final String introduction;
  final String url;
  final List<(String, String)> sections;
  const _LegalScreen(
      {required this.title,
      required this.eyebrow,
      required this.introduction,
      required this.url,
      required this.sections});
  @override
  Widget build(BuildContext context) => HolyScaffold(
      title: title,
      body: ReadingWidth(
          child: ListView(padding: const EdgeInsets.all(26), children: [
        PageHeading(eyebrow: eyebrow, title: title, subtitle: introduction),
        const SizedBox(height: 24),
        GlassSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final section in sections) ...[
            Text(section.$1,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
            const SizedBox(height: 8),
            Text(section.$2,
                style: const TextStyle(
                    fontSize: 14, height: 1.8, color: AppColors.textSecondary)),
            const SizedBox(height: 24)
          ]
        ])),
        const SizedBox(height: 24),
        HolyButton(
            label: title == 'Terms'
                ? 'Read full terms'
                : 'Read full privacy policy',
            icon: Icons.open_in_new_rounded,
            secondary: true,
            onPressed: () => openExternal(context, url)),
        const SizedBox(height: 26)
      ])));
}
