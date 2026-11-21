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
//
// The say-it cards do not use that probe (operator ruling 2026-11-21). They record the learner
// and Azure scores the audio, so they ask [browserRecordingSupport] instead: the page needs
// `navigator.mediaDevices.getUserMedia` and a `MediaRecorder`. Firefox has both and no
// recognizer, so it keeps spoken say-it cards.

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

/// Whether this page can record the learner: `getUserMedia` on the page global
/// [navigatorName]'s `mediaDevices`, and one of [recorderNames] as a page global.
Future<SpeechSupport> browserRecordingSupport(
    String navigatorName, List<String> recorderNames) async {
  try {
    final nav = globalContext[navigatorName];
    if (nav.isUndefinedOrNull) return SpeechSupport.noRecorder;
    final devices = (nav as JSObject)['mediaDevices'];
    if (devices.isUndefinedOrNull) return SpeechSupport.noRecorder;
    if (!(devices as JSObject).has('getUserMedia')) {
      return SpeechSupport.noRecorder;
    }
    final hasRecorder =
        recorderNames.any((name) => !globalContext[name].isUndefinedOrNull);
    return hasRecorder ? SpeechSupport.works : SpeechSupport.noRecorder;
  } catch (_) {
    // A page that cannot be read cannot rule recording out; a failed recording is unscored.
    return SpeechSupport.works;
  }
}
