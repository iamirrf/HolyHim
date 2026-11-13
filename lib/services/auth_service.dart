import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:holyhim/services/notifications.dart';
import 'package:holyhim/firebase_options.dart';
import 'firebase_runtime.dart';
import 'widget_bridge.dart';
import 'account_cache.dart';

class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool emailVerified, isNewAccount;
  const AuthUser(
      {required this.uid,
      this.email = '',
      this.displayName = '',
      this.photoUrl,
      this.emailVerified = false,
      this.isNewAccount = false});
  factory AuthUser.fromFirebase(fb.User user) => AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      isNewAccount: user.metadata.creationTime != null &&
          user.metadata.lastSignInTime != null &&
          user.metadata.creationTime!
              .isAtSameMomentAs(user.metadata.lastSignInTime!));
}

enum AuthAction {
  apple,
  google,
  email,
  createAccount,
  reset,
  signOut,
  deleteAccount
}

class AuthState {
  final AuthAction? action;
  final AuthUser? user;
  final bool loading;
  final bool configured;
  final String? error;
  const AuthState(
      {this.user,
      this.action,
      this.loading = false,
      this.configured = true,
      this.error});
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<fb.User?>? _subscription;
  bool _disposed = false, _running = false;
  Future<void>? _googleInitialization;
  @override
  AuthState build() {
    _disposed = false;
    if (!ref.watch(firebaseReadyProvider) || Firebase.apps.isEmpty) {
      return const AuthState(configured: false);
    }
    _subscription = fb.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!_disposed) {
        state =
            AuthState(user: user == null ? null : AuthUser.fromFirebase(user));
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });
    final user = fb.FirebaseAuth.instance.currentUser;
    return AuthState(user: user == null ? null : AuthUser.fromFirebase(user));
  }

  void clearError() =>
      state = AuthState(user: state.user, configured: state.configured);
  Future<void> _run(Future<void> Function() action, {AuthAction? kind}) async {
    if (_running || state.loading) return;
    if (!state.configured) {
      state = const AuthState(
          configured: false,
          error: 'We could not connect right now. Please try again shortly.');
      return;
    }
    _running = true;
    state = AuthState(user: state.user, loading: true, action: kind);
    try {
      await action().timeout(const Duration(seconds: 30));
      final user = fb.FirebaseAuth.instance.currentUser;
      final method = switch (kind) {
        AuthAction.apple => 'apple',
        AuthAction.google => 'google',
        AuthAction.email || AuthAction.createAccount => 'email',
        _ => null,
      };
      if (method != null && user != null) {
        unawaited(SharedPreferences.getInstance()
            .then((prefs) => prefs.setString(lastSignInKey, method))
            .then<void>((_) {})
            .catchError((Object _) {}));
      }
      if (!_disposed) {
        state =
            AuthState(user: user == null ? null : AuthUser.fromFirebase(user));
      }
    } on fb.FirebaseAuthException catch (e) {
      if (!_disposed) {
        state = AuthState(
            user: state.user,
            error: const [
              'popup-closed-by-user',
              'cancelled-popup-request',
              'web-context-cancelled'
            ].contains(e.code)
                ? null
                : authErrorMessage(e.code));
      }
    } on GoogleSignInException catch (e) {
      if (!_disposed) {
        state = AuthState(
            user: state.user,
            error: e.code == GoogleSignInExceptionCode.canceled
                ? null
                : 'Google sign-in could not finish. Please try again.');
      }
    } catch (_) {
      if (!_disposed) {
        state = AuthState(
            user: state.user,
            error:
                'Something interrupted that request. Check your connection and try again.');
      }
    } finally {
      _running = false;
    }
  }

  Future<void> signInEmail(String email, String password) => _run(() async {
        await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.trim(), password: password);
      }, kind: AuthAction.email);
  Future<void> signUpEmail(String email, String password) => _run(() async {
        final result = await fb.FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: email.trim(), password: password);
        try {
          final verification = result.user?.sendEmailVerification();
          if (verification != null) {
            unawaited(verification
                .timeout(const Duration(seconds: 5))
                .catchError((Object _) {}));
          }
        } catch (_) {/* Account remains usable; verification can be retried. */}
      }, kind: AuthAction.createAccount);
  Future<void> resetPassword(String email) => _run(() async {
        try {
          await fb.FirebaseAuth.instance
              .sendPasswordResetEmail(email: email.trim());
        } on fb.FirebaseAuthException catch (error) {
          if (error.code != 'user-not-found') rethrow;
        }
      }, kind: AuthAction.reset);
  Future<void> signInApple() => _run(() async {
        final provider = fb.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        if (kIsWeb) {
          await fb.FirebaseAuth.instance.signInWithPopup(provider);
        } else {
          await fb.FirebaseAuth.instance.signInWithProvider(provider);
        }
      }, kind: AuthAction.apple);
  Future<fb.OAuthCredential> _googleCredential() async {
    if (HolyHimFirebaseOptions.googleClientId.isEmpty) {
      throw fb.FirebaseAuthException(code: 'operation-not-allowed');
    }
    _googleInitialization ??= GoogleSignIn.instance
        .initialize(clientId: HolyHimFirebaseOptions.googleClientId);
    await _googleInitialization;
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw StateError('Missing Google token');
    return fb.GoogleAuthProvider.credential(idToken: token);
  }

  Future<void> signInGoogle() => _run(() async {
        if (kIsWeb) {
          await fb.FirebaseAuth.instance
              .signInWithPopup(fb.GoogleAuthProvider());
        } else {
          await fb.FirebaseAuth.instance
              .signInWithCredential(await _googleCredential());
        }
      }, kind: AuthAction.google);
  Future<void> signOut() => _run(() async {
        await fb.FirebaseAuth.instance.signOut();
        unawaited(ref.read(notificationServiceProvider).cancel());
        unawaited(ref.read(widgetBridgeProvider).clear());
        if (!kIsWeb) {
          try {
            await GoogleSignIn.instance.signOut();
          } catch (_) {}
        }
      });
  Future<void> reauthenticate({String? password}) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('apple.com')) {
      await user.reauthenticateWithProvider(fb.AppleAuthProvider());
    } else if (providers.contains('google.com')) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(fb.GoogleAuthProvider());
      } else {
        await user.reauthenticateWithCredential(await _googleCredential());
      }
    } else {
      await user.reauthenticateWithCredential(fb.EmailAuthProvider.credential(
          email: user.email!, password: password ?? ''));
    }
    await user.getIdToken(true);
  }

  Future<void> deleteAccount({String? password}) => _run(() async {
        final user = fb.FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final providers = user.providerData.map((p) => p.providerId).toSet();
        if (providers.contains('apple.com')) {
          final result =
              await user.reauthenticateWithProvider(fb.AppleAuthProvider());
          final code = result.additionalUserInfo?.authorizationCode;
          if (code == null) {
            throw StateError('Apple authorization could not be renewed');
          }
          try {
            // Revocation needs the Sign in with Apple key in Firebase. If it
            // is unavailable, deleting the account must still go ahead.
            await fb.FirebaseAuth.instance
                .revokeTokenWithAuthorizationCode(code);
          } on fb.FirebaseAuthException catch (e) {
            debugPrint('Apple token revocation failed: ${e.code}');
          }
        } else if (providers.contains('google.com')) {
          if (kIsWeb) {
            await user.reauthenticateWithPopup(fb.GoogleAuthProvider());
          } else {
            await user.reauthenticateWithCredential(await _googleCredential());
          }
        } else if (password != null && password.isNotEmpty) {
          await user.reauthenticateWithCredential(
              fb.EmailAuthProvider.credential(
                  email: user.email!, password: password));
        }
        await user.getIdToken(true);
        await FirebaseFunctions.instance
            .httpsCallable('deleteAccount')
            .call<void>();
        await ref.read(accountCacheProvider).remove(user.uid);
        await fb.FirebaseAuth.instance.signOut();
        unawaited(ref.read(notificationServiceProvider).cancel());
        unawaited(ref.read(widgetBridgeProvider).clear());
      });
}

