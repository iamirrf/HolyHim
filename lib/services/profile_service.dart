import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/reminder_service.dart';

class UserProfile {
  final String name, familiarity, focus, obstacle;
  final int? reminderMinutes;
  final bool onboardingComplete, haptics, loaded;
  final int onboardingStep;
  const UserProfile(
      {this.name = '',
      this.familiarity = 'new',
      this.focus = 'peace',
      this.obstacle = 'busy',
      this.reminderMinutes,
      this.onboardingComplete = false,
      this.haptics = true,
      this.loaded = false,
      this.onboardingStep = 0});
  UserProfile copyWith(
          {String? name,
          String? familiarity,
          String? focus,
          String? obstacle,
          int? reminderMinutes,
          bool clearReminder = false,
          bool? onboardingComplete,
          bool? haptics,
          bool? loaded,
          int? onboardingStep}) =>
      UserProfile(
          name: name ?? this.name,
          familiarity: familiarity ?? this.familiarity,
          focus: focus ?? this.focus,
          obstacle: obstacle ?? this.obstacle,
          reminderMinutes:
              clearReminder ? null : reminderMinutes ?? this.reminderMinutes,
          onboardingComplete: onboardingComplete ?? this.onboardingComplete,
          haptics: haptics ?? this.haptics,
          loaded: loaded ?? this.loaded,
          onboardingStep: onboardingStep ?? this.onboardingStep);
  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'familiarity': familiarity,
        'focus': focus,
        'obstacle': obstacle,
        'reminderMinutes': reminderMinutes,
        'onboardingComplete': onboardingComplete,
        'haptics': haptics,
        'onboardingStep': onboardingStep
      };
  factory UserProfile.fromJson(Map<String, dynamic> data) => UserProfile(
      name: data['name'] is String ? data['name'] as String : '',
      familiarity:
          data['familiarity'] is String ? data['familiarity'] as String : 'new',
      focus: data['focus'] is String ? data['focus'] as String : 'peace',
      obstacle:
          data['obstacle'] is String ? data['obstacle'] as String : 'busy',
      reminderMinutes: data['reminderMinutes'] is int &&
              (data['reminderMinutes'] as int) >= 0 &&
              (data['reminderMinutes'] as int) < 1440
          ? data['reminderMinutes'] as int
          : null,
      onboardingComplete: data['onboardingComplete'] == true,
      haptics: data['haptics'] != false,
      loaded: true,
      onboardingStep: data['onboardingStep'] is int
          ? (data['onboardingStep'] as int).clamp(0, 6)
          : 0);
}

class ProfileNotifier extends Notifier<UserProfile> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Future<void>? _loading;
  int _generation = 0;
  String? _uid;
  @override
  UserProfile build() {
    _uid = ref.watch(authProvider.select((s) => s.user?.uid));
    ref.watch(localStoreProvider);
    final generation = ++_generation;
    _subscription?.cancel();
    _loading = null;
    ref.onDispose(() {
      _generation++;
      _subscription?.cancel();
    });
    Future.microtask(() {
      if (_generation == generation) initialize();
    });
    return const UserProfile();
  }

  Future<void> initialize() => _loading ??= _load(_generation);
  Future<void> _load(int generation) async {
    final store = ref.read(localStoreProvider);
    final raw = await store.read('profile');
    UserProfile cached = const UserProfile(loaded: true);
    if (raw is String) {
      try {
        cached = UserProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    if (_generation != generation) return;
    final uid = _uid;
    if (uid != null && Firebase.apps.isNotEmpty) {
      final document = FirebaseFirestore.instance.collection('users').doc(uid);
      if (raw == null) {
        final initial = await document
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 15));
        if (_generation != generation) return;
        cached = initial.data() == null
            ? const UserProfile(loaded: true)
            : UserProfile.fromJson(initial.data()!);
      }
      state = cached;
      _reconcileReminder(cached.reminderMinutes);
      _subscription =
          document.snapshots(includeMetadataChanges: true).listen((doc) {
        if (_generation != generation || doc.metadata.hasPendingWrites) return;
        final data = doc.data();
        if (data != null) {
          state = UserProfile.fromJson(data);
          _reconcileReminder(state.reminderMinutes);
          unawaited(store.write('profile', jsonEncode(state.toJson())));
        }
      }, onError: (Object _) {});
    } else {
      state = cached;
    }
  }

  Future<void> save(UserProfile profile) async {
    final generation = _generation;
    final uid = _uid;
    final store = ref.read(localStoreProvider);
    final saved = profile.copyWith(loaded: true);
    if (!await store.write('profile', jsonEncode(saved.toJson()))) {
      throw StateError('Your changes could not be saved. Please try again.');
    }
    if (uid != null && Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(saved.toJson(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        throw StateError(
            'Your changes are saved on this device. Reconnect to finish syncing.');
      }
    }
    if (_generation == generation) state = saved;
  }

  void _reconcileReminder(int? minutes) {
    final generation = _generation;
    unawaited(ref.read(reminderServiceProvider).reconcile(minutes).then((_) {
      if (_generation == generation) ref.invalidate(reminderEnabledProvider);
    }).catchError((Object _) {}));
  }

  Future<void> setReminder(int? minutes) async {
    if (minutes == null) {
      await ref.read(reminderServiceProvider).cancel();
      await save(state.copyWith(clearReminder: true));
      ref.invalidate(reminderEnabledProvider);
    } else {
      final allowed = await ref.read(reminderServiceProvider).schedule(minutes);
      if (!allowed) {
        throw StateError(
            'Allow notifications in your device Settings to turn on reminders.');
      }
      await save(state.copyWith(reminderMinutes: minutes));
      ref.invalidate(reminderEnabledProvider);
    }
  }

  Future<void> setHaptics(bool enabled) =>
      save(state.copyWith(haptics: enabled));
}

final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
