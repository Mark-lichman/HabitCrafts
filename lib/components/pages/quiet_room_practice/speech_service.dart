// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Speaking and listening for the Japanese drills. Wraps flutter_tts and speech_to_text so the
// drill screen holds none of the platform handling.
//
// 🚨 WHAT THIS CAN AND CANNOT DO. speech_to_text returns a TRANSCRIPT. A correct transcript means
// the learner produced something the recogniser could match to the right word -- it does NOT mean
// they pronounced it well. The recogniser will happily normalise a poor pronunciation into the
// correct word. So this supports SPOKEN RECALL, not pronunciation assessment, and the UI must not
// claim otherwise. Phoneme-level scoring needs a paid service (Azure Pronunciation Assessment,
// Speechace); see docs/japanese-lessons.md.
//
// That gap matters more in Japanese than most languages because VOWEL LENGTH IS PHONEMIC:
// おばさん / おばあさん and ここ / こうこう are different words, and the recogniser's language model
// will quietly pick the likelier one, hiding the error the learner most needs to see.
//
// 🚨 SECOND PROBLEM, handled in `judge()`: Android ASR returns kanji (貼ります) while the expected
// answer is hiragana (はります). There is no reading dictionary bundled, so the caller passes the
// answer's own kanji spellings as `kanjiForms`: EDICT2 spellings for a vocabulary word, and the
// sentence's kanji version (its `_ruby` twin with the readings dropped) in the grammar speaking
// drill. A transcript that equals one of them is correct, and one that overlaps it is close.
// A kanji transcript that matches no kanji form still CANNOT be compared to the hiragana. Rather
// than call that wrong -- which would punish a correct answer -- `judge()` returns `unverified`
// and the UI shows what was heard so the learner decides. Being unable to check is not the same
// as being wrong, and conflating them teaches nothing.
//
// 🚨 ONE LISTEN AT A TIME, AND A STOP IS AN ANSWER. `cancel()` completes the pending
// `listenOnce` future at once with an empty, unverified result, so a Stop never leaves a listen
// in flight that lands later as a miss. Every listen takes an attempt token: a listen whose token
// is no longer current neither stops the recogniser nor closes the level tap, because both now
// belong to a newer attempt.

import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueNotifier, kIsWeb, visibleForTesting;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'mic_level.dart';

enum Judgement { correct, close, wrong, unverified }

class SpeechResult {
  const SpeechResult(this.heard, this.judgement);
  final String heard;
  final Judgement judgement;
}

/// The recogniser as [SpeechService] uses it. The default wraps speech_to_text; tests pass a
/// fake, so the listen, Stop and error paths run without a platform channel.
abstract class SttEngine {
  /// Starts the recogniser. [onError] receives the platform's raw error code.
  Future<bool> initialize({required void Function(String code) onError});

  /// Listens once. [onFinal] receives every hypothesis of the final result.
  Future<void> listen({
    required Duration listenFor,
    required void Function(List<String> alternates) onFinal,
    required void Function(double raw) onLevel,
  });
  Future<void> stop();
  Future<void> cancel();
  bool get isListening;
}

/// The voice as [SpeechService] uses it. The default wraps flutter_tts.
abstract class TtsEngine {
  /// Rate, volume and pitch. Called once, before the first speak.
  Future<void> configure();

  /// Every installed voice, as flutter_tts reports them (name and locale).
  Future<List<Map<String, String>>> voices();
  Future<List<String>> languages();
  Future<void> use(Map<String, String> voice);
  Future<void> speak(String text);
  Future<void> stop();

  /// Called when an utterance finishes, is cancelled or fails.
  set onDone(void Function()? f);
}

class _PluginStt implements SttEngine {
  final stt.SpeechToText _stt = stt.SpeechToText();

  @override
  Future<bool> initialize({required void Function(String code) onError}) =>
      _stt.initialize(
        onError: (e) => onError(e.errorMsg),
        onStatus: (_) {},
        debugLogging: false,
      );

