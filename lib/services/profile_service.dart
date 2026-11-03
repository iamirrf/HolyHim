import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:holyher/features/onboarding/checkpoint.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/auth_service.dart';
import 'package:holyher/services/local_store.dart';
import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/reminder_service.dart';

class UserProfile {
  final String name, familiarity, focus, obstacle, theme;
  final double readingScale;
  final int? reminderMinutes;
  final bool onboardingComplete, haptics, sounds, tips, largerText, loaded;
  final int onboardingStep;
  final Set<String> onboardingAnswered;
  final int? suggestedReminderMinutes;
  final String reminderDecision;
  final String? guidedExampleAnswer;
  final bool guidedExampleRevealed;
  String get onboardingStepId => OnboardingStages
      .ids[onboardingStep.clamp(0, OnboardingStages.ids.length - 1)];
  const UserProfile(
      {this.name = '',
      this.theme = 'pearl',
      this.readingScale = 1,
      this.familiarity = 'new',
      this.focus = 'peace',
      this.obstacle = 'busy',
      this.reminderMinutes,
      this.onboardingComplete = false,
      this.haptics = true,
      this.sounds = true,
      this.tips = true,
      this.largerText = false,
      this.loaded = false,
      this.onboardingStep = 0,
      this.onboardingAnswered = const {},
      this.suggestedReminderMinutes = 480,
      this.reminderDecision = 'pending',
      this.guidedExampleAnswer,
      this.guidedExampleRevealed = false});
  UserProfile copyWith(
          {String? name,
          String? theme,
          double? readingScale,
          String? familiarity,
          String? focus,
          String? obstacle,
          int? reminderMinutes,
          bool clearReminder = false,
          bool? onboardingComplete,
          bool? haptics,
          bool? sounds,
          bool? tips,
          bool? largerText,
          bool? loaded,
          int? onboardingStep,
          Set<String>? onboardingAnswered,
          int? suggestedReminderMinutes,
          bool clearSuggestedReminder = false,
          String? reminderDecision,
          String? guidedExampleAnswer,
          bool? guidedExampleRevealed}) =>
      UserProfile(
          name: name ?? this.name,
          theme: theme ?? this.theme,
          readingScale: readingScale ?? this.readingScale,
          familiarity: familiarity ?? this.familiarity,
          focus: focus ?? this.focus,
          obstacle: obstacle ?? this.obstacle,
          reminderMinutes:
              clearReminder ? null : reminderMinutes ?? this.reminderMinutes,
          onboardingComplete: onboardingComplete ?? this.onboardingComplete,
          haptics: haptics ?? this.haptics,
          sounds: sounds ?? this.sounds,
          tips: tips ?? this.tips,
          largerText: largerText ?? this.largerText,
          loaded: loaded ?? this.loaded,
          onboardingStep: onboardingStep ?? this.onboardingStep,
          onboardingAnswered: onboardingAnswered ?? this.onboardingAnswered,
          suggestedReminderMinutes: clearSuggestedReminder
              ? null
              : suggestedReminderMinutes ?? this.suggestedReminderMinutes,
          reminderDecision: reminderDecision ?? this.reminderDecision,
          guidedExampleAnswer: guidedExampleAnswer ?? this.guidedExampleAnswer,
          guidedExampleRevealed:
              guidedExampleRevealed ?? this.guidedExampleRevealed);
  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'theme': theme,
        'readingScale': readingScale,
        'familiarity': familiarity,
        'focus': focus,
        'obstacle': obstacle,
        'reminderMinutes': reminderMinutes,
        'onboardingComplete': onboardingComplete,
        'haptics': haptics,
        'sounds': sounds,
        'tips': tips,
        'largerText': largerText,
        'onboardingVersion': 4,
        'onboardingStepId': onboardingStepId,
        'onboardingAnswered': onboardingAnswered.toList()..sort(),
        'suggestedReminderMinutes': suggestedReminderMinutes,
        'reminderDecision': reminderDecision,
        'guidedExampleAnswer': guidedExampleAnswer,
        'guidedExampleRevealed': guidedExampleRevealed,
        'onboardingStep': onboardingStep
      };
  factory UserProfile.fromJson(Map<String, dynamic> data) => UserProfile(
      theme: const ['pearl', 'rose', 'lavender', 'sage', 'dawn', 'midnight']
              .contains(data['theme'])
          ? data['theme'] as String
          : 'pearl',
      readingScale: data['readingScale'] is num
          ? (data['readingScale'] as num).toDouble().clamp(1, 2)
          : 1,
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
      sounds: data['sounds'] != false,
      tips: data['tips'] != false,
      largerText: data['largerText'] == true,
      loaded: true,
      onboardingStep: OnboardingStages.migrate(data),
      onboardingAnswered: OnboardingStages.answered(data),
      suggestedReminderMinutes: data['suggestedReminderMinutes'] is int &&
              (data['suggestedReminderMinutes'] as int) >= 0 &&
              (data['suggestedReminderMinutes'] as int) < 1440
          ? data['suggestedReminderMinutes'] as int
          : data['onboardingVersion'] == 3
              ? null
              : data['reminderMinutes'] as int? ?? 480,
      reminderDecision: const ['pending', 'enabled', 'declined', 'denied']
              .contains(data['reminderDecision'])
          ? data['reminderDecision'] as String
          : data['reminderMinutes'] is int
              ? 'enabled'
              : 'pending',
      guidedExampleAnswer: data['guidedExampleAnswer'] is String
          ? data['guidedExampleAnswer'] as String
          : null,
      guidedExampleRevealed: data['guidedExampleRevealed'] == true);
}

