// Pins SpeechService's waits and its listen life cycle.
//
//   * The speak wait (PIN-15): SpeechService.speak waits for the voice for at most
//     SpeechService.speakWait, and that one named constant is the only place the wait is set.
//   * speakAndWait completes on the voice's completion handler, at SpeechService.speakAndWaitCap
//     when no handler comes, and at once on stopSpeaking.
//   * cancel() completes the pending listenOnce with an empty, unverified result, and the attempt
//     token keeps a cancelled listen from stopping a newer one.
//   * A recogniser error ends the listen at once and reads as a plain sentence, never a raw code.
//
// The service runs on fake engines (SpeechService.withEngines), so no platform channel is used.

import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart';

const _servicePath =
    'lib/components/pages/quiet_room_practice/speech_service.dart';
const _drillPath =
    'lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';

/// A recogniser the test drives by hand.
class FakeStt implements SttEngine {
  bool initialised = true;
  int listens = 0;
  int stops = 0;
  int cancels = 0;
  bool _listening = false;
  void Function(List<String>)? _onFinal;
  void Function(String)? _onError;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({required void Function(String code) onError}) async {
    _onError = onError;
    return initialised;
  }

  @override
  Future<void> listen({
    required Duration listenFor,
    required void Function(List<String> alternates) onFinal,
    required void Function(double raw) onLevel,
  }) async {
    listens++;
    _listening = true;
    _onFinal = onFinal;
  }

  @override
  Future<void> stop() async {
    stops++;
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    _listening = false;
  }

  /// The recogniser's final result, as it arrives from the platform.
  void hear(List<String> alternates) => _onFinal?.call(alternates);

  /// A platform error, as speech_to_text reports it.
  void fail(String code) {
    _listening = false;
    _onError?.call(code);
  }
}

/// A voice that finishes only when the test says so.
class FakeTts implements TtsEngine {
  FakeTts({this.hasJapanese = true});
  final bool hasJapanese;
  final List<String> spoken = [];
  int stops = 0;
  void Function()? _onDone;

  @override
  set onDone(void Function()? f) => _onDone = f;

  @override
  Future<void> configure() async {}

  @override
  Future<List<Map<String, String>>> voices() async => [
        {'name': 'en-us-x', 'locale': 'en-US'},
        if (hasJapanese) {'name': 'ja-jp-x', 'locale': 'ja-JP'},
      ];

  @override
  Future<List<String>> languages() async => const ['en-US'];

  @override
  Future<void> use(Map<String, String> voice) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;

  /// The platform's completion handler.
  void finish() => _onDone?.call();
}