  @override
  Future<void> listen({
    required Duration listenFor,
    required void Function(List<String> alternates) onFinal,
    required void Function(double raw) onLevel,
  }) =>
      _stt.listen(
        onSoundLevelChange: onLevel,
        onResult: (r) {
          // Keep EVERY hypothesis, not just the top one. The recogniser often ranks a kanji
          // spelling first and a kana spelling second; the kana one is the surest hypothesis
          // to compare, but a kanji one that equals a kanji form also judges correct.
          if (r.finalResult) {
            onFinal(r.alternates.map((a) => a.recognizedWords).toList());
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'ja_JP',
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          cancelOnError: true,
        ),
      );

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();

  @override
  bool get isListening => _stt.isListening;
}

class _PluginTts implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  void Function()? _onDone;

  @override
  set onDone(void Function()? f) => _onDone = f;

  @override
  Future<void> configure() async {
    _tts
      ..setCompletionHandler(() => _onDone?.call())
      ..setCancelHandler(() => _onDone?.call())
      ..setErrorHandler((_) => _onDone?.call());
    await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.42); // the web rate scale differs
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Not on web: the web implementation does not resolve the completion handler
    // reliably there, so awaiting speak() can hang and the button looks dead.
    if (!kIsWeb) await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<List<Map<String, String>>> voices() async {
    final raw = await _tts.getVoices;
    return (raw is List ? raw : const [])
        .map((v) => Map<String, String>.from(
            (v as Map).map((k, val) => MapEntry('$k', '$val'))))
        .toList();
  }

  @override
  Future<List<String>> languages() async {
    final l = await _tts.getLanguages;
    return l is List ? l.map((e) => e.toString()).toList() : const [];
  }

  @override
  Future<void> use(Map<String, String> voice) async {
    await _tts.setVoice(voice);
    await _tts.setLanguage(voice['locale'] ?? 'ja-JP');
  }

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}

/// The runtime microphone permission. On web the browser owns the prompt (see
/// [SpeechService.prepareMic]).
Future<bool> _pluginMicPermission() async {
  if (kIsWeb) return true;
  final status = await Permission.microphone.request();
  return status.isGranted;
}

class SpeechService {
  SpeechService._()
      : _sttSeam = null,
        _ttsSeam = null,
        _micPermission = _pluginMicPermission;
  static final SpeechService instance = SpeechService._();

  /// A service on fake engines, for tests.
  @visibleForTesting
  SpeechService.withEngines({
    required SttEngine stt,
    required TtsEngine tts,
    Future<bool> Function()? micPermission,
  })  : _sttSeam = stt,
        _ttsSeam = tts,
        _micPermission = micPermission ?? (() async => true);

  final SttEngine? _sttSeam;
  final TtsEngine? _ttsSeam;
  final Future<bool> Function() _micPermission;

  // Built on first use, so a test service never touches a platform channel.
  late final TtsEngine _tts = _ttsSeam ?? _PluginTts();
  late final SttEngine _stt = _sttSeam ?? _PluginStt();

  /// The longest [speak] waits for the voice to finish before it returns (PIN-15). A longer
  /// sentence keeps playing after this; the drill's Play guard releases at the cap.
  static const Duration speakWait = Duration(seconds: 3);

  /// The longest [speakAndWait] waits for the voice's completion handler. It is a safety cap
  /// for a platform that never calls the handler (the web), set above the longest lesson
  /// sentence at the app's speech rate.
  static const Duration speakAndWaitCap = Duration(seconds: 15);

  bool _ttsReady = false;
  bool _sttReady = false;