String authErrorMessage(String code) => switch (code) {
      'popup-closed-by-user' ||
      'cancelled-popup-request' ||
      'web-context-cancelled' =>
        '',
      'popup-blocked' =>
        'Your browser blocked sign-in. Allow pop-ups for HolyHim and try again.',
      'invalid-email' => 'Please enter a valid email address.',
      'email-already-in-use' =>
        'There is already an account with this email. Try signing in.',
      'weak-password' => 'Choose a password with at least 8 characters.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'That email and password did not match. Please try again.',
      'network-request-failed' =>
        'You appear to be offline. Please reconnect and try again.',
      'too-many-requests' => 'Please wait a moment before trying again.',
      'requires-recent-login' =>
        'Please sign in again before deleting your account.',
      'canceled' => 'Sign-in was cancelled. You can try again anytime.',
      'operation-not-allowed' =>
        'This sign-in method is temporarily unavailable. Please try email.',
      _ => 'We could not finish signing you in. Please try again.'
    };
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// The sign-in method used last on this device: 'apple', 'google' or 'email'.
const lastSignInKey = 'holyhim.lastSignIn';
final lastSignInProvider = FutureProvider<String?>((ref) async {
  try {
    return (await SharedPreferences.getInstance()).getString(lastSignInKey);
  } catch (_) {
    return null;
  }
});
