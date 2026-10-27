// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Checks a spoken sentence BY SOUND, not by spelling (plan 2026-10-27). The service records
// the learner, sends the audio and the sentence's hiragana to the `scorePronunciation` Cloud
// Function, and maps Azure's PronScore to a verdict. Spelling never enters the check, so a
// recognizer's choice of kanji cannot turn a correct sentence into a Close (PIN-1).
//
//   * Audio: 16 kHz mono 16-bit PCM, wrapped as WAV here (PIN-6). That is the format Azure's
//     short-audio endpoint takes.
//   * Listening stops by itself after a silence that follows speech, or at [listenCap]
//     (PIN-5). Silence before any speech never ends it.
//   * [level] and [levels] carry the live sound level for the drill's animation (PIN-7).
//   * PronScore decides (PIN-10): [correctCutoff] and up is correct, [closeCutoff] and up is
//     close, below is wrong (PIN-4).
//   * 🚨 Anything that cannot be scored is `unverified`, never `wrong` (PIN-3): no microphone,
//     no speech, a failed sign-in, a network or function error, or a reply we cannot read.
//     The drill sends unverified to self-check.
//
// The recorder, the clock, the caller sign-in and the function call are injectable seams, so
// tests need no microphone, no network and no Firebase.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:record/record.dart';

import 'speech_service.dart' show Judgement;

export 'speech_service.dart' show Judgement;

// --- seams -------------------------------------------------------------------

/// The microphone. [start] returns a stream of 16-bit little-endian mono PCM chunks at
/// [sampleRate], or null when no microphone can be opened.
abstract class PronRecorder {
  Future<Stream<Uint8List>?> start(int sampleRate);
  Future<void> stop();

  /// Releases the native recorder. The recorder cannot start again afterwards.
  Future<void> dispose();
}

/// Time, so the silence and cap rules can be tested without waiting.
abstract class PronClock {
  DateTime now();
  Timer timer(Duration after, void Function() callback);
}

/// Makes sure a Firebase caller exists before the function call. The drill passes the
/// anonymous-caller helper (PIN-9); see [PronunciationService.new] for the default.
typedef CallerSignIn = Future<void> Function();

/// Calls `scorePronunciation` with `{audio, referenceText}` and returns the reply data.
typedef ScoreCall = Future<Object?> Function(Map<String, Object?> payload);

class SystemPronClock implements PronClock {
  const SystemPronClock();
  @override
  DateTime now() => DateTime.now();
  @override
  Timer timer(Duration after, void Function() callback) => Timer(after, callback);
}

/// The real microphone, through the `record` package's PCM stream (Android and web).
class RecordPackageRecorder implements PronRecorder {
  AudioRecorder? _rec;

  @override
  Future<Stream<Uint8List>?> start(int sampleRate) async {
    try {
      final rec = _rec ??= AudioRecorder();
      // On Android this asks for RECORD_AUDIO. On web the browser raises its own prompt.
      if (!await rec.hasPermission()) return null;
      return await rec.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _rec?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
  }
}

// --- results -----------------------------------------------------------------

/// One letter (one mora) of a word, with the score that colors it (PIN-8).
class LetterScore {
  const LetterScore(this.text, this.score, {required this.fromSyllable});

  /// The mora as written: one kana, or a kana with its small kana (きょ).
  final String text;
  final double score;

  /// True when the score is this mora's own syllable score; false for the whole-word fallback.
  final bool fromSyllable;
}

/// One letter of the sentence as the drill shows it. [score] is null for a space, punctuation
/// or a letter no scored word covers.
class SentenceLetter {
  const SentenceLetter(this.text, this.score);
  final String text;
  final double? score;
}

/// One word of Azure's reply.
class WordScore {
  const WordScore({
    required this.word,
    required this.score,
    required this.errorType,
    required this.syllableScores,
  });

  final String word;
  final double score;

  /// Azure's error type: None, Mispronunciation, Omission or Insertion.
  final String errorType;

