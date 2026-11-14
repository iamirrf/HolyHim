// Stand-in providers so real screens render without Firebase or the store.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:holyhim/domain/calendar.dart';
import 'package:holyhim/services/auth_service.dart';
import 'package:holyhim/services/billing.dart';
import 'package:holyhim/services/community.dart';
import 'package:holyhim/services/repository.dart';

class FakeAuth extends AuthNotifier {
  final AuthUser? user;
  final AuthState? fixed;
  FakeAuth(this.user, {this.fixed});
  @override
  AuthState build() => fixed ?? AuthState(user: user);
  @override
  void clearError() {}
}

class FakeRepository extends WalkRepository {
  final WalkState initial;
  FakeRepository(this.initial);
  @override
  WalkState build() => initial;
  @override
  void updateProfile(AppProfile value) =>
      state = state.copyWith(profile: value);
  @override
  void toggleSaved(int day, {DateTime? now}) {}
  @override
  Future<void> finishOnboardingDurably([AppProfile? profile]) async =>
      updateProfile((profile ?? state.profile)
          .copyWith(onboardedAt: DateTime(2026, 11, 4)));
}

class FakeBilling extends LifetimeController {
  final LifetimeState fixed;
  FakeBilling(this.fixed);
  @override
  LifetimeState build() => fixed;
}

const product = StoreProduct('holyhim_lifetime', 'All 365 lessons',
    'HolyHim Lifetime', 1.99, r'$1.99', 'USD');

AppProfile profile(
        {String name = 'Daniel Reyes',
        bool onboarded = true,
        Map<String, dynamic> draft = const {},
        List<String> hearts = const ['peace', 'hope'],
        String theme = 'blush',
        double readingScale = 1}) =>
    AppProfile(
        name: name,
        theme: theme,
        haptics: false,
        sounds: false,
        readingScale: readingScale,
        timeZone: 'America/New_York',
        reminderEnabled: true,
        reminderMinutes: 420,
        birthday: '1995-06-15',
        hearts: hearts,
        onboardedAt: onboarded ? DateTime(2026, 11, 4) : null,
        onboardingDraft: draft);

/// [read] lessons completed on consecutive days ending yesterday, plus today
/// when [today] is true.
Map<int, String> history(int read, {bool today = false, DateTime? now}) {
  final local = localNow(now ?? DateTime.now(), 'America/New_York');
  final out = <int, String>{};
  final total = read + (today ? 1 : 0);
  for (var i = 0; i < total; i++) {
    final daysAgo = total - i - (today ? 1 : 0);
    out[i + 1] =
        dateKey(DateTime(local.year, local.month, local.day - daysAgo));
  }
  return out;
}

Widget scope(Widget app,
    {WalkState? walk,
    AuthUser? user = const AuthUser(uid: 'review', email: 'daniel@example.com'),
    AuthState? auth,
    String? lastSignIn = 'apple',
    LifetimeState billing = const LifetimeState(loading: false, product: product),
    bool community = false}) {
  return ProviderScope(overrides: [
    authProvider.overrideWith(() => FakeAuth(user, fixed: auth)),
    repositoryProvider.overrideWith(
        () => FakeRepository(walk ?? WalkState(profile: profile()))),
    lifetimeProvider.overrideWith(() => FakeBilling(billing)),
    lastSignInProvider.overrideWith((ref) async => lastSignIn),
    if (community) ...[
      myMemberProvider.overrideWith((ref) => Stream.value(sampleMe)),
      hiddenProvider.overrideWith((ref) => Stream.value(const Hidden())),
      feedSourceProvider.overrideWith((ref, q) => Stream.value(samplePosts
          .where((p) => !q.prayers || p.kind == PostKind.prayer)
          .where((p) => !q.mine || p.authorId == 'review')
          .toList())),
      boardSourceProvider.overrideWith((ref, board) => Stream.value([
            ...sampleMembers
          ]..sort((a, b) => board == Board.streak
              ? b.streak.compareTo(a.streak)
              : b.days.compareTo(a.days)))),
      myRankProvider.overrideWith((ref, board) async => 7),
      postProvider.overrideWith((ref, id) =>
          Stream.value(samplePosts.firstWhere((p) => p.id == id))),
      repliesSourceProvider.overrideWith((ref, id) => Stream.value(sampleReplies)),
    ],
  ], child: app);
}

