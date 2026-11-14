import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/badges.dart';
import '../domain/streak.dart';
import 'auth_service.dart';
import 'avatar_service.dart';
import 'repository.dart';

/// What a post is: a word from today's reading, a prayer request, or a win.
enum PostKind {
  word('word', 'Word'),
  prayer('prayer', 'Prayer'),
  win('win', 'Win');

  final String id, label;
  const PostKind(this.id, this.label);
  static PostKind of(Object? id) =>
      values.firstWhere((k) => k.id == id, orElse: () => word);
}

/// Feed order, after Cognein's: newest, most Amens, or rising now.
enum FeedSort {
  newest('new', 'Newest'),
  top('top', 'Top'),
  trending('trending', 'Trending');

  final String id, label;
  const FeedSort(this.id, this.label);
}

/// Coin metals a member can wear when he has no photo.
const memberMetals = ['brass', 'silver', 'bronze', 'steel', 'pine'];

DateTime? _time(Object? v) => v is Timestamp
    ? v.toDate()
    : v is DateTime
        ? v
        : null;
int _int(Object? v) => v is num ? v.toInt() : 0;
String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
List<String> _strings(Object? v) =>
    v is List ? [for (final x in v) if (x is String) x] : const [];

/// A brother's public card: what the community and the board can see.
@immutable
class Member {
  final String uid, name, metal, medal;
  final String? photo;
  final int streak, best, days;
  final DateTime? joinedAt;
  const Member(
      {required this.uid,
      required this.name,
      this.metal = 'brass',
      this.medal = '',
      this.photo,
      this.streak = 0,
      this.best = 0,
      this.days = 0,
      this.joinedAt});

  factory Member.fromMap(String uid, Map<String, dynamic> m) => Member(
      uid: uid,
      name: _str(m['name'], 'Brother'),
      metal: memberMetals.contains(m['metal']) ? m['metal'] as String : 'brass',
      medal: _str(m['medal']),
      photo: _str(m['photo']).isEmpty ? null : m['photo'] as String,
      streak: _int(m['streak']),
      best: _int(m['best']),
      days: _int(m['days']),
      joinedAt: _time(m['joinedAt']));

  String get initial => name.trim().isEmpty ? 'H' : name.trim()[0].toUpperCase();
}

@immutable
class Post {
  final String id, authorId, authorName, authorMetal, authorMedal, text;
  final String? authorPhoto, verseRef, verseText;
  final PostKind kind;
  final int authorStreak, amens, comments;
  final List<String> amenBy;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool hidden;
  const Post(
      {required this.id,
      required this.authorId,
      required this.authorName,
      required this.text,
      required this.createdAt,
      this.authorMetal = 'brass',
      this.authorMedal = '',
      this.authorPhoto,
      this.verseRef,
      this.verseText,
      this.kind = PostKind.word,
      this.authorStreak = 0,
      this.amens = 0,
      this.comments = 0,
      this.amenBy = const [],
      this.editedAt,
      this.hidden = false});

  factory Post.fromMap(String id, Map<String, dynamic> m) => Post(
      id: id,
      authorId: _str(m['authorId']),
      authorName: _str(m['authorName'], 'Brother'),
      authorMetal: _str(m['authorMetal'], 'brass'),
      authorMedal: _str(m['authorMedal']),
      authorPhoto: _str(m['authorPhoto']).isEmpty ? null : m['authorPhoto'] as String,
      authorStreak: _int(m['authorStreak']),
      text: _str(m['text']),
      kind: PostKind.of(m['kind']),
      verseRef: _str(m['verseRef']).isEmpty ? null : m['verseRef'] as String,
      verseText: _str(m['verseText']).isEmpty ? null : m['verseText'] as String,
      amens: _int(m['amens']),
      comments: _int(m['comments']),
      amenBy: _strings(m['amenBy']),
      createdAt: _time(m['createdAt']) ?? DateTime.now(),
      editedAt: _time(m['editedAt']),
      hidden: m['hidden'] == true);