class ProfileNotifier extends Notifier<UserProfile> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Future<void>? _loading;
  int _generation = 0, _draftRevision = 0;
  Timer? _draftTimer;
  bool _draftDirty = false;
  String? _uid;
  @override
  UserProfile build() {
    _uid = ref.watch(authProvider.select((s) => s.user?.uid));
    ref.watch(localStoreProvider);
    final generation = ++_generation;
    _subscription?.cancel();
    _draftTimer?.cancel();
    _draftDirty = false;
    _draftRevision++;
    _loading = null;
    ref.onDispose(() {
      _generation++;
      _subscription?.cancel();
      _draftTimer?.cancel();
    });
    Future.microtask(() {
      if (_generation == generation) {
        unawaited(initialize().catchError((Object _) {}));
      }
    });
    return const UserProfile();
  }

  Future<void> initialize() => _loading ??= _load(_generation);
  Future<void> _load(int generation) async {
    final store = ref.read(localStoreProvider);
    final raw = await store.read('profile');
    final pending = await store.read('profile_pending') == true;
    final finalizing = await store.read('profile_finalizing') == true;
    if (_generation != generation) return;
    _draftDirty = pending;
    UserProfile cached = const UserProfile(loaded: true);
    if (raw is String) {
      try {
        cached = UserProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        throw StateError(
            'Your saved setup could not be read. Contact support before resetting data.');
      }
    } else if (raw != null) {
      throw StateError(
          'Your saved setup could not be read. Contact support before resetting data.');
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
      if (finalizing) {
        try {
          final remote = await document
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 8));
          if (_generation != generation) return;
          if (remote.data()?['onboardingComplete'] == true) {
            cached = UserProfile.fromJson(remote.data()!);
            if (!await writeLocalBatch(store, {
              'profile': jsonEncode(cached.toJson()),
              'profile_finalizing': false,
              'profile_pending': false
            })) {
              throw StateError('Setup recovery could not be saved.');
            }
            if (_generation != generation) return;
            _draftDirty = false;
          }
        } catch (_) {}
      }
      if (_generation != generation) return;
      state = cached;
      _reconcileReminder(cached.reminderMinutes);
      _subscription =
          document.snapshots(includeMetadataChanges: true).listen((doc) {
        if (_generation != generation ||
            _draftDirty ||
            doc.metadata.hasPendingWrites) {
          return;
        }
        final data = doc.data();
        if (data != null) {
          state = UserProfile.fromJson(data);
          _reconcileReminder(state.reminderMinutes);
          unawaited(store.write('profile', jsonEncode(state.toJson())));
        }
      }, onError: (Object _) {});
      if (pending && !finalizing) unawaited(flushDraft());
    } else {
      state = cached;
    }
  }

  Future<void> saveDraft(UserProfile profile) async {
    final generation = _generation;
    await initialize();
    if (generation != _generation) throw StateError('Account changed.');
    final store = ref.read(localStoreProvider);
    if (!await writeLocalBatch(store,
        {'profile': jsonEncode(profile.toJson()), 'profile_pending': true})) {
      throw StateError('Your setup could not be saved on this device.');
    }
    if (generation != _generation) return;
    state = profile.copyWith(loaded: true);
    _draftDirty = true;
    _draftRevision++;
    _draftTimer?.cancel();
    _draftTimer =
        Timer(const Duration(milliseconds: 800), () => unawaited(flushDraft()));
  }

  Future<void> flushDraft() async {
    _draftTimer?.cancel();
    if (!_draftDirty || _uid == null || Firebase.apps.isEmpty) return;
    final generation = _generation,
        revision = _draftRevision,
        uid = _uid!,
        snapshot = state,
        store = ref.read(localStoreProvider);
    try {
      if (await store.read('profile_finalizing') == true ||
          generation != _generation) {
        return;
      }
      await FirebaseFirestore.instance
          .doc('users/$uid')
          .set(snapshot.toJson(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      if (generation == _generation && revision == _draftRevision) {
        if (await store.write('profile_pending', false) &&
            generation == _generation &&
            revision == _draftRevision) {
          _draftDirty = false;
        }
      }
    } catch (_) {
      /* The draft remains queued locally; final save exposes failure. */
    }
  }

  Future<void> save(UserProfile profile) async {
    final generation = _generation;
    await initialize();
    if (generation != _generation) throw StateError('Account changed.');
    _draftTimer?.cancel();
    final revision = ++_draftRevision;
    _draftDirty = true;
    final uid = _uid;
    final store = ref.read(localStoreProvider);
    final saved = profile.copyWith(loaded: true);
    final finalizing = saved.onboardingComplete && !state.onboardingComplete;
    if (!await writeLocalBatch(store, {
      'profile': jsonEncode(
          (finalizing ? saved.copyWith(onboardingComplete: false) : saved)
              .toJson()),
      'profile_pending': true,
      if (finalizing) 'profile_finalizing': true
    })) {
      throw StateError('Your changes could not be saved. Please try again.');
    }
    if (_generation != generation || _draftRevision != revision) return;
    if (!finalizing) state = saved;
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
    if (_generation == generation && _draftRevision == revision) {
      if (!await writeLocalBatch(store, {
        'profile': jsonEncode(saved.toJson()),
        'profile_pending': false,
        if (finalizing) 'profile_finalizing': false
      })) {
        throw StateError(
            'Your setup was confirmed online but could not be saved here. Please retry.');
      }
      if (_generation != generation || _draftRevision != revision) return;
      _draftDirty = false;
      state = saved;
    }
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
    } else if (kIsWeb) {
      await save(state.copyWith(
          reminderMinutes: minutes, reminderDecision: 'enabled'));
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