/// Sample brothers for renders and App Store screenshots. Fictional people.
final _ago = DateTime.now();
const sampleMe = Member(
    uid: 'review', name: 'Daniel', metal: 'brass', streak: 12, best: 12, days: 12, medal: 'days-7');
final sampleMembers = <Member>[
  const Member(uid: 'm1', name: 'Caleb', metal: 'silver', streak: 64, best: 64, days: 71, medal: 'days-50'),
  const Member(uid: 'm2', name: 'Marcus', metal: 'bronze', streak: 41, best: 52, days: 96, medal: 'days-75'),
  const Member(uid: 'm3', name: 'Josiah', metal: 'brass', streak: 33, best: 33, days: 40, medal: 'days-30'),
  const Member(uid: 'm4', name: 'Elijah', metal: 'steel', streak: 21, best: 30, days: 58, medal: 'days-50'),
  const Member(uid: 'm5', name: 'Noah', metal: 'pine', streak: 18, best: 18, days: 26, medal: 'days-21'),
  const Member(uid: 'm6', name: 'Isaac', metal: 'silver', streak: 14, best: 20, days: 35, medal: 'days-30'),
  sampleMe,
  const Member(uid: 'm7', name: 'Gabriel', metal: 'bronze', streak: 9, best: 15, days: 22, medal: 'days-21'),
  const Member(uid: 'm8', name: 'Samuel', metal: 'brass', streak: 6, best: 11, days: 17, medal: 'days-14'),
  const Member(uid: 'm9', name: 'Levi', metal: 'steel', streak: 4, best: 9, days: 9, medal: 'days-7'),
];
final samplePosts = <Post>[
  Post(
      id: 'p1', authorId: 'm1', authorName: 'Caleb', authorMetal: 'silver', authorMedal: 'days-50',
      authorStreak: 64, kind: PostKind.win, amens: 41, comments: 12,
      text: 'Day 64. Longest I have kept anything going in my life. Phone stays in the kitchen until I have read. Thank you, brothers.',
      createdAt: _ago.subtract(const Duration(minutes: 38))),
  Post(
      id: 'p2', authorId: 'm2', authorName: 'Marcus', authorMetal: 'bronze', authorMedal: 'days-75',
      authorStreak: 41, kind: PostKind.prayer, amens: 27, comments: 8, amenBy: const ['review'],
      text: 'Job interview Thursday morning. First real one. I am nervous. Would mean a lot if you prayed.',
      createdAt: _ago.subtract(const Duration(hours: 2))),
  Post(
      id: 'p3', authorId: 'm3', authorName: 'Josiah', authorMetal: 'brass', authorMedal: 'days-30',
      authorStreak: 33, amens: 22, comments: 3,
      text: 'Read this before practice. Fear shows up every time I step on the field. So does He.',
      verseRef: 'Joshua 1:9',
      verseText: 'Haven’t I commanded you? Be strong and courageous. Don’t be afraid. Don’t be dismayed, for Yahweh your God is with you wherever you go.',
      createdAt: _ago.subtract(const Duration(hours: 5))),
  Post(
      id: 'p4', authorId: 'm4', authorName: 'Elijah', authorMetal: 'steel', authorMedal: 'days-50',
      authorStreak: 21, amens: 18, comments: 6,
      text: 'Called my brother today after two years of silence. We talked for an hour. Iron sharpens iron is not just a verse.',
      createdAt: _ago.subtract(const Duration(hours: 9))),
  Post(
      id: 'p5', authorId: 'm5', authorName: 'Noah', authorMetal: 'pine', authorMedal: 'days-21',
      authorStreak: 18, kind: PostKind.prayer, amens: 33, comments: 9,
      text: 'My dad goes in for heart surgery tomorrow at 7. Pray for the surgeons, and for my mom.',
      createdAt: _ago.subtract(const Duration(hours: 20))),
];
final sampleReplies = <Reply>[
  Reply(id: 'r1', postId: 'p2', authorId: 'm1', authorName: 'Caleb', authorMetal: 'silver',
      text: 'Praying right now. Walk in like you belong there.', amens: 6,
      createdAt: _ago.subtract(const Duration(hours: 1))),
  Reply(id: 'r2', postId: 'p2', authorId: 'm5', authorName: 'Noah', authorMetal: 'pine',
      text: 'Philippians 4:6. You got this, brother.', amens: 4,
      createdAt: _ago.subtract(const Duration(minutes: 50))),
];