  bool amenedBy(String? uid) => uid != null && amenBy.contains(uid);

  /// Hacker News' gravity: Amens and replies, cooling with age.
  double get heat {
    final hours = DateTime.now().difference(createdAt).inMinutes / 60;
    return (amens + 2 * comments + 1) / math.pow(hours + 2, 1.5);
  }
}

@immutable
class Reply {
  final String id, postId, authorId, authorName, authorMetal, text;
  final String? authorPhoto;
  final int amens;
  final List<String> amenBy;
  final DateTime createdAt;
  final bool hidden;
  const Reply(
      {required this.id,
      required this.postId,
      required this.authorId,
      required this.authorName,
      required this.text,
      required this.createdAt,
      this.authorMetal = 'brass',
      this.authorPhoto,
      this.amens = 0,
      this.amenBy = const [],
      this.hidden = false});

  factory Reply.fromMap(String postId, String id, Map<String, dynamic> m) =>
      Reply(
          id: id,
          postId: postId,
          authorId: _str(m['authorId']),
          authorName: _str(m['authorName'], 'Brother'),
          authorMetal: _str(m['authorMetal'], 'brass'),
          authorPhoto:
              _str(m['authorPhoto']).isEmpty ? null : m['authorPhoto'] as String,
          text: _str(m['text']),
          amens: _int(m['amens']),
          amenBy: _strings(m['amenBy']),
          createdAt: _time(m['createdAt']) ?? DateTime.now(),
          hidden: m['hidden'] == true);
}

/// What this person has chosen not to see: brothers he blocked and posts
/// or replies he reported.
@immutable
class Hidden {
  final Set<String> users, posts;
  const Hidden({this.users = const {}, this.posts = const {}});
  bool hides(String authorId, String id) =>
      users.contains(authorId) || posts.contains(id);
}

class CommunityException implements Exception {
  final String message;
  const CommunityException(this.message);
  @override
  String toString() => message;
}

FirebaseFirestore? _db(Ref ref) => ref.watch(repositoryFirestoreProvider);
String? _uid(Ref ref) => ref.watch(authProvider.select((a) => a.user?.uid));

/// This person's own card, or null before he joins.
final myMemberProvider = StreamProvider<Member?>((ref) {
  final db = _db(ref), uid = _uid(ref);
  if (db == null || uid == null) return Stream.value(null);
  return db.doc('members/$uid').snapshots().map((s) =>
      s.exists && s.data() != null ? Member.fromMap(uid, s.data()!) : null);
});

final hiddenProvider = StreamProvider<Hidden>((ref) {
  final db = _db(ref), uid = _uid(ref);
  if (db == null || uid == null) return Stream.value(const Hidden());
  return db.doc('users/$uid/social/hidden').snapshots().map((s) {
    final m = s.data() ?? const {};
    return Hidden(
        users: _strings(m['users']).toSet(), posts: _strings(m['posts']).toSet());
  });
});

@immutable
class FeedQuery {
  final FeedSort sort;
  final bool mine, prayers;
  const FeedQuery(
      {this.sort = FeedSort.newest, this.mine = false, this.prayers = false});
  @override
  bool operator ==(Object other) =>
      other is FeedQuery &&
      other.sort == sort &&
      other.mine == mine &&
      other.prayers == prayers;
  @override
  int get hashCode => Object.hash(sort, mine, prayers);
}