/// Lets the service's awaits run.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('speak wait', () {
    test('is capped at 3 seconds', () {
      expect(SpeechService.speakWait, const Duration(seconds: 3));
    });

    test('speak() times out on the named constant, not a literal', () {
      final src = File(_servicePath).readAsStringSync();
      final speakBody = src.substring(src.indexOf('Future<String?> speak('),
          src.indexOf('Future<List<String>> voices('));
      expect(speakBody, contains('.timeout(speakWait'));
      expect(
          RegExp(r'\.timeout\(\s*const Duration').hasMatch(speakBody), isFalse);
    });

    test('no comment in the service or the drill names the old wait', () {
      final old = RegExp(r'\b(4|four)[- ]?(s|sec|second|seconds)\b',
          caseSensitive: false);
      for (final path in [_servicePath, _drillPath]) {
        final src = File(path).readAsStringSync();
        expect(old.hasMatch(src), isFalse, reason: path);
        expect(src.contains('seconds: 4'), isFalse, reason: path);
      }
    });
  });

  group('speakAndWait', () {
    test('completes on the completion handler, not before', () async {
      final tts = FakeTts();
      final s = SpeechService.withEngines(stt: FakeStt(), tts: tts);
      var done = false;
      final f = s.speakAndWait('ほん').then((e) {
        done = true;
        return e;
      });
      await settle();
      expect(tts.spoken, ['ほん']);
      expect(done, isFalse, reason: 'the voice has not finished');
      tts.finish();
      expect(await f, isNull);
      expect(done, isTrue);
    });

    test('completes at the cap when no handler comes', () {
      fakeAsync((async) {
        final tts = FakeTts();
        final s = SpeechService.withEngines(stt: FakeStt(), tts: tts);
        var done = false;
        s.speakAndWait('ほん').then((_) => done = true);
        async.flushMicrotasks();
        async.elapse(
            SpeechService.speakAndWaitCap - const Duration(milliseconds: 1));
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 2));
        expect(done, isTrue);
      });
    });

    test('completes when the voice is stopped', () async {
      final tts = FakeTts();
      final s = SpeechService.withEngines(stt: FakeStt(), tts: tts);
      var done = false;
      s.speakAndWait('ほん').then((_) => done = true);
      await settle();
      await s.stopSpeaking();
      await settle();
      expect(tts.stops, 1);
      expect(done, isTrue);
    });

    test('says why when there is no Japanese voice', () async {
      final s = SpeechService.withEngines(
          stt: FakeStt(), tts: FakeTts(hasJapanese: false));
      expect(await s.speakAndWait('ほん'), startsWith('No Japanese voice'));
    });
  });

  group('listenOnce', () {
    test('judges the final result and stops the recogniser', () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      final f = s.listenOnce(expectedKana: 'ほん');
      await settle();
      expect(stt.isListening, isTrue);
      stt.hear(['ほん']);
      final r = await f;
      expect(r.judgement, Judgement.correct);
      expect(r.heard, 'ほん');
      expect(stt.stops, 1);
    });

    test('cancel() completes the pending listen at once, empty and unverified',
        () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      var finished = false;
      final f = s.listenOnce(expectedKana: 'ほん').then((r) {
        finished = true;
        return r;
      });
      await settle();
      await s.cancel();
      await settle();
      expect(finished, isTrue,
          reason: 'Stop must not leave the listen in flight');
      final r = await f;
      expect(r.heard, '');
      expect(r.judgement, Judgement.unverified);
      expect(stt.cancels, 1);
    });

    test('a cancelled listen never stops a newer one', () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      final first = s.listenOnce(expectedKana: 'ほん');
      await settle();
      await s.cancel();
      final second = s.listenOnce(expectedKana: 'じしょ');
      await settle();
      expect((await first).judgement, Judgement.unverified);
      expect(stt.stops, 0, reason: 'the late stop belongs to the old attempt');
      expect(stt.isListening, isTrue, reason: 'the newer listen is still open');
      stt.hear(['じしょ']);
      expect((await second).judgement, Judgement.correct);
      expect(stt.stops, 1);
    });

    test('a result after cancel is dropped', () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      final f = s.listenOnce(expectedKana: 'ほん');
      await settle();
      await s.cancel();
      stt.hear(['ほん']);
      expect((await f).judgement, Judgement.unverified);
    });

    test('a recogniser error ends the listen at once with a plain sentence',
        () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      final f = s.listenOnce(expectedKana: 'ほん');
      await settle();
      stt.fail('error_no_match');
      final r = await f.timeout(const Duration(seconds: 1));
      expect(r.judgement, Judgement.unverified);
      expect(s.lastError, isNotNull);
      expect(s.lastError, isNot(contains('error_')));
    });

    test('no microphone permission is unverified, with the reason', () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(
          stt: stt, tts: FakeTts(), micPermission: () async => false);
      final r = await s.listenOnce(expectedKana: 'ほん');
      expect(r.judgement, Judgement.unverified);
      expect(s.lastError, contains('Microphone permission'));
      expect(stt.listens, 0);
    });
  });

  group('describeError', () {
    test('maps every raw code to a sentence without the code', () {
      for (final code in [
        'error_no_match',
        'error_speech_timeout',
        'error_network',
        'error_network_timeout',
        'error_audio',
        'error_server',
        'error_client',
        'error_permission',
        'error_insufficient_permissions',
        'error_busy',
        'error_recognizer_busy',
        'error_language_not_supported',
        'error_language_unavailable',
        'error_too_many_requests',
        'error_server_disconnected',
        'no-speech',
        'not-allowed',
        'network',
        'audio-capture',
        'aborted',
        'error_something_new',
      ]) {
        final s = SpeechService.describeError(code);
        expect(s, isNot(contains(code)), reason: code);
        expect(s, endsWith('.'), reason: code);
      }
    });

    test('names the microphone for a permission code', () {
      expect(SpeechService.describeError('error_permission'),
          contains('Microphone'));
      expect(
          SpeechService.describeError('not-allowed'), contains('Microphone'));
    });
  });
}