  /// Azure's syllable scores in order. Azure returns empty syllable text for ja-JP, so these
  /// map to the word's morae by index only.
  final List<double> syllableScores;

  /// An extra word the learner said that is not in the sentence. The drill strikes it through.
  bool get isInserted => errorType == 'Insertion';

  /// Each mora with its syllable score, or every mora with the word score when Azure's
  /// syllable count differs from the mora count (the whole-word fallback).
  List<LetterScore> get letters {
    final morae = PronunciationService.splitMorae(word);
    if (morae.length == syllableScores.length) {
      return [
        for (var i = 0; i < morae.length; i++)
          LetterScore(morae[i], syllableScores[i], fromSyllable: true),
      ];
    }
    return [for (final m in morae) LetterScore(m, score, fromSyllable: false)];
  }
}

class PronunciationResult {
  const PronunciationResult({
    required this.verdict,
    this.overall,
    this.accuracy,
    this.fluency,
    this.completeness,
    this.words = const [],
  });

  /// Nothing could be scored. The drill sends this to self-check (PIN-3).
  const PronunciationResult.unverified() : this(verdict: Judgement.unverified);

  final Judgement verdict;

  /// Azure's PronScore, the score that decides [verdict] (PIN-10). Null when unverified.
  final double? overall;
  final double? accuracy;
  final double? fluency;
  final double? completeness;
  final List<WordScore> words;

  /// Reads the function's reply. Accepts both Azure's own shape (`NBest[0]`, PascalCase,
  /// scores either flat or under `PronunciationAssessment`) and a flattened camelCase shape,
  /// so the client does not break on how the function chooses to pass the reply through.
  ///
  /// 🚨 Throws [FormatException] when there is no PronScore. The caller turns that into
  /// unverified; a missing score is never read as 0, which would mark the learner wrong.
  factory PronunciationResult.fromReply(Object? data) {
    var m = _asMap(data);
    if (m == null) throw const FormatException('reply is not an object');
    final status = m['RecognitionStatus'] ?? m['recognitionStatus'];
    if (status != null && status != 'Success') {
      throw FormatException('recognition status $status');
    }
    final nbest = m['NBest'] ?? m['nBest'];
    if (nbest is List) {
      if (nbest.isEmpty) throw const FormatException('no NBest entry');
      m = _asMap(nbest.first);
      if (m == null) throw const FormatException('NBest entry is not an object');
    }
    final overall = _score(m, const ['PronScore', 'pronScore', 'overall']);
    if (overall == null) throw const FormatException('reply has no PronScore');

    final rawWords = m['Words'] ?? m['words'];
    final words = <WordScore>[];
    if (rawWords is List) {
      for (final rw in rawWords) {
        final w = _asMap(rw);
        if (w == null) continue;
        final text = w['Word'] ?? w['word'];
        if (text is! String) continue;
        words.add(WordScore(
          word: text,
          score: _score(w, const ['AccuracyScore', 'accuracyScore', 'accuracy', 'score']) ?? 0,
          errorType: (_field(w, const ['ErrorType', 'errorType']) as String?) ?? 'None',
          syllableScores: _syllables(w),
        ));
      }
    }
    return PronunciationResult(
      verdict: PronunciationService.verdictFor(overall),
      overall: overall,
      accuracy: _score(m, const ['AccuracyScore', 'accuracyScore', 'accuracy']),
      fluency: _score(m, const ['FluencyScore', 'fluencyScore', 'fluency']),
      completeness:
          _score(m, const ['CompletenessScore', 'completenessScore', 'completeness']),
      words: words,
    );
  }

