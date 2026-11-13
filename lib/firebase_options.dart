import 'package:firebase_core/firebase_core.dart';

abstract final class HolyHimFirebaseOptions {
  static const googleClientId =
      "REPLACE_WITH_HOLYHIM_GOOGLE_CLIENT_ID";
  static const ios = FirebaseOptions(
    apiKey: "REPLACE_WITH_HOLYHIM_FIREBASE_API_KEY",
    appId: "1:000000000000:ios:REPLACE_WITH_HOLYHIM_IOS_APP_ID",
    messagingSenderId: "000000000000",
    projectId: "holyhim-app-production",
    storageBucket: "holyhim-app-production.firebasestorage.app",
    iosBundleId: "com.holyhim.app",
  );
  static const web = FirebaseOptions(
    apiKey: "REPLACE_WITH_HOLYHIM_FIREBASE_API_KEY",
    appId: "1:000000000000:web:REPLACE_WITH_HOLYHIM_WEB_APP_ID",
    messagingSenderId: "000000000000",
    projectId: "holyhim-app-production",
    storageBucket: "holyhim-app-production.firebasestorage.app",
    authDomain: "holyhim-app-production.web.app",
  );
}
