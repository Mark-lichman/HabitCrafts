// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The browser speech probe on the web (plan 2026-11-19, Task 9, PIN-6). speech_to_text's web
// plugin cannot say whether the browser takes Japanese: its `locales()` returns only the
// recognizer's own `lang`, which is empty until set. So this asks the page directly.
//
//   1. No `SpeechRecognition` (or `webkitSpeechRecognition`) global: no recognizer.
//   2. The recognizer's static `available({langs: ['ja-JP']})`, where the browser has it,
//      answers for Japanese. Only `unavailable` rules it out; `downloadable` and the rest
//      still let a listen go ahead.
//   3. A browser without `available()`, or one whose answer fails or never comes, cannot rule
//      Japanese out, so speech works. A recognizer that then refuses `ja_JP` reports
//      `language-not-supported`, and SpeechService downgrades on that error.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'speech_service.dart' show SpeechSupport;

/// The longest the probe waits for the browser's `available()` answer.
const Duration _availableWait = Duration(seconds: 3);

Future<SpeechSupport> browserSpeechSupport(List<String> recognizerNames) async {
  JSObject? recognizer;
  for (final name in recognizerNames) {
    final v = globalContext[name];
    if (!v.isUndefinedOrNull) {
      recognizer = v as JSObject;
      break;
    }
  }
  if (recognizer == null) return SpeechSupport.noRecognizer;
  if (!recognizer.has('available')) return SpeechSupport.works;
  try {
    final options = JSObject()
      ..['langs'] = <JSString>['ja-JP'.toJS].toJS
      ..['processLocally'] = false.toJS;
    final status = await recognizer
        .callMethod<JSPromise<JSString>>('available'.toJS, options)
        .toDart
        .timeout(_availableWait);
    return status.toDart == 'unavailable'
        ? SpeechSupport.noJapanese
        : SpeechSupport.works;
  } catch (_) {
    return SpeechSupport.works;
  }
}
