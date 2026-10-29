import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/services/local_store.dart';

/// FUTURE SEAM: SharedPreferences local unlock in v1; RevenueCat at ship time.
/// Keep initialize()/unlock()/restore(): `Future<void>` / `Future<bool>` and
/// paywallProvider's boolean gate.
/// Ship time (App Store gate, must be done before submission): replace the
/// local implementation with a RevenueCat $1.99 lifetime product, valid
/// entitlement handling, and REAL Restore Purchases. The local restore()
/// below only re-reads the on-device unlock flag; it is NOT a store
/// restore and must not ship as one.
/// No purchases_flutter calls, products, credentials, or checkout exist in v1.
class PaywallNotifier extends Notifier<bool> {
  // Preserve the legacy lifetime key: changing it would re-lock existing users.
  static const _kUnlocked = 'paywall_lifetime_unlocked';
  Future<void>? _loaded;
  Future<void>? _unlocking;
  bool _alive = true;

  @override
  bool build() {
    ref.onDispose(() => _alive = false);
    return false;
  }

  Future<void> initialize() => _loaded ??= _load();

  Future<void> _load() async {
    final raw = await ref.read(localStoreProvider).read(_kUnlocked);
    if (_alive) state = raw is bool ? raw : false;
  }

  Future<void> unlock() => _unlocking ??= _unlock();

  Future<void> _unlock() async {
    final store = ref.read(localStoreProvider);
    await initialize();
    if (!_alive || state) return;
    await store.write(_kUnlocked, true);
    if (_alive) state = true;
  }

  /// Local-only restore for v1: re-reads the on-device unlock flag.
  /// Returns true if this device already unlocked. Ship time must replace
  /// this with a real RevenueCat restore before App Store submission.
  Future<bool> restore() async {
    await initialize();
    return state;
  }
}

final paywallProvider =
    NotifierProvider<PaywallNotifier, bool>(PaywallNotifier.new);
