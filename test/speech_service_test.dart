// Pins SpeechService's waits and its listen life cycle.
//
//   * The speak wait (PIN-15): SpeechService.speak waits for the voice for at most
//     SpeechService.speakWait, and that one named constant is the only place the wait is set.
//   * speakAndWait completes on the voice's completion handler, at SpeechService.speakAndWaitCap
//     when no handler comes, at once on stopSpeaking, at once when speak() fails, and when a
//     second speakAndWait replaces it. A stopSpeaking still in flight releases only the waiter
//     it was called on, never one that began during its platform stop.
//   * cancel() completes the pending listenOnce with an empty, unverified result, the attempt
//     token keeps a cancelled listen from stopping a newer one, a cancelled listen's late
//     result never completes the newer one, and a cancel while the permission prompt is
//     pending never opens the recogniser.
//   * A cancel that lands while the level tap is starting never opens the recogniser, and a
//     stale listen that finishes while a newer listen is open never zeroes its level. The web
//     tap-stop half of that finally guard (`_pending == null`) has no fixture: MicLevelTap is
//     built inside the service and its non-web stub is a no-op.
//   * A recogniser error ends the listen at once and reads as a plain sentence, never a raw code.
//
// The service runs on fake engines (SpeechService.withEngines), so no platform channel is used.

