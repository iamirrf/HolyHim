import 'package:firebase_core/firebase_core.dart';

// Public Firebase app identity for HolyHim (not a server credential).
// Written from ios/Runner/GoogleService-Info.plist and config/firebase-web.json.
abstract final class HolyHimFirebaseOptions {
  static const googleClientId =
      "924772723375-pnm726i3n90t2ld2atueqtqrdf99nnv3.apps.googleusercontent.com";
  static const ios = FirebaseOptions(
    apiKey: "AIzaSyBI8m85-QubbbHNikonWCuPtLc12pJmHOQ",
    appId: "1:924772723375:ios:e77948fc5cf114955d425a",
    messagingSenderId: "924772723375",
    projectId: "holyhim-app-production",
    storageBucket: "holyhim-app-production.firebasestorage.app",
    iosBundleId: "com.holyhim.app",
    iosClientId: "924772723375-pnm726i3n90t2ld2atueqtqrdf99nnv3.apps.googleusercontent.com",
  );
  static const web = FirebaseOptions(
    apiKey: "AIzaSyAIBe1UIEMC0pB1Hn_eYjpGZN1EQjg7wM4",
    appId: "1:924772723375:web:ac02534a895e83d85d425a",
    messagingSenderId: "924772723375",
    projectId: "holyhim-app-production",
    storageBucket: "holyhim-app-production.firebasestorage.app",
    authDomain: "holyhim-app-production.web.app",
  );
}
