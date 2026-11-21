// A fake speech recognizer on the page, for the real browser probe in Chrome (plan 2026-11-19,
// Task 9, PIN-6). speech_support_web.dart reads the recognizer as a page global and calls its
// static `available()`. This puts a global under a name no browser has, so the probe's
// `unavailable` branch runs in any Chrome. The VM build imports fake_recognizer_stub.dart
// instead, because dart:js_interop does not compile there.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Puts a fake recognizer on the page under [name].
///
/// With [answer], its static `available()` resolves to that string. With [reject], the promise
/// rejects. With neither, the recognizer has no `available()` at all.
void installFakeRecognizer(String name, {String? answer, bool reject = false}) {
  final recognizer = JSObject();
  if (answer != null || reject) {
    JSPromise<JSAny?> available(JSAny? options) => reject
        ? Future<JSAny?>.error(StateError('fake refusal')).toJS
        : Future<JSAny?>.value(answer!.toJS).toJS;
    recognizer['available'] = available.toJS;
  }
  globalContext[name] = recognizer;
}

/// Takes the fake recognizer under [name] off the page.
void removeFakeRecognizer(String name) {
  globalContext.delete(name.toJS);
}

/// Puts a fake `navigator` on the page under [name], for the recording probe
/// (operator ruling 2026-11-21). Its `mediaDevices` has `getUserMedia` only when
/// [getUserMedia] is true.
void installFakeNavigator(String name, {required bool getUserMedia}) {
  final devices = JSObject();
  if (getUserMedia) {
    JSAny? open(JSAny? constraints) => null;
    devices['getUserMedia'] = open.toJS;
  }
  globalContext[name] = JSObject()..['mediaDevices'] = devices;
}

/// Takes the fake navigator under [name] off the page.
void removeFakeNavigator(String name) {
  globalContext.delete(name.toJS);
}