/// The raw feed for a query, before this person's blocks and reports.
final feedSourceProvider =
    StreamProvider.family<List<Post>, FeedQuery>((ref, q) {
  final db = _db(ref), uid = _uid(ref);
  if (db == null || uid == null) return Stream.value(const []);
  Query<Map<String, dynamic>> query = db.collection('posts');
  if (q.mine) {
    query = query.where('authorId', isEqualTo: uid);
  } else if (q.prayers) {
    query = query.where('kind', isEqualTo: 'prayer');
  } else if (q.sort == FeedSort.top) {
    query = query.orderBy('amens', descending: true);
  } else {
    query = query.orderBy('createdAt', descending: true);
  }
  return query.limit(q.mine || q.prayers ? 200 : 100).snapshots().map((s) {
    final posts = [for (final d in s.docs) Post.fromMap(d.id, d.data())];
    switch (q.sort) {
      case FeedSort.newest:
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FeedSort.top:
        posts.sort((a, b) => b.amens != a.amens
            ? b.amens.compareTo(a.amens)
            : b.createdAt.compareTo(a.createdAt));
      case FeedSort.trending:
        posts.sort((a, b) => b.heat.compareTo(a.heat));
    }
    return posts;
  });
});

/// The feed as this person sees it: hidden and reported posts gone, blocked
/// brothers gone, his own posts always shown.
final feedProvider = Provider.family<AsyncValue<List<Post>>, FeedQuery>((ref, q) {
  final uid = _uid(ref);
  final hidden = ref.watch(hiddenProvider).valueOrNull ?? const Hidden();
  return ref.watch(feedSourceProvider(q)).whenData((posts) => [
        for (final p in posts)
          if (p.authorId == uid || (!p.hidden && !hidden.hides(p.authorId, p.id)))
            p
      ]);
});

final postProvider = StreamProvider.family<Post?, String>((ref, id) {
  final db = _db(ref);
  if (db == null) return Stream.value(null);
  return db.doc('posts/$id').snapshots().map(
      (s) => s.exists && s.data() != null ? Post.fromMap(s.id, s.data()!) : null);
});

final repliesSourceProvider =
    StreamProvider.family<List<Reply>, String>((ref, postId) {
  final db = _db(ref);
  if (db == null) return Stream.value(const []);
  return db
      .collection('posts/$postId/comments')
      .orderBy('createdAt')
      .limit(300)
      .snapshots()
      .map((s) => [for (final d in s.docs) Reply.fromMap(postId, d.id, d.data())]);
});

final repliesProvider =
    Provider.family<AsyncValue<List<Reply>>, String>((ref, postId) {
  final uid = _uid(ref);
  final hidden = ref.watch(hiddenProvider).valueOrNull ?? const Hidden();
  return ref.watch(repliesSourceProvider(postId)).whenData((replies) => [
        for (final r in replies)
          if (r.authorId == uid || (!r.hidden && !hidden.hides(r.authorId, r.id)))
            r
      ]);
});

/// The board: by current streak, or by every day ever read.
enum Board {
  streak('streak', 'Streak'),
  days('days', 'Days read');

  final String field, label;
  const Board(this.field, this.label);
}

final boardSourceProvider =
    StreamProvider.family<List<Member>, Board>((ref, board) {
  final db = _db(ref), uid = _uid(ref);
  if (db == null || uid == null) return Stream.value(const []);
  return db
      .collection('members')
      .orderBy(board.field, descending: true)
      .limit(50)
      .snapshots()
      .map((s) => [for (final d in s.docs) Member.fromMap(d.id, d.data())]);
});

final boardProvider =
    Provider.family<AsyncValue<List<Member>>, Board>((ref, board) {
  final hidden = ref.watch(hiddenProvider).valueOrNull ?? const Hidden();
  return ref.watch(boardSourceProvider(board)).whenData(
      (members) => [for (final m in members) if (!hidden.users.contains(m.uid)) m]);
});

/// This person's place on a board, counted on the server.
final myRankProvider = FutureProvider.family<int?, Board>((ref, board) async {
  final db = _db(ref);
  final me = ref.watch(myMemberProvider).valueOrNull;
  if (db == null || me == null) return null;
  final mine = board == Board.streak ? me.streak : me.days;
  final above = await db
      .collection('members')
      .where(board.field, isGreaterThan: mine)
      .count()
      .get();
  return (above.count ?? 0) + 1;
});

