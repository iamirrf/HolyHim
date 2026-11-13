import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bootstrap updates this after a late Firebase initialization as well as an
/// ordinary launch. Auth and the repository can recover without restarting.
final firebaseReadyProvider =
    StateProvider<bool>((ref) => Firebase.apps.isNotEmpty);
