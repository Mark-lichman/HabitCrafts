// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The browser speech probe off the web (plan 2026-11-19, Task 9, PIN-6). The phone and the
// VM have no browser to ask, and their recognizer path is unchanged, so speech works. The web
// build imports speech_support_web.dart instead (see speech_service.dart).

import 'speech_service.dart' show SpeechSupport;

Future<SpeechSupport> browserSpeechSupport(
        List<String> recognizerNames) async =>
    SpeechSupport.works;