/// The public numbers for this person, from his own walk.
({int streak, int best, int days, String medal}) memberStats(WalkState state) {
  final streak = streakFor(state.completed, DateTime.now(), state.profile.timeZone);
  final badges = badgesFor(
      completed: state.completed,
      saved: state.saved,
      streak: streak,
      promiseStartedAt: state.profile.promiseStartedAt,
      timeZone: state.profile.timeZone);
  final medal = badges
      .where((b) => b.earned && b.id.startsWith('days-'))
      .fold<String>('', (best, b) => b.id);
  return (
    streak: streak.current,
    best: streak.longest,
    days: state.completed.length,
    medal: medal
  );
}

final communityProvider = Provider<Community>((ref) => Community(ref));

/// Every write the community makes. Posts, replies, edits, deletes and
/// reports go through the server, which checks them; Amens, blocks and this
/// person's own card are written directly under the database rules.
class Community {
  final Ref ref;
  Community(this.ref);

  FirebaseFirestore get _firestore {
    final db = ref.read(repositoryFirestoreProvider);
    if (db == null) throw const CommunityException('You are offline right now.');
    return db;
  }

  String get _me {
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) throw const CommunityException('Please sign in first.');
    return uid;
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final result =
          await FirebaseFunctions.instance.httpsCallable(name).call(data);
      final value = result.data;
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    } on FirebaseFunctionsException catch (e) {
      throw CommunityException(e.message ?? 'That did not go through. Try again.');
    }
  }

  /// Joins the brotherhood under [name], after agreeing to the rules.
  Future<void> join({required String name, required String metal}) async {
    final uid = _me;
    final state = ref.read(repositoryProvider);
    final stats = memberStats(state);
    final profile = state.profile;
    final auth = ref.read(authProvider).user;
    final photo = visibleAvatarUrl(profile.avatarUrl, auth?.photoUrl);
    await _firestore.doc('members/$uid').set({
      'name': name.trim(),
      'metal': metal,
      'photo': photo ?? '',
      'streak': stats.streak,
      'best': stats.best,
      'days': stats.days,
      'medal': stats.medal,
      'agreedAt': FieldValue.serverTimestamp(),
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCard({String? name, String? metal, String? photo}) async {
    final uid = _me;
    await _firestore.doc('members/$uid').update({
      if (name != null) 'name': name.trim(),
      if (metal != null) 'metal': metal,
      if (photo != null) 'photo': photo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Keeps the board honest with his own walk. Writes only when a number
  /// moved.
  Future<void> syncStats(Member me) async {
    final stats = memberStats(ref.read(repositoryProvider));
    if (stats.streak == me.streak &&
        stats.best == me.best &&
        stats.days == me.days &&
        stats.medal == me.medal) {
      return;
    }
    await _firestore.doc('members/${me.uid}').update({
      'streak': stats.streak,
      'best': stats.best,
      'days': stats.days,
      'medal': stats.medal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leave() async {
    await _call('communityLeave', const {});
  }

  Future<String> post(String text, PostKind kind,
      {String? verseRef, String? verseText}) async {
    final r = await _call('communityPost', {
      'text': text.trim(),
      'kind': kind.id,
      if (verseRef != null) 'verseRef': verseRef,
      if (verseText != null) 'verseText': verseText,
    });
    return _str(r['id']);
  }

  Future<void> edit(String postId, String text) =>
      _call('communityEdit', {'postId': postId, 'text': text.trim()});

  Future<void> reply(String postId, String text) =>
      _call('communityComment', {'postId': postId, 'text': text.trim()});

  Future<void> delete(String postId, {String? replyId}) => _call(
      'communityDelete', {'postId': postId, if (replyId != null) 'commentId': replyId});

  Future<void> report(String postId,
      {String? replyId, required String reason}) async {
    await _call('communityReport', {
      'postId': postId,
      if (replyId != null) 'commentId': replyId,
      'reason': reason,
    });
    await _hide(posts: [replyId ?? postId]);
  }

  Future<void> amen(Post post) async {
    final uid = _me;
    final on = post.amenedBy(uid);
    await _firestore.doc('posts/${post.id}').update({
      'amenBy': on ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      'amens': FieldValue.increment(on ? -1 : 1),
    });
  }

  Future<void> amenReply(Reply reply) async {
    final uid = _me;
    final on = reply.amenBy.contains(uid);
    await _firestore.doc('posts/${reply.postId}/comments/${reply.id}').update({
      'amenBy': on ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      'amens': FieldValue.increment(on ? -1 : 1),
    });
  }

  Future<void> block(String uid) => _hide(users: [uid]);

  Future<void> unblock(String uid) async {
    final me = _me;
    await _firestore.doc('users/$me/social/hidden').set({
      'users': FieldValue.arrayRemove([uid]),
    }, SetOptions(merge: true));
  }

  Future<void> _hide({List<String> users = const [], List<String> posts = const []}) async {
    final me = _me;
    await _firestore.doc('users/$me/social/hidden').set({
      if (users.isNotEmpty) 'users': FieldValue.arrayUnion(users),
      if (posts.isNotEmpty) 'posts': FieldValue.arrayUnion(posts),
    }, SetOptions(merge: true));
  }

  /// A member's public card, read once.
  Future<Member?> member(String uid) async {
    final s = await _firestore.doc('members/$uid').get();
    return s.exists && s.data() != null ? Member.fromMap(uid, s.data()!) : null;
  }
}

/// Patterns the server refuses (functions/moderation.json), checked here
/// first so a post is never typed in vain. The server's check is the one
/// that counts; a test keeps the two lists the same.
const communityBlockedPatterns = [
  r'\bf+u+c*k',
  r'\bf+c+k',
  r'\bsh+[i1]+t',
  r'\bbitch',
  r'\bcunt',
  r'\bdick(s|head)?\b',
  r'\bcock(s|sucker)?\b',
  r'\bpuss(y|ies)\b',
  r'\bwhore',
  r'\bslut',
  r'\bbastard',
  r'\ba(ss|rse)hole',
  r'\bnigg(a|er|ah|az|as|ers)',
  r'\bfag(s|got|gots)?\b',
  r'\bretard(s|ed)?\b',
  r'\btrann(y|ies)\b',
  r'\bkike',
  r'\bspics?\b',
  r'\bchinks?\b',
  r'\bporn',
  r'\bnudes?\b',
  r'\bonlyfans',
  r'\bsex ?chat',
  r'\bkys\b',
  r'kill (yo)?urself',
  r'\bgo die\b',
];
final _blocked = [
  for (final p in communityBlockedPatterns) RegExp(p, caseSensitive: false)
];

/// Folds look-alike characters so "sh1t" reads as what it is.
String foldForModeration(String text) => text
    .toLowerCase()
    .replaceAll('0', 'o')
    .replaceAll('1', 'i')
    .replaceAll('3', 'e')
    .replaceAll('4', 'a')
    .replaceAll('5', 's')
    .replaceAll('@', 'a')
    .replaceAll('\$', 's');

/// A short reason the text cannot be posted, or null when it can.
String? communityTextProblem(String text, {int max = 600}) {
  final t = text.trim();
  if (t.length < 2) return 'Write a little more first.';
  if (t.length > max) return 'Keep it under $max characters.';
  final plain = foldForModeration(t);
  if (RegExp(r'(https?://|www\.|\.(com|net|org|io|co|ly|gg)\b)').hasMatch(plain)) {
    return 'Links are not allowed here.';
  }
  if (_blocked.any((p) => p.hasMatch(plain))) return 'Keep it clean, brother.';
  return null;
}