  /// Live microphone amplitude, 0..1, for the listening indicator.
  ///
  /// Two sources feed this, because no single one covers every platform:
  ///
  ///   * Android and iOS: `speech_to_text`'s `onSoundLevelChange`.
  ///   * Web: [MicLevelTap], our own Web Audio reading. 🚨 speech_to_text's web
  ///     implementation NEVER emits `onSoundLevelChange` -- the Web Speech API has no such
  ///     callback -- so without the tap this stays flat in Chrome.
  ///
  /// 🚨 WHERE NEITHER SOURCE WORKS THIS STAYS AT 0, and the UI must then show a still
  /// "Listening" state rather than a moving one. An indicator that animates while nothing is
  /// being measured claims to hear the person when it cannot.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  /// The recogniser's last complaint as a plain sentence (see [describeError]), or null. Read
  /// by the drill so a failure says something instead of looking like a slow answer.
  String? lastError;

  final MicLevelTap _levelTap = MicLevelTap();

  /// Platforms report sound level on different scales (dB-ish, ranges vary by device),
  /// so normalise against a decaying observed maximum rather than a hardcoded ceiling.
  double _levelMax = 1;

  void _onLevel(double raw) {
    final v = raw.abs();
    _levelMax = (_levelMax * 0.995).clamp(1.0, double.infinity);
    if (v > _levelMax) _levelMax = v;
    level.value = (v / _levelMax).clamp(0.0, 1.0);
  }

  /// True only once the recogniser has actually initialised. The drill uses this to decide
  /// whether to offer the microphone at all, rather than offering a button that fails.
  bool get canListen => _sttReady;
  bool get isListening => _stt.isListening;

  /// 🚨 BIND AN ACTUAL VOICE, not just a language.
  ///
  /// flutter_tts's web `_setLanguage` reads `synth.getVoices()` and only assigns
  /// `utterance.voice` if that list is ALREADY populated. At init it is not -- browsers
  /// fill it asynchronously -- so the utterance keeps the default English voice, Chrome
  /// is handed kana to read with Microsoft David, and the result is SILENCE with no
  /// error raised. The platform was never the problem; the voice was never bound.
  Map<String, String>? _jaVoice;

