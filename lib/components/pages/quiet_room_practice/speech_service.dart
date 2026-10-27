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

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
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

class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  /// The longest [speak] waits for the voice to finish before it returns (PIN-15). A longer
  /// sentence keeps playing after this; the drill's Play guard releases at the cap.
  static const Duration speakWait = Duration(seconds: 3);

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

  /// The recogniser's last complaint, or null. Read by the drill so a failure says something
  /// instead of looking like a slow answer.
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
        final raw = await _tts.getVoices;
        final list = (raw is List ? raw : const [])
            .map((v) => Map<String, String>.from(
                (v as Map).map((k, val) => MapEntry('$k', '$val'))))
            .toList();
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
    await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.42); // the web rate scale differs
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Not on web: the web implementation does not resolve the completion handler
    // reliably there, so awaiting speak() can hang and the button looks dead.
    if (!kIsWeb) await _tts.awaitSpeakCompletion(true);
    _ttsReady = true;
  }

  /// Speaks Japanese text. Returns null on success, or a message explaining why not.
  Future<String?> speak(String text) async {
    try {
      await _initTts();
      final v = await _findJapaneseVoice();
      if (v == null) {
        final langs = await voices();
        return langs.isEmpty
            ? 'No speech voices are available yet. Try again in a moment.'
            : 'No Japanese voice found. Available: ${langs.take(6).join(', ')}';
      }
      await _tts.setVoice(v);
      await _tts.setLanguage(v['locale'] ?? 'ja-JP');
      // 🚨 Do NOT stop() first. `_stop()` calls synth.cancel(), whose state change
      // arrives on a later event, and `_speak` refuses to run unless the state is
      // already stopped -- so a stop immediately before a speak silently eats it.
      await _tts.speak(text).timeout(speakWait, onTimeout: () => 1);
      return null;
    } catch (e) {
      final msg = e.toString();
      return 'Speech failed: ${msg.length > 140 ? msg.substring(0, 140) : msg}';
    }
  }

  /// The platform's language list, for diagnostics. May be empty on a first web call.
  Future<List<String>> voices() async {
    try {
      final l = await _tts.getLanguages;
      return l is List ? l.map((e) => e.toString()).toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
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
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        lastError = 'Microphone permission is off for HabitCrafts.';
        return false;
      }
    }
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(
      onError: (e) => lastError = e.errorMsg,
      onStatus: (_) {},
      debugLogging: false,
    );
    if (!_sttReady) {
      lastError ??= 'Speech recognition is unavailable on this device.';
    }
    return _sttReady;
  }

  /// Listens once and judges against [expectedKana]. Always reports what was heard.
  Future<SpeechResult> listenOnce({
    required String expectedKana,
    List<String> kanjiForms = const [],
    Duration limit = const Duration(seconds: 6),
  }) async {
    if (!await prepareMic()) {
      return const SpeechResult('', Judgement.unverified);
    }
    final done = Completer<List<String>>();
    level.value = 0;
    lastError = null;

    final List<String> heard;
    try {
      // Off the web this returns false immediately and the recogniser's own callback is the
      // only source. Failure is not worth surfacing: the indicator just stays still.
      await _levelTap.start(_onLevel);
      await _stt.listen(
        onSoundLevelChange: _onLevel,
        onResult: (r) {
          if (r.finalResult && !done.isCompleted) {
            // Keep EVERY hypothesis, not just the top one. The recogniser often ranks a
            // kanji spelling first and a kana spelling second; the kana one is the surest
            // hypothesis to compare, but a kanji one that equals a kanji form also judges
            // correct.
            done.complete(r.alternates.map((a) => a.recognizedWords).toList());
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'ja_JP',
          listenFor: limit,
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          cancelOnError: true,
        ),
      );
      heard = await done.future.timeout(limit + const Duration(seconds: 2),
          onTimeout: () => const <String>[]);
      await _stt.stop();
    } finally {
      // 🚨 In a finally because the tap holds a live getUserMedia track. If `listen` throws,
      // an early return would leave it polling and the browser's recording light on with no
      // control left to switch it off.
      await _levelTap.stop();
      level.value = 0;
    }

    if (heard.isEmpty) return const SpeechResult('', Judgement.unverified);

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

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    // 🚨 Must also release our own stream. The Web Audio tap holds a getUserMedia track,
    // and leaving it open keeps the browser's recording indicator lit after Stop.
    await _levelTap.stop();
    level.value = 0;
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
