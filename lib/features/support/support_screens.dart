import 'package:flutter/material.dart';
import 'package:holyher/data/legal_documents.dart';
import 'package:holyher/features/support/contact_screen.dart';
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
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              runSpacing: 0,
              children: [
                TextButton(
                    onPressed: () => openScreen(context, const PrivacyScreen()),
                    child: Text('Privacy',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary))),
                TextButton(
                    onPressed: () => openScreen(context, const TermsScreen()),
                    child: Text('Terms',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary))),
                TextButton(
                    onPressed: () => openScreen(context, const HelpScreen()),
                    child: Text('Help',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary))),
              ]));
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          title: 'About HolyHer',
          body: ReadingWidth(
              child: ListView(padding: const EdgeInsets.all(24), children: [
            const Align(
                alignment: Alignment.centerLeft, child: HolyMark(size: 64)),
            const SizedBox(height: 28),
            const Text('A daily moment with Scripture.',
                style: HolyTypography.section),
            const SizedBox(height: 16),
            const Text(
                'Daily Bible learning for women. One message to read, understand, and carry into your day.'),
            const SizedBox(height: 24),
            const Text(
                '365 lessons, in a deliberate order. One new lesson opens each calendar day. Keep every unlocked lesson and return whenever you need its words.'),
            const SizedBox(height: 20),
            const Text(
                'Bible quotations identify their translation. Original explanations and prayers are presented separately from Scripture.',
                style: HolyTypography.supporting),
            const SizedBox(height: 32),
            Text(
                'HolyHer · Version ${AppConstants.versionLabel}\nCodellion LLC',
                style: HolyTypography.supporting),
            const SizedBox(height: 24),
            HolyButton(
                label: 'Visit HolyHer',
                secondary: true,
                icon: Icons.open_in_new_rounded,
                onPressed: () =>
                    openExternal(context, AppConstants.websiteUrl)),
            const SizedBox(height: 16),
            const LegalFooter(),
          ]))));
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  static const _answers = [
    (
      'How does my daily journey work?',
      'Day 1 becomes available when your journey begins. One further lesson opens each calendar day in your journey’s timezone. You can revisit earlier lessons and complete any unlocked lesson you missed.'
    ),
    (
      'How do guided lessons work?',
      'Every lesson has five reading-only cards: Scripture, Meaning, Encouragement, Hope, and Prayer. Visit all five and tap Finish my reading to complete it. There are no quizzes or timers. Your place and progress are saved.'
    ),
    (
      'What does my focus change?',
      'Your focus shapes practical guidance; there are no written reflections. Your reading familiarity and routine choices shape helpful guidance. The scripture and ordered 365 lessons stay the same for everyone.'
    ),
    (
      'Can I read offline?',
      'The lesson library is included with the app. After starting your journey online, your unlocked lessons remain readable offline. Reconnect to open new daily lessons and sync completed messages.'
    ),
    (
      'Is this edition free?',
      'Starting during the free phase grants retained access to the HolyHer 365 edition. A lesson still unlocks each calendar day. A future pricing change will not revoke that retained grant.'
    ),
    (
      'Why is my reminder off?',
      'Reminders are optional and need notification permission. Choose a reminder in Settings. If permission was denied, enable notifications for HolyHer in your device’s Settings.'
    ),
    (
      'How do I delete my account?',
      'Open Profile → Settings → Delete account. This removes your cloud profile and saved progress. You can begin again with a new account at any time.'
    ),
  ];
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          title: 'Help & support',
          body: ReadingWidth(
              child: ListView(padding: const EdgeInsets.all(24), children: [
            const Text('How can we help?', style: HolyTypography.heading),
            const SizedBox(height: 24),
            for (final answer in _answers)
              DecoratedBox(
                  decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: AppColors.divider))),
                  child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(vertical: 10),
                      childrenPadding:
                          const EdgeInsets.only(bottom: 24, right: 20),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      iconColor: AppColors.accent,
                      collapsedIconColor: AppColors.textSecondary,
                      title: Text(answer.$1, style: HolyTypography.action),
                      children: [
                        Text(answer.$2,
                            style: HolyTypography.body
                                .copyWith(color: AppColors.textSecondary))
                      ])),
            const SectionLabel('Still need a hand?'),
            MenuRow(
                title: 'HolyHer support',
                subtitle: 'Send us a message',
                icon: Icons.support_agent_rounded,
                onTap: () => openScreen(context, const ContactScreen())),
            MenuRow(
                title: 'Send feedback',
                icon: Icons.chat_bubble_outline,
                onTap: () =>
                    openScreen(context, const ContactScreen(feedback: true))),
            if (AppConstants.supportEmail.isNotEmpty)
              MenuRow(
                  title: 'Email support',
                  subtitle: AppConstants.supportEmail,
                  icon: Icons.mail_outline_rounded,
                  onTap: () => openExternal(context,
                      'mailto:${AppConstants.supportEmail}?subject=HolyHer%20support')),
          ]))));
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => _LegalScreen(
          title: 'Privacy',
          eyebrow: 'Your private journey',
          introduction: 'Effective October 31, 2026',
          url: AppConstants.privacyUrl,
          sections: legalDocuments['privacy']!));
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => _LegalScreen(
          title: 'Terms',
          eyebrow: 'Using HolyHer',
          introduction: 'Effective October 31, 2026',
          url: AppConstants.termsUrl,
          sections: legalDocuments['terms']!));
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
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          title: title,
          body: ReadingWidth(
              child: ListView(padding: const EdgeInsets.all(24), children: [
            PageHeading(eyebrow: eyebrow, title: title, subtitle: introduction),
            const SizedBox(height: 24),
            for (final section in sections) ...[
              Text(section.$1, style: HolyTypography.section),
              const SizedBox(height: 12),
              Text(section.$2, style: HolyTypography.body),
              const SizedBox(height: 32),
            ],
            const SizedBox(height: 24),
            HolyButton(
                label: title == 'Terms'
                    ? 'Read full terms'
                    : 'Read full privacy policy',
                icon: Icons.open_in_new_rounded,
                secondary: true,
                onPressed: () => openExternal(context, url)),
            const SizedBox(height: 26)
          ]))));
}
