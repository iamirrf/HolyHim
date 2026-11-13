import 'package:firebase_core/firebase_core.dart';

abstract final class HolyHimFirebaseOptions {
  static const googleClientId =
      "000000000000-REPLACE_WITH_HOLYHIM.apps.googleusercontent.com";
  static const ios = FirebaseOptions(
    apiKey: "REPLACE_WITH_HOLYHIM_FIREBASE_API_KEY",
    appId: "1:000000000000:ios:REPLACE_WITH_HOLYHIM_IOS_APP_ID",
    messagingSenderId: "000000000000",
    projectId: "holyhim-app-production",
    storageBucket: "holyhim-app-production.firebasestorage.app",
    iosBundleId: "com.holyhim.app",
  );
  static const web = FirebaseOptions(
    apiKey: "REPLACE_WITH_HOLYHIM_KEY",
    appId: "REPLACE_WITH_HOLYHIM_APP_ID",
    messagingSenderId: "000000000000",
    projectId: "holyhim-app-production",
    storageBucket: "holyhim-app-production.firebasestorage.app",
    authDomain: "holyhim-app-production.web.app",
  );
}