  Future<Map<String, String>?> _findJapaneseVoice() async {
    if (_jaVoice != null) return _jaVoice;
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final list = await _tts.voices();
        if (list.isNotEmpty) {
          for (final v in list) {
            if ((v['locale'] ?? '').toLowerCase().startsWith('ja')) {
              return _jaVoice = v;
            }
          }
          return null; // loaded, and genuinely no Japanese voice
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  Future<void> _initTts() async {
    if (_ttsReady) return;
    _tts.onDone = _speechDone;
    await _tts.configure();
    _ttsReady = true;
  }

  /// Binds the Japanese voice. Returns null when it is bound, or a message saying why not.
  Future<String?> _bindVoice() async {
    await _initTts();
    final v = await _findJapaneseVoice();
    if (v == null) {
      final langs = await voices();
      return langs.isEmpty
          ? 'No speech voices are available yet. Try again in a moment.'
          : 'No Japanese voice found. Available: ${langs.take(6).join(', ')}';
    }
    await _tts.use(v);
    return null;
  }

  /// Speaks Japanese text. Returns null on success, or a message explaining why not.
  Future<String?> speak(String text) async {
    try {
      final err = await _bindVoice();
      if (err != null) return err;
      // 🚨 Do NOT stop() first. `_stop()` calls synth.cancel(), whose state change
      // arrives on a later event, and `_speak` refuses to run unless the state is
      // already stopped -- so a stop immediately before a speak silently eats it.
      await _tts.speak(text).timeout(speakWait, onTimeout: () {});
      return null;
    } catch (e) {
      return _speechFailed(e);
    }
  }

  /// The platform's language list, for diagnostics. May be empty on a first web call.
  Future<List<String>> voices() async {
    try {
      return await _tts.languages();
    } catch (_) {
      return const [];
    }
  }

  /// The utterance [speakAndWait] is waiting on, or null.
  Completer<void>? _speaking;

  void _speechDone() {
    final s = _speaking;
    _speaking = null;
    if (s != null && !s.isCompleted) s.complete();
  }

  /// Speaks Japanese text and completes when the voice says it has finished: the completion
  /// handler, a cancel or an error, or [stopSpeaking]. [speakAndWaitCap] bounds the wait for a
  /// platform that never calls the handler. Returns null on success, or a message saying why
  /// not. A caller that opens the microphone after this never records the app's own voice.
  Future<String?> speakAndWait(String text) async {
    try {
      final err = await _bindVoice();
      if (err != null) return err;
      _speechDone(); // a voice still awaited is over: this utterance replaces it
      final done = _speaking = Completer<void>();
      // Not awaited: off the web speak() itself waits for the voice, on the web it returns
      // at once. The handler is the one signal both share.
      unawaited(_tts.speak(text).then((_) {}, onError: (Object _) {
        if (identical(_speaking, done)) _speechDone();
      }));
      await done.future.timeout(speakAndWaitCap, onTimeout: () {
        if (identical(_speaking, done)) _speaking = null;
      });
      return null;
    } catch (e) {
      return _speechFailed(e);
    }
  }

  static String _speechFailed(Object e) {
    final msg = e.toString();
    return 'Speech failed: ${msg.length > 140 ? msg.substring(0, 140) : msg}';
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speechDone();
  }

  /// Asks for the microphone and initialises the recogniser. RECORD_AUDIO is already declared in
  /// the manifest and NSMicrophoneUsageDescription in Info.plist; this is the runtime half.
  ///
  /// 🚨 On web, permission_handler is NOT the right gate and asking it here would block us: the
  /// browser owns the microphone prompt and raises it from `getUserMedia` when the recogniser
  /// starts. Skipping straight to initialise is what lets Chrome ask properly.
  /// 🚨 Permission is re-checked every time, not cached. Revoking the microphone in Settings
  /// while the app is backgrounded used to leave `_sttReady` true, so this reported success
  /// and the drill then sat through its whole timeout for an answer that could never arrive.
  Future<bool> prepareMic() async {
    if (!await _micPermission()) {
      lastError = 'Microphone permission is off for HabitCrafts.';
      return false;
    }
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(onError: _onSttError);
    if (!_sttReady) {
      lastError ??= 'Speech recognition is unavailable on this device.';
    }
    return _sttReady;
  }

  /// The pending listen's hypotheses, or null when no listen is waiting.
  Completer<List<String>>? _pending;

  /// Bumped by every [listenOnce] and [cancel]. A listen whose token is stale is over.
  int _listenToken = 0;

  void _finishListen(List<String> heard) {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.complete(heard);
  }

  /// With `cancelOnError` the recogniser has stopped, so the listen ends now with nothing
  /// heard rather than waiting out its timeout.
  void _onSttError(String code) {
    lastError = describeError(code);
    _finishListen(const []);
  }

  /// Listens once and judges against [expectedKana]. Always reports what was heard. A [cancel]
  /// while it listens ends it at once with an empty, unverified result.
  Future<SpeechResult> listenOnce({
    required String expectedKana,
    List<String> kanjiForms = const [],
    Duration limit = const Duration(seconds: 6),
  }) async {
    const nothing = SpeechResult('', Judgement.unverified);
    final token = ++_listenToken;
    _finishListen(const []); // an older listen still waiting is over
    lastError = null;
    if (!await prepareMic()) return nothing;
    // Cancelled during the permission prompt.
    if (token != _listenToken) return nothing;

    final done = _pending = Completer<List<String>>();
    level.value = 0;

    final List<String> heard;
    try {
      // Off the web this returns false immediately and the recogniser's own callback is the
      // only source. Failure is not worth surfacing: the indicator just stays still.
      await _levelTap.start(_onLevel);
      if (token == _listenToken) {
        await _stt.listen(
          listenFor: limit,
          onLevel: _onLevel,
          onFinal: (alternates) {
            if (identical(_pending, done)) _finishListen(alternates);
          },
        );
      }
      heard = await done.future.timeout(limit + const Duration(seconds: 2),
          onTimeout: () => const <String>[]);
      // 🚨 The attempt token: after a cancel the recogniser may already belong to a newer
      // listen, and stopping it here would end that one instead.
      if (token == _listenToken) await _stt.stop();
    } finally {
      if (identical(_pending, done)) _pending = null;
      // 🚨 In a finally because the tap holds a live getUserMedia track. If `listen` throws,
      // an early return would leave it polling and the browser's recording light on with no
      // control left to switch it off. A stale listen leaves it alone: [cancel] already
      // closed this listen's tap, and a newer listen owns the current one.
      if (token == _listenToken) {
        await _levelTap.stop();
        level.value = 0;
      }
    }

    if (token != _listenToken || heard.isEmpty) return nothing;

    // Best verdict across all hypotheses: a correct kana alternate should win even when
    // the top hypothesis came back as kanji.
    var best = Judgement.unverified;
    const rank = {
      Judgement.correct: 3,
      Judgement.close: 2,
      Judgement.unverified: 1,
      Judgement.wrong: 0,
    };
    for (final h in heard) {
      final j = judge(h, expectedKana, kanjiForms: kanjiForms);
      if (rank[j]! > rank[best]!) best = j;
    }
    return SpeechResult(heard.first, best);
  }

  /// Ends the current listen. Its pending [listenOnce] completes at once with an empty,
  /// unverified result, and its attempt token goes stale.
  Future<void> cancel() async {
    _listenToken++;
    _finishListen(const []);
    try {
      await _stt.cancel();
    } catch (_) {}
    // 🚨 Must also release our own stream. The Web Audio tap holds a getUserMedia track,
    // and leaving it open keeps the browser's recording indicator lit after Stop.
    await _levelTap.stop();
    level.value = 0;
  }

  /// The recogniser's raw error code (`error_no_match`, `no-speech`, ...) as a plain sentence.
  /// A code nobody listed still gets a sentence, never the code itself.
  static String describeError(String code) {
    switch (code.trim().toLowerCase()) {
      case 'error_permission':
      case 'error_insufficient_permissions':
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Microphone permission is off for HabitCrafts.';
      case 'error_no_match':
      case 'error_speech_timeout':
      case 'no-speech':
        return 'No speech was recognised. Try again a little closer to the microphone.';
      case 'error_network':
      case 'error_network_timeout':
      case 'network':
        return 'Speech recognition needs the internet and could not reach it.';
      case 'error_server':
      case 'error_server_disconnected':
      case 'error_too_many_requests':
        return 'The speech recogniser did not answer. Try again in a moment.';
      case 'error_audio':
      case 'audio-capture':
        return 'The microphone could not be opened.';
      case 'error_busy':
      case 'error_recognizer_busy':
        return 'The speech recogniser is busy. Try again in a moment.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
      case 'language-not-supported':
        return 'Japanese speech recognition is not installed on this device.';
      case 'error_client':
      case 'aborted':
        return 'Listening stopped before an answer came back.';
      default:
        return 'Speech recognition stopped with a problem. Try again.';
    }
  }

  // --- judging -------------------------------------------------------------

  static final RegExp _kanji = RegExp(r'[一-鿿]');
  static final RegExp _noise = RegExp(r'[\s、。・「」！？,.!?]');

  /// Katakana to hiragana, punctuation and spacing removed, long marks folded. Enough to compare
  /// two kana spellings of the same word; NOT a reading conversion.
  static String normalise(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x30A1 && r <= 0x30F6) {
        b.writeCharCode(r - 0x60); // katakana -> hiragana
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString().replaceAll(_noise, '').replaceAll('ー', '');
  }

  /// 🚨 Returns `unverified`, never `wrong`, when the transcript contains kanji and matches none
  /// of [kanjiForms]. See the header: without a reading dictionary such a transcript cannot be
  /// compared to kana, and marking an unknowable answer wrong is worse than admitting we cannot
  /// tell. `wrong` comes back only for a transcript with no kanji, so a caller that must never
  /// mark a correct answer wrong also checks that the transcript is plain kana (digits and Latin
  /// letters reach `wrong` too).
  static Judgement judge(
    String heard,
    String expectedKana, {
    List<String> kanjiForms = const [],
  }) {
    if (heard.trim().isEmpty) return Judgement.unverified;

    // 🚨 THE KANJI ANSWER. Most Japanese nouns are written in pure kanji with no
    // okurigana (鞄, 山, 花瓶, 美術館), so the recogniser returns a form the hiragana
    // answer cannot be compared with -- and the subsequence bridge below, which relies on
    // okurigana, cannot help. Readings from EDICT2 close that gap: the word's own kanji
    // spellings ship alongside its kana, so a kanji transcript is now an exact lookup
    // rather than a guess. A grammar sentence passes its kanji version the same way.
    // Words with no kanji form (katakana loanwords) simply carry an
    // empty list and fall through to the kana paths.
    //
    // Both sides go through normalise() first, so a sentence's spaces and 。 (the grammar
    // kanji versions carry both, the recogniser returns neither) do not turn an exact
    // match into a partial one.
    final heardForm = normalise(heard);
    for (final raw in kanjiForms) {
      final k = normalise(raw);
      if (k.isEmpty || heardForm.isEmpty) continue;
      if (heardForm == k) return Judgement.correct;
      if (heardForm.contains(k) || k.contains(heardForm)) {
        return Judgement.close;
      }
    }

    final h = normalise(heard);
    final e = normalise(expectedKana);
    if (h.isEmpty || e.isEmpty) return Judgement.unverified;
    if (h == e) return Judgement.correct;
    if (h.contains(e) || e.contains(h)) return Judgement.close;

    // KANA-SUBSEQUENCE BRIDGE. A kanji transcript still carries its okurigana, and
    // those kana appear IN ORDER within the expected reading:
    //     引き出し -> き, し     inside ひきだし  (ひ[き]だ[し])
    //     決めます -> めます     inside きめます
    // So: the heard kana must be an in-order subsequence of the expected kana, and the
    // kanji must plausibly account for the gap (1 to 4 kana each).
    //
    // 🚨 Requires at least one kana. A pure-kanji transcript (美術館, 山) carries no
    // evidence at all -- 山 against あさ is "1 kanji, 2 kana", which is just as
    // plausible as the right answer. Those stay unverified for the person to mark,
    // because a rule that accepts them would accept anything of the right length.
    if (_kanji.hasMatch(heard)) {
      final heardKana = h.replaceAll(_kanji, '');
      if (heardKana.isNotEmpty && _isSubsequence(heardKana, e)) {
        final missing = e.length - heardKana.length;
        final kanjiCount = heard.length - heard.replaceAll(_kanji, '').length;
        if (missing >= kanjiCount && missing <= kanjiCount * 4) {
          return Judgement.close;
        }
      }
      return Judgement.unverified;
    }

    return _similar(h, e) >= 0.7 ? Judgement.close : Judgement.wrong;
  }

  /// Are all of [needle]'s characters present in [hay], in order?
  static bool _isSubsequence(String needle, String hay) {
    var i = 0;
    for (var j = 0; j < hay.length && i < needle.length; j++) {
      if (needle[i] == hay[j]) i++;
    }
    return i == needle.length;
  }

  static double _similar(String a, String b) {
    if (a == b) return 1;
    final d = _levenshtein(a, b);
    final n = a.length > b.length ? a.length : b.length;
    return n == 0 ? 1 : 1 - d / n;
  }

  static int _levenshtein(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var m = prev[j] + 1;
        if (cur[j - 1] + 1 < m) m = cur[j - 1] + 1;
        if (prev[j - 1] + cost < m) m = prev[j - 1] + cost;
        cur[j] = m;
      }
      prev = cur;
    }
    return prev[b.length];
  }
}