  /// The sentence letter by letter, each with the score of the mora that covers it (PIN-8).
  /// Inserted words are skipped, since they are not in the sentence. Spaces and punctuation
  /// get a null score.
  List<SentenceLetter> sentenceLetters(String sentence) {
    final scored = [
      for (final w in words)
        if (!w.isInserted) ...w.letters,
    ];
    final folded = _toHiragana(sentence);
    final out = <SentenceLetter>[];
    var pos = 0;
    var next = 0;
    while (pos < sentence.length) {
      if (next < scored.length) {
        final t = _toHiragana(scored[next].text);
        if (t.isNotEmpty && folded.startsWith(t, pos)) {
          final s = scored[next].score;
          for (var i = 0; i < t.length; i++) {
            out.add(SentenceLetter(sentence[pos + i], s));
          }
          pos += t.length;
          next++;
          continue;
        }
      }
      out.add(SentenceLetter(sentence[pos], null));
      pos++;
    }
    return out;
  }

  static Map<String, Object?>? _asMap(Object? v) =>
      v is Map ? v.map((k, val) => MapEntry('$k', val)) : null;

  /// A field read flat or from Azure's nested `PronunciationAssessment` object.
  static Object? _field(Map<String, Object?> m, List<String> keys) {
    final nested = _asMap(m['PronunciationAssessment'] ?? m['pronunciationAssessment']);
    for (final k in keys) {
      if (m[k] != null) return m[k];
      if (nested != null && nested[k] != null) return nested[k];
    }
    return null;
  }

  static double? _score(Map<String, Object?> m, List<String> keys) {
    final v = _field(m, keys);
    return v is num ? v.toDouble() : null;
  }

  static List<double> _syllables(Map<String, Object?> w) {
    final raw = w['Syllables'] ?? w['syllables'] ?? w['syllableScores'];
    if (raw is! List) return const [];
    final out = <double>[];
    for (final s in raw) {
      if (s is num) {
        out.add(s.toDouble());
        continue;
      }
      final sm = _asMap(s);
      final v = sm == null
          ? null
          : _score(sm, const ['AccuracyScore', 'accuracyScore', 'accuracy', 'score']);
      if (v != null) out.add(v);
    }
    return out;
  }
}

// --- the service -------------------------------------------------------------

class PronunciationService {
  PronunciationService({
    PronRecorder? recorder,
    PronClock? clock,
    CallerSignIn? signIn,
    ScoreCall? score,
  })  : _recorder = recorder ?? RecordPackageRecorder(),
        _clock = clock ?? const SystemPronClock(),
        _signIn = signIn ?? _firebaseSignIn,
        _score = score ?? _callFunction;

  final PronRecorder _recorder;
  final PronClock _clock;
  final CallerSignIn _signIn;
  final ScoreCall _score;

  /// PronScore at or above this is correct (PIN-4). Tune from the drill's Recent scores.
  static const double correctCutoff = 80;

  /// PronScore at or above this, and below [correctCutoff], is close (PIN-4).
  static const double closeCutoff = 60;

  /// 16 kHz mono 16-bit PCM (PIN-6).
  static const int sampleRate = 16000;

  /// How long a quiet stretch after speech must last before listening stops (PIN-5).
  static const Duration silenceAfterSpeech = Duration(milliseconds: 1200);

  /// The longest a listen runs, speech or not (PIN-5).
  static const Duration listenCap = Duration(seconds: 10);

  /// A chunk at or above this level (dB full scale) counts as speech.
  static const double speechDbfs = -40;

  /// A chunk below this level counts as silence. A chunk between the two levels does not
  /// refresh the last-speech time and does not end the listen by itself. The silence span is
  /// measured from the last chunk at or above [speechDbfs]. A chunk below this level ends the
  /// listen once that span reaches [silenceAfterSpeech].
  static const double silenceDbfs = -50;

  /// The level shown as 0 by [level]; 0 dBFS shows as 1.
  static const double levelFloorDbfs = -60;

  /// How long the sign-in and the function call together may take before the check gives up
  /// as unverified.
  static const Duration callTimeout = Duration(seconds: 20);

  static const String functionName = 'scorePronunciation';
  static const String functionRegion = 'us-central1';

  static Judgement verdictFor(double pronScore) {
    if (pronScore >= correctCutoff) return Judgement.correct;
    if (pronScore >= closeCutoff) return Judgement.close;
    return Judgement.wrong;
  }

  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  final ValueNotifier<bool> _listening = ValueNotifier<bool>(false);
  final StreamController<double> _levels = StreamController<double>.broadcast();