import 'dart:async';
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

  /// Every listen's final-result callback, oldest first, so a test can deliver an old
  /// listen's result while a newer listen is pending.
  final List<void Function(List<String>)> _onFinals = [];
  void Function(String)? _onError;

  /// Runs at the top of [listen], so a test can read state at the moment the mic opens.
  void Function()? onListen;

  /// The newest listen's level callback, so a test can feed the platform's sound level.
  void Function(double)? onLevel;

  /// When set, [listen] holds after its bookkeeping until the test completes it, as a
  /// platform listen that has not yet returned.
  Completer<void>? listenGate;

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
    onListen?.call();
    listens++;
    _listening = true;
    _onFinals.add(onFinal);
    this.onLevel = onLevel;
    final g = listenGate;
    if (g != null) await g.future;
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

  /// The recogniser's final result for the newest listen, as it arrives from the platform.
  void hear(List<String> alternates) {
    if (_onFinals.isNotEmpty) _onFinals.last(alternates);
  }

  /// The final result of the listen at [index] (0 is the first listen this engine saw),
  /// delivered even when a newer listen has since opened.
  void hearFrom(int index, List<String> alternates) =>
      _onFinals[index](alternates);

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

  /// When set, [speak] fails with it instead of speaking.
  Object? speakError;

  /// When set, [stop] holds until the test completes it, as a platform stop takes time.
  Completer<void>? stopGate;

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
  Future<void> speak(String text) async {
    final e = speakError;
    if (e != null) throw e;
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stops++;
    final gate = stopGate;
    if (gate != null) await gate.future;
  }

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

    test('a stop in flight releases only the waiter it was called on',
        () async {
      final tts = FakeTts();
      final s = SpeechService.withEngines(stt: FakeStt(), tts: tts);
      var firstDone = false;
      var secondDone = false;
      s.speakAndWait('ほん').then((_) => firstDone = true);
      await settle();
      expect(firstDone, isFalse);

      // The platform stop takes time. Not awaited: the lifecycle callers do not await it.
      tts.stopGate = Completer<void>();
      unawaited(s.stopSpeaking());
      await settle();
      expect(tts.stops, 1);
      s.speakAndWait('じしょ').then((_) => secondDone = true);
      await settle();
      expect(firstDone, isTrue, reason: 'the newer utterance replaces it');
      expect(secondDone, isFalse);

      tts.stopGate!.complete();
      await settle();
      expect(secondDone, isFalse,
          reason: 'the stop was called before this utterance began');
      tts.finish();
      await settle();
      expect(secondDone, isTrue);
    });

    test('a stop in flight with no waiter releases nothing', () async {
      final tts = FakeTts();
      final s = SpeechService.withEngines(stt: FakeStt(), tts: tts);
      tts.stopGate = Completer<void>();
      unawaited(s.stopSpeaking());
      await settle();
      expect(tts.stops, 1);
      var done = false;
      s.speakAndWait('ほん').then((_) => done = true);
      await settle();
      expect(done, isFalse);

      tts.stopGate!.complete();
      await settle();
      expect(done, isFalse,
          reason: 'no utterance was playing when the stop began');
      tts.finish();
      await settle();
      expect(done, isTrue);
    });

    test('says why when there is no Japanese voice', () async {
      final s = SpeechService.withEngines(
          stt: FakeStt(), tts: FakeTts(hasJapanese: false));
      expect(await s.speakAndWait('ほん'), startsWith('No Japanese voice'));
    });

    test('completes at once when speak() fails, not at the cap', () {
      fakeAsync((async) {
        final tts = FakeTts()..speakError = StateError('no voice');
        final s = SpeechService.withEngines(stt: FakeStt(), tts: tts);
        var done = false;
        s.speakAndWait('ほん').then((_) => done = true);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));
        expect(done, isTrue,
            reason: 'a failed voice must not hold the drill for the cap');
        expect(async.elapsed, lessThan(SpeechService.speakAndWaitCap));
      });
    });

    test('a second speakAndWait releases the first waiter', () async {
      final tts = FakeTts();
      final s = SpeechService.withEngines(stt: FakeStt(), tts: tts);
      var firstDone = false;
      var secondDone = false;
      s.speakAndWait('ほん').then((_) => firstDone = true);
      await settle();
      expect(firstDone, isFalse);
      s.speakAndWait('じしょ').then((_) => secondDone = true);
      await settle();
      expect(firstDone, isTrue, reason: 'the newer utterance replaces it');
      expect(secondDone, isFalse, reason: 'the newer voice is still playing');
      tts.finish();
      await settle();
      expect(secondDone, isTrue);
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

    test('a cancel during the permission prompt never opens the recogniser',
        () async {
      final gate = Completer<bool>();
      final stt = FakeStt();
      final s = SpeechService.withEngines(
          stt: stt, tts: FakeTts(), micPermission: () => gate.future);
      final f = s.listenOnce(expectedKana: 'ほん');
      await settle();
      await s.cancel();
      gate.complete(true);
      final r = await f.timeout(const Duration(seconds: 1));
      expect(r.judgement, Judgement.unverified);
      expect(r.heard, '');
      expect(stt.listens, 0);
    });

    test('a cancel during the permission prompt leaves a newer listen free',
        () async {
      final gate = Completer<bool>();
      final stt = FakeStt();
      final s = SpeechService.withEngines(
          stt: stt, tts: FakeTts(), micPermission: () => gate.future);
      final first = s.listenOnce(expectedKana: 'ほん');
      await settle();
      await s.cancel();
      final second = s.listenOnce(expectedKana: 'じしょ');
      await settle();
      gate.complete(true);
      final r = await first.timeout(const Duration(seconds: 1));
      expect(r.judgement, Judgement.unverified);
      await settle();
      expect(stt.listens, 1, reason: 'only the newer listen opens the mic');
      expect(stt.isListening, isTrue);
      stt.hear(['じしょ']);
      expect((await second).judgement, Judgement.correct);
      expect(stt.stops, 1);
    });

    test('a cancel while the level tap starts never opens the recogniser',
        () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      final first = s.listenOnce(expectedKana: 'ほん');
      await settle();
      stt.hear(['ほん']);
      await first;
      // A nonzero level, so the reset at the top of the next listen is a change the
      // listener sees. listenOnce zeroes the level after it takes the pending slot and
      // before the tap starts, so a cancel from that notification lands in the window
      // between the tap start and the listen.
      stt.onLevel!(5);
      expect(s.level.value, greaterThan(0));
      s.level.addListener(() {
        if (s.level.value == 0) unawaited(s.cancel());
      });
      final second = s.listenOnce(expectedKana: 'じしょ');
      final r = await second.timeout(const Duration(seconds: 1));
      expect(r.judgement, Judgement.unverified);
      expect(stt.listens, 1,
          reason: 'the cancelled listen never opens the mic');
    });

    test('a stale listen that finishes never zeroes a newer listen’s level',
        () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      stt.listenGate = Completer<void>();
      final gate = stt.listenGate!;
      final first = s.listenOnce(expectedKana: 'ほん');
      await settle(); // held inside _stt.listen
      await s.cancel();
      stt.listenGate = null;
      final second = s.listenOnce(expectedKana: 'じしょ');
      await settle();
      stt.onLevel!(5);
      expect(s.level.value, greaterThan(0));

      // The platform returns the first listen, so its finally runs while the newer listen
      // owns the level.
      gate.complete();
      await settle();
      expect((await first).judgement, Judgement.unverified);
      expect(s.level.value, greaterThan(0),
          reason: 'the stale listen must leave the newer level alone');
      stt.hear(['じしょ']);
      expect((await second).judgement, Judgement.correct);
      expect(s.level.value, 0,
          reason: 'the listen that owns the level resets it');
    });

    test('an old listen’s late result never completes a newer listen',
        () async {
      final stt = FakeStt();
      final s = SpeechService.withEngines(stt: stt, tts: FakeTts());
      final first = s.listenOnce(expectedKana: 'ほん');
      await settle();
      await s.cancel();
      expect((await first).judgement, Judgement.unverified);
      var secondDone = false;
      final second = s.listenOnce(expectedKana: 'じしょ').then((r) {
        secondDone = true;
        return r;
      });
      await settle();
      expect(stt.listens, 2);

      // The platform delivers the first listen's result after the second opened.
      stt.hearFrom(0, ['ほん']);
      await settle();
      expect(secondDone, isFalse,
          reason: 'a stale result belongs to the cancelled listen');

      stt.hear(['じしょ']);
      final r = await second;
      expect(r.judgement, Judgement.correct);
      expect(r.heard, 'じしょ');
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
