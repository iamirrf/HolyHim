import 'package:firebase_core/firebase_core.dart';

abstract final class HolyHerFirebaseOptions {
  static const googleClientId =
      "746503857955-nvkgi8skvodb06dejass0e0rj18ef45u.apps.googleusercontent.com";
  static const ios = FirebaseOptions(
    apiKey: "AIzaSyAKPKDXXcpH6jCRMwsIUO3XFMtZBdpUNQo",
    appId: "1:746503857955:ios:6ed10c73853d13b39f8e96",
    messagingSenderId: "746503857955",
    projectId: "holyher-app-production",
    storageBucket: "holyher-app-production.firebasestorage.app",
    iosBundleId: "com.holyher.app",
  );
  static const web = FirebaseOptions(
    apiKey: "AIzaSyDPv9e6_jZ-x_TWXRS6yNy-P-qJS_uKqZ8",
    appId: "1:746503857955:web:b0c6ecf2df60ab209f8e96",
    messagingSenderId: "746503857955",
    projectId: "holyher-app-production",
    storageBucket: "holyher-app-production.firebasestorage.app",
    authDomain: "holyher-app-production.web.app",
  );
}