  /// Live microphone level, 0..1, while listening; 0 otherwise (PIN-7).
  ValueListenable<double> get level => _level;

  /// The same live level as a stream (PIN-7).
  Stream<double> get levels => _levels.stream;

  /// True while the microphone is open.
  ValueListenable<bool> get listening => _listening;

  _Listen? _active;

  /// Counts recorder starts. [cancel] records the latest start it covers in
  /// [_cancelledStart], so a cancel that lands while the start is still pending is not lost.
  int _starts = 0;
  int _cancelledStart = 0;

  /// Records the learner saying [hiragana] and scores it against [hiragana] (PIN-1).
  /// Never throws: anything that cannot be scored is [PronunciationResult.unverified].
  Future<PronunciationResult> check(String hiragana) async {
    final audio = await _record();
    if (audio == null) return const PronunciationResult.unverified();
    try {
      // One bound covers the sign-in and the call, so a black-holed network cannot hold the
      // check past callTimeout.
      final reply = await () async {
        await _signIn();
        return _score({
          'audio': base64Encode(audio),
          'referenceText': hiragana,
        });
      }()
          .timeout(callTimeout);
      return PronunciationResult.fromReply(reply);
    } catch (_) {
      // Network, function, sign-in, timeout and format errors all land here (PIN-3).
      return const PronunciationResult.unverified();
    }
  }

  /// Stops a listen in progress, or one whose recorder start is still pending. Its [check]
  /// returns unverified and makes no call.
  Future<void> cancel() async {
    _cancelledStart = _starts;
    final a = _active;
    if (a != null) await a.finish(cancelled: true);
  }

  /// Returns the WAV, or null when there is nothing worth scoring (no microphone, no speech,
  /// empty audio, or a cancel).
  Future<Uint8List?> _record() async {
    await cancel();
    final start = ++_starts;
    final stream = await _recorder.start(sampleRate);
    if (stream == null) return null;
    if (_cancelledStart >= start) {
      // cancel() or dispose() ran while the start was pending (for example during the
      // first-run microphone prompt). Close the microphone it just opened.
      await _recorder.stop();
      return null;
    }
    final listen = _active = _Listen(this);
    _listening.value = true;
    listen.begin(stream);
    final pcm = await listen.done.future;
    if (identical(_active, listen)) _active = null;
    if (pcm == null || pcm.isEmpty) return null;
    return wav(pcm);
  }

  void _setLevel(double v) {
    _level.value = v;
    if (!_levels.isClosed) _levels.add(v);
  }

  /// Releases the level stream and the recorder. The service cannot listen again afterwards.
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
    await _levels.close();
  }

  // --- audio helpers ---------------------------------------------------------

  /// RMS level of a 16-bit little-endian PCM chunk, in dB full scale.
  static double dbfs(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    if (n == 0) return double.negativeInfinity;
    final b = ByteData.sublistView(pcm);
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final s = b.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    final rms = math.sqrt(sum / n);
    return rms == 0 ? double.negativeInfinity : 20 * math.log(rms) / math.ln10;
  }

