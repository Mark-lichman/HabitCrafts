// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Picks the amplitude source for the platform. Conditional import rather than a `kIsWeb`
// branch because `dart:js_interop` does not exist off the web and would fail to compile.

export 'mic_level_stub.dart' if (dart.library.js_interop) 'mic_level_web.dart';
