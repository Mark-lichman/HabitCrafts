import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBN3usT-YwAYqQ7tzVz6KsmfHdO-0Se0NA",
            authDomain: "tiny-habits-jf61nl.firebaseapp.com",
            projectId: "tiny-habits-jf61nl",
            storageBucket: "tiny-habits-jf61nl.firebasestorage.app",
            messagingSenderId: "68894759253",
            appId: "1:68894759253:web:8ac60bbb0abb52694bf7dc"));
  } else {
    await Firebase.initializeApp();
  }
}