  /// A 44-byte RIFF header around 16 kHz mono 16-bit PCM (PIN-6).
  static Uint8List wav(Uint8List pcm) {
    const channels = 1;
    const bits = 16;
    const byteRate = sampleRate * channels * bits ~/ 8;
    final h = ByteData(44);
    void tag(int at, String s) {
      for (var i = 0; i < 4; i++) {
        h.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    h.setUint32(4, 36 + pcm.length, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little); // PCM
    h.setUint16(22, channels, Endian.little);
    h.setUint32(24, sampleRate, Endian.little);
    h.setUint32(28, byteRate, Endian.little);
    h.setUint16(32, channels * bits ~/ 8, Endian.little);
    h.setUint16(34, bits, Endian.little);
    tag(36, 'data');
    h.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder(copy: false)
          ..add(h.buffer.asUint8List())
          ..add(pcm))
        .toBytes();
  }

  // --- morae (PIN-8) -----------------------------------------------------------

  /// Small kana that join the letter before them, hiragana and katakana.
  static const String _small = 'ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ';

  /// Splits kana into morae: a small kana joins the letter before it, and っ, ん and ー each
  /// count as one mora. Spaces and punctuation are dropped.
  static List<String> splitMorae(String kana) {
    final out = <String>[];
    for (final r in kana.runes) {
      final c = String.fromCharCode(r);
      if (!_isKana(r)) continue;
      if (_small.contains(c) && out.isNotEmpty) {
        out[out.length - 1] += c;
      } else {
        out.add(c);
      }
    }
    return out;
  }

  /// Hiragana, katakana and the long mark ー.
  static bool _isKana(int r) =>
      (r >= 0x3041 && r <= 0x3096) || (r >= 0x30A1 && r <= 0x30FA) || r == 0x30FC;

  // --- defaults ----------------------------------------------------------------

  /// Default caller: reuse any signed-in user, else sign in anonymously. The drill passes the
  /// shared anonymous-caller helper instead, which does the same (PIN-9).
  static Future<void> _firebaseSignIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
  }

  static Future<Object?> _callFunction(Map<String, Object?> payload) async {
    final callable = FirebaseFunctions.instanceFor(region: functionRegion).httpsCallable(
        functionName,
        options: HttpsCallableOptions(timeout: callTimeout));
    final r = await callable.call<Object?>(payload);
    return r.data;
  }
}

String _toHiragana(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    b.writeCharCode(r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r);
  }
  return b.toString();
}

/// One recording session: collects PCM, drives the live level and decides when to stop.
class _Listen {
  _Listen(this.svc);

  final PronunciationService svc;
  final Completer<Uint8List?> done = Completer<Uint8List?>();
  final BytesBuilder _pcm = BytesBuilder(copy: true);
  StreamSubscription<Uint8List>? _sub;
  Timer? _cap;
  late final DateTime _started;
  DateTime? _lastSpeech;
  bool _heardSpeech = false;
  bool _finishing = false;

  static final int _maxBytes = PronunciationService.sampleRate *
      2 *
      PronunciationService.listenCap.inMilliseconds ~/
      1000;

  void begin(Stream<Uint8List> stream) {
    _started = svc._clock.now();
    _cap = svc._clock.timer(PronunciationService.listenCap, () => finish());
    _sub = stream.listen(_onChunk, onDone: () => finish(), onError: (_) => finish());
  }

  void _onChunk(Uint8List chunk) {
    if (_finishing) return;
    final room = _maxBytes - _pcm.length;
    if (room > 0) {
      _pcm.add(chunk.length > room ? Uint8List.sublistView(chunk, 0, room) : chunk);
    }
    final db = PronunciationService.dbfs(chunk);
    const floor = PronunciationService.levelFloorDbfs;
    svc._setLevel(db.isFinite ? ((db - floor) / -floor).clamp(0.0, 1.0) : 0.0);

    final now = svc._clock.now();
    if (db >= PronunciationService.speechDbfs) {
      _heardSpeech = true;
      _lastSpeech = now;
    } else if (_heardSpeech &&
        db < PronunciationService.silenceDbfs &&
        now.difference(_lastSpeech!) >= PronunciationService.silenceAfterSpeech) {
      finish();
      return;
    }
    if (now.difference(_started) >= PronunciationService.listenCap || room <= chunk.length) {
      finish();
    }
  }

  Future<void> finish({bool cancelled = false}) async {
    if (_finishing) {
      await done.future;
      return;
    }
    _finishing = true;
    _cap?.cancel();
    await _sub?.cancel();
    await svc._recorder.stop();
    svc._setLevel(0);
    svc._listening.value = false;
    // No speech is nothing to score: sending silence would spend a call to learn nothing.
    done.complete(cancelled || !_heardSpeech ? null : _pcm.takeBytes());
  }
}
