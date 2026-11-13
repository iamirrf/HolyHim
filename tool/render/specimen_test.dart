import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/design/design.dart';
import 'harness.dart';

const out = 'build/render/specimen';

class Specimen extends StatelessWidget {
  const Specimen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Scaffold(
        backgroundColor: t.paper,
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Wordmark(size: 44, color: t.ink),
                      const SizedBox(height: 18),
                      Text('A word for your morning',
                          style: HolyTypography.display.copyWith(color: t.ink)),
                      const SizedBox(height: 10),
                      Flourish(color: t.gold),
                      const SizedBox(height: 14),
                      Paper(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Eyebrow("Today's word"),
                                const SizedBox(height: 10),
                                Text(
                                    '“God is our refuge and strength, a very present help in trouble.”',
                                    style: HolyTypography.verse
                                        .copyWith(color: t.ink)),
                                const SizedBox(height: 10),
                                Text('Psalm 46:1 · WEB',
                                    style: HolyTypography.label
                                        .copyWith(color: t.accent)),
                                const SizedBox(height: 14),
                                Text(
                                    'You do not have to be strong first. God is already with you, right in the middle of the hard thing.',
                                    style: HolyTypography.reading
                                        .copyWith(color: t.ink, fontSize: 19)),
                              ])),
                      const SizedBox(height: 18),
                      Row(children: [
                        Text('12',
                            style: HolyTypography.numeral
                                .copyWith(color: t.ink)),
                        const SizedBox(width: 8),
                        Text('day walk',
                            style: HolyTypography.label
                                .copyWith(color: t.muted)),
                        const Spacer(),
                        Text('Amen.',
                            style: HolyTypography.accent
                                .copyWith(color: t.accent)),
                      ]),
                      const SizedBox(height: 16),
                      HolyButton('Begin today’s walk', onPressed: () {}),
                      const SizedBox(height: 10),
                      Row(children: [
                        HolySwitch(value: true, onChanged: (_) {}),
                        const SizedBox(width: 8),
                        const HolyCheck(checked: true),
                        const SizedBox(width: 12),
                        const HolySpinner(),
                        const Spacer(),
                        IconControl(
                            icon: CupertinoIcons.heart,
                            onPressed: () {},
                            label: 'Save'),
                      ]),
                    ]))));
  }
}

class Field extends StatefulWidget {
  const Field({super.key});
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  final a = TextEditingController(text: 'daniel@example.com');
  final b = TextEditingController();
  final c = TextEditingController(text: 'secret');
  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return Scaffold(
        backgroundColor: t.paper,
        body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
            child: Column(children: [
              HolyField(controller: a, label: 'Email'),
              const SizedBox(height: 14),
              HolyField(controller: b, label: 'First name'),
              const SizedBox(height: 14),
              HolyField(
                  controller: c,
                  label: 'Password',
                  password: true,
                  error: 'Use at least 8 characters.'),
              const SizedBox(height: 14),
              ChoiceTile(
                  label: 'Peace in a busy season',
                  detail: 'Quiet for the noise in my head',
                  selected: true,
                  onPressed: () {}),
              const SizedBox(height: 10),
              ChoiceTile(
                  label: 'Strength for a hard time',
                  selected: false,
                  onPressed: () {}),
            ])));
  }
}

class OnPhoto extends StatelessWidget {
  const OnPhoto({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      body: PhotoStage(
          images: const ['assets/art/library/scripture-morning.webp'],
          timeOfDay: false,
          topVeil: .3,
          bottomVeil: .6,
          child: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const SizedBox(height: 30),
                    const Wordmark(size: 46, color: HolyTheme.photoInk),
                    const Spacer(),
                    HolyButton('Continue',
                        style: HolyButtonStyle.photoPrimary, onPressed: () {}),
                    const SizedBox(height: 10),
                    HolyButton('Use email',
                        style: HolyButtonStyle.onPhoto, onPressed: () {}),
                    const SizedBox(height: 10),
                    AppleButton(onPressed: () {}),
                  ])))));
}

void main() {
  setUpAll(loadFonts);
  testWidgets('type specimen', (tester) async {
    for (final theme in [HolyThemes.blush, HolyThemes.midnightRose]) {
      await capture(tester, '$out/specimen-${theme.id}.png', const Specimen(),
          theme: theme);
    }
    await capture(tester, '$out/fields.png', const Field());
    await capture(tester, '$out/photo.png', const OnPhoto());
  });
}
