import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/profile_service.dart';

/// All app-owned haptic paths read the preference at the moment of delivery.
class AppFeedback {
  final Ref ref;
  AppFeedback(this.ref);
  void selection() {
    if (ref.read(profileProvider).haptics) HapticFeedback.selectionClick();
  }

  void light() {
    if (ref.read(profileProvider).haptics) HapticFeedback.lightImpact();
  }
}

final feedbackProvider = Provider<AppFeedback>((ref) => AppFeedback(ref));
