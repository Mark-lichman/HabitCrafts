// Pins the client pronunciation service (plan 2026-10-27, Task 2):
//   * PronScore (PIN-10) maps to correct / close / wrong on the named cutoffs (PIN-4);
//   * a network error, a function error, a failed sign-in or empty audio is unverified (PIN-3);
//   * listening stops by itself after silence that follows speech, never before speech and
//     never past the cap (PIN-5), and the live level streams while recording (PIN-7);
//   * the recording is 16 kHz mono 16-bit WAV (PIN-6), sent with the hiragana reference (PIN-1);
//   * the mora splitter and the syllable-to-letter mapping, with the whole-word fallback (PIN-8).
//
// Every seam is faked: no microphone, no network, no Firebase.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/pronunciation_service.dart';

const _goodFixture = 'firebase/speech_functions/fixtures/azure-reply-L26-1-mark.json';
const _badFixture =
    'firebase/speech_functions/fixtures/azure-reply-L26-1-mark-mispronounced.json';
const _sentence = 'あたまが いたいんです。';

Object? _fixture(String path) => jsonDecode(File(path).readAsStringSync());

/// [ms] of 16 kHz mono 16-bit PCM, a square wave of ±[amp].
Uint8List _pcm(int amp, int ms) {
  final n = PronunciationService.sampleRate * ms ~/ 1000;
  final b = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    b.setInt16(i * 2, i.isEven ? amp : -amp, Endian.little);
  }
  return b.buffer.asUint8List();
}

const _loud = 8000; // about -12 dBFS
const _quiet = 30; // about -61 dBFS

class _FakeTimer implements Timer {
  _FakeTimer(this.due, this.callback);
  final DateTime due;
  final void Function() callback;
  bool _active = true;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
  @override
  void cancel() => _active = false;
}

class _FakeClock implements PronClock {
  DateTime _now = DateTime(2026, 10, 27, 9);
  final List<_FakeTimer> _timers = [];

  @override
  DateTime now() => _now;

  @override
  Timer timer(Duration after, void Function() callback) {
    final t = _FakeTimer(_now.add(after), callback);
    _timers.add(t);
    return t;
  }

  void advance(Duration d) {
    _now = _now.add(d);
    for (final t in List.of(_timers)) {
      if (t.isActive && !t.due.isAfter(_now)) {
        t.cancel();
        t.callback();
      }
    }
  }
}

class _FakeRecorder implements PronRecorder {
  _FakeRecorder({this.available = true});
  final bool available;
  StreamController<Uint8List>? ctl;
  int? startedAt;
  int stops = 0;

  @override
  Future<Stream<Uint8List>?> start(int sampleRate) async {
    if (!available) return null;
    startedAt = sampleRate;
    ctl = StreamController<Uint8List>();
    return ctl!.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
    await ctl?.close();
  }
}

Future<void> _flush() => pumpEventQueue();

class _Rig {
  _Rig({
    bool micAvailable = true,
    this.reply,
    this.error,
    this.signInError,
  }) : recorder = _FakeRecorder(available: micAvailable) {
    service = PronunciationService(
      recorder: recorder,
      clock: clock,
      signIn: () async {
        events.add('signIn');
        if (signInError != null) throw signInError!;
      },
      score: (payload) async {
        events.add('score');
        sent = payload;
        if (error != null) throw error!;
        return reply;
      },
    );
  }

  final _FakeRecorder recorder;
  final _FakeClock clock = _FakeClock();
  final Object? reply;
  final Object? error;
  final Object? signInError;
  final List<String> events = [];
  Map<String, Object?>? sent;
  late final PronunciationService service;

  /// Feeds [ms] of audio at [amp] in 100 ms chunks, advancing the clock with it.
  Future<void> feed(int amp, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      if (recorder.ctl == null || recorder.ctl!.isClosed) return;
      clock.advance(const Duration(milliseconds: 100));
      if (recorder.ctl!.isClosed) return;
      recorder.ctl!.add(_pcm(amp, 100));
      await _flush();
    }
  }
}

void main() {
  group('cutoffs (PIN-4, PIN-10)', () {
    test('are 80 and 60, as named constants', () {
      expect(PronunciationService.correctCutoff, 80);
      expect(PronunciationService.closeCutoff, 60);
    });

    test('80 or more is correct, 60 to 79 close, below 60 wrong', () {
      expect(PronunciationService.verdictFor(100), Judgement.correct);
      expect(PronunciationService.verdictFor(80), Judgement.correct);
      expect(PronunciationService.verdictFor(79.9), Judgement.close);
      expect(PronunciationService.verdictFor(60), Judgement.close);
      expect(PronunciationService.verdictFor(59.9), Judgement.wrong);
      expect(PronunciationService.verdictFor(0), Judgement.wrong);
    });
  });

  group('reading a reply', () {
    test('the good fixture is correct with every score kept', () {
      final r = PronunciationResult.fromReply(_fixture(_goodFixture));
      expect(r.verdict, Judgement.correct);
      expect(r.overall, 98.6);
      expect(r.accuracy, 98);
      expect(r.fluency, 99);
      expect(r.completeness, 100);
      expect(r.words.map((w) => w.word),
          ['あたま', 'が', 'いたい', 'ん', 'です']);
      final atama = r.words.first;
      expect(atama.score, 97);
      expect(atama.errorType, 'None');
      expect(atama.syllableScores, [85, 100, 100]);
    });

    test('the mispronounced fixture is wrong (PronScore 44.8)', () {
      final r = PronunciationResult.fromReply(_fixture(_badFixture));
      expect(r.overall, 44.8);
      expect(r.verdict, Judgement.wrong);
      expect(r.words.first.errorType, 'Insertion');
      expect(r.words.first.isInserted, isTrue);
      expect(r.words[1].errorType, 'Mispronunciation');
      expect(r.words[1].syllableScores, [12, 64, 0]);
      expect(r.words[4].syllableScores, [6]);
    });

    test('the function shape (camelCase, flat syllable scores) reads too', () {
      final r = PronunciationResult.fromReply(<Object?, Object?>{
        'pronScore': 72.5,
        'accuracyScore': 70,
        'fluencyScore': 75,
        'completenessScore': 100,
        'words': [
          {
            'word': 'です',
            'accuracyScore': 70,
            'errorType': 'None',
            'syllables': [
              {'accuracyScore': 60},
              {'accuracyScore': 80},
            ],
          },
          {
            'word': 'が',
            'score': 90,
            'errorType': 'None',
            'syllableScores': [90],
          },
        ],
      });
      expect(r.verdict, Judgement.close);
      expect(r.overall, 72.5);
      expect(r.accuracy, 70);
      expect(r.fluency, 75);
      expect(r.completeness, 100);
      expect(r.words[0].syllableScores, [60, 80]);
      expect(r.words[1].score, 90);
      expect(r.words[1].syllableScores, [90]);
    });

    test('a reply with no PronScore is refused, not guessed', () {
      expect(() => PronunciationResult.fromReply({'words': []}),
          throwsFormatException);
      expect(
          () => PronunciationResult.fromReply(
              {'RecognitionStatus': 'NoMatch', 'NBest': []}),
          throwsFormatException);
      expect(() => PronunciationResult.fromReply(null), throwsFormatException);
    });
  });

  group('mora splitter (PIN-8)', () {
    test('plain kana are one mora each', () {
      expect(PronunciationService.splitMorae('あたま'), ['あ', 'た', 'ま']);
    });

    test('a small kana joins the letter before it', () {
      expect(PronunciationService.splitMorae('きょう'), ['きょ', 'う']);
      expect(PronunciationService.splitMorae('しゃしん'), ['しゃ', 'し', 'ん']);
      expect(PronunciationService.splitMorae('ファイル'), ['ファ', 'イ', 'ル']);
      expect(PronunciationService.splitMorae('くゎ'), ['くゎ']);
    });

    test('っ, ん and ー each count as one mora', () {
      expect(PronunciationService.splitMorae('がっこう'), ['が', 'っ', 'こ', 'う']);
      expect(PronunciationService.splitMorae('ラーメン'), ['ラ', 'ー', 'メ', 'ン']);
      expect(PronunciationService.splitMorae('ちょっと'), ['ちょ', 'っ', 'と']);
      expect(PronunciationService.splitMorae('コーヒー'), ['コ', 'ー', 'ヒ', 'ー']);
    });

    test('spaces and punctuation are not morae', () {
      expect(PronunciationService.splitMorae('です。'), ['で', 'す']);
      expect(PronunciationService.splitMorae(''), isEmpty);
    });
  });

  group('syllable-to-letter mapping (PIN-8)', () {
    test('both fixtures map every syllable to its mora by index', () {
      final good = PronunciationResult.fromReply(_fixture(_goodFixture));
      final atama = good.words.first.letters;
      expect(atama.map((l) => l.text), ['あ', 'た', 'ま']);
      expect(atama.map((l) => l.score), [85, 100, 100]);
      expect(atama.every((l) => l.fromSyllable), isTrue);
      expect(good.words.last.letters.map((l) => l.score), [93, 79]);

      final bad = PronunciationResult.fromReply(_fixture(_badFixture));
      final itai = bad.words[3].letters;
      expect(itai.map((l) => l.text), ['い', 'た', 'い']);
      expect(itai.map((l) => l.score), [7, 79, 42]);
      expect(bad.words[4].letters.single.score, 6);
    });

    test('a word with っ, ー or a small kana maps when the counts agree', () {
      const w = WordScore(
          word: 'ちょっと', score: 70, errorType: 'None', syllableScores: [90, 40, 85]);
      expect(w.letters.map((l) => l.text), ['ちょ', 'っ', 'と']);
      expect(w.letters.map((l) => l.score), [90, 40, 85]);
      expect(w.letters.every((l) => l.fromSyllable), isTrue);

      const r = WordScore(
          word: 'ラーメン', score: 88, errorType: 'None', syllableScores: [90, 50, 95, 100]);
      expect(r.letters.map((l) => l.score), [90, 50, 95, 100]);
    });

    test('when the counts differ the whole word takes its word score', () {
      const w = WordScore(
          word: 'がっこう', score: 66, errorType: 'Mispronunciation', syllableScores: [90, 40, 85]);
      expect(w.letters.map((l) => l.text), ['が', 'っ', 'こ', 'う']);
      expect(w.letters.map((l) => l.score), [66, 66, 66, 66]);
      expect(w.letters.any((l) => l.fromSyllable), isFalse);

      const omitted = WordScore(
          word: 'きょう', score: 0, errorType: 'Omission', syllableScores: []);
      expect(omitted.letters.map((l) => l.score), [0, 0]);
    });

    test('the sentence letters line up, skipping punctuation and inserted words', () {
      final good = PronunciationResult.fromReply(_fixture(_goodFixture))
          .sentenceLetters(_sentence);
      expect(good.map((l) => l.text).join(), _sentence);
      expect(good.where((l) => l.score == null).map((l) => l.text), [' ', '。']);
      expect(good.first.score, 85);

      final bad = PronunciationResult.fromReply(_fixture(_badFixture))
          .sentenceLetters(_sentence);
      expect(bad.map((l) => l.text).join(), _sentence);
      // The inserted extra あたま is not in the sentence, so the sentence's あたま takes the
      // second, scored one.
      expect(bad.take(3).map((l) => l.score), [12, 64, 0]);
      expect(bad.firstWhere((l) => l.text == 'ん').score, 6);
    });
  });

  group('check(): scoring', () {
    test('records 16 kHz mono WAV and sends it with the hiragana reference', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      final f = rig.service.check(_sentence);
      await _flush();
      expect(rig.recorder.startedAt, 16000);
      await rig.feed(_loud, 1000);
      await rig.feed(_quiet, 1500);
      final r = await f;

      expect(r.verdict, Judgement.correct);
      expect(r.overall, 98.6);
      expect(rig.events, ['signIn', 'score']);
      expect(rig.sent!['referenceText'], _sentence);
      final wav = base64Decode(rig.sent!['audio']! as String);
      final h = ByteData.sublistView(wav);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
      expect(h.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(h.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(h.getUint32(24, Endian.little), 16000, reason: 'sample rate');
      expect(h.getUint16(34, Endian.little), 16, reason: 'bits per sample');
      expect(h.getUint32(40, Endian.little), wav.length - 44);
      expect(wav.length - 44, greaterThan(0));
    });

    test('the mispronounced fixture comes back wrong', () async {
      final rig = _Rig(reply: _fixture(_badFixture));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_loud, 800);
      await rig.feed(_quiet, 1500);
      expect((await f).verdict, Judgement.wrong);
    });

    test('a network error is unverified, never wrong (PIN-3)', () async {
      final rig = _Rig(error: const SocketException('offline'));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_loud, 800);
      await rig.feed(_quiet, 1500);
      final r = await f;
      expect(r.verdict, Judgement.unverified);
      expect(r.overall, isNull);
    });

    test('a function error is unverified (PIN-3)', () async {
      final rig = _Rig(
          error: FirebaseFunctionsException(code: 'internal', message: 'azure 500'));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_loud, 800);
      await rig.feed(_quiet, 1500);
      expect((await f).verdict, Judgement.unverified);
    });

    test('a timed-out call is unverified (PIN-3)', () async {
      final rig = _Rig(error: TimeoutException('slow'));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_loud, 800);
      await rig.feed(_quiet, 1500);
      expect((await f).verdict, Judgement.unverified);
    });

    test('a reply that cannot be read is unverified (PIN-3)', () async {
      final rig = _Rig(reply: {'error': 'nope'});
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_loud, 800);
      await rig.feed(_quiet, 1500);
      expect((await f).verdict, Judgement.unverified);
    });

    test('a failed sign-in is unverified and makes no call (PIN-3)', () async {
      final rig = _Rig(
          reply: _fixture(_goodFixture), signInError: StateError('no auth'));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_loud, 800);
      await rig.feed(_quiet, 1500);
      expect((await f).verdict, Judgement.unverified);
      expect(rig.events, ['signIn']);
    });

    test('empty audio is unverified and makes no call (PIN-3)', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.recorder.ctl!.close();
      expect((await f).verdict, Judgement.unverified);
      expect(rig.events, isEmpty);
    });

    test('no microphone is unverified and makes no call (PIN-3)', () async {
      final rig = _Rig(micAvailable: false, reply: _fixture(_goodFixture));
      expect((await rig.service.check(_sentence)).verdict, Judgement.unverified);
      expect(rig.events, isEmpty);
    });
  });

  group('check(): stopping by itself (PIN-5)', () {
    test('stops after a silence that follows speech', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      var done = false;
      final f = rig.service.check(_sentence).whenComplete(() => done = true);
      await _flush();
      await rig.feed(_loud, 1000);
      await rig.feed(_quiet,
          PronunciationService.silenceAfterSpeech.inMilliseconds - 200);
      expect(done, isFalse, reason: 'a short pause does not end the listen');
      expect(rig.recorder.stops, 0);
      await rig.feed(_quiet, 400);
      await f;
      expect(done, isTrue);
      expect(rig.recorder.stops, 1);
      expect(rig.events, ['signIn', 'score']);
    });

    test('a pause inside the sentence does not end the listen', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      var done = false;
      final f = rig.service.check(_sentence).whenComplete(() => done = true);
      await _flush();
      await rig.feed(_loud, 500);
      await rig.feed(_quiet, 600);
      await rig.feed(_loud, 500);
      expect(done, isFalse);
      await rig.feed(_quiet, 1500);
      await f;
      expect(done, isTrue);
    });

    test('never stops on silence before speech starts', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      var done = false;
      final f = rig.service.check(_sentence).whenComplete(() => done = true);
      await _flush();
      await rig.feed(_quiet, 4000);
      expect(done, isFalse);
      expect(rig.recorder.stops, 0);
      await rig.feed(_loud, 800);
      await rig.feed(_quiet, 1500);
      expect((await f).verdict, Judgement.correct);
    });

    test('stops at the cap, even mid-speech', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      var done = false;
      final f = rig.service.check(_sentence).whenComplete(() => done = true);
      await _flush();
      final capMs = PronunciationService.listenCap.inMilliseconds;
      await rig.feed(_loud, capMs - 500);
      expect(done, isFalse);
      await rig.feed(_loud, 1000);
      final r = await f;
      expect(rig.recorder.stops, 1);
      expect(r.verdict, Judgement.correct, reason: 'speech at the cap is still scored');
      final wav = base64Decode(rig.sent!['audio']! as String);
      expect(wav.length - 44,
          lessThanOrEqualTo(capMs * PronunciationService.sampleRate ~/ 1000 * 2));
    });

    test('stops at the cap with no chunk arriving (a stalled stream)', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      final f = rig.service.check(_sentence);
      await _flush();
      rig.clock.advance(PronunciationService.listenCap);
      await _flush();
      final r = await f;
      expect(rig.recorder.stops, 1);
      expect(r.verdict, Judgement.unverified, reason: 'no speech, nothing to score');
      expect(rig.events, isEmpty);
    });

    test('silence all the way to the cap is unverified, with no call', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_quiet, PronunciationService.listenCap.inMilliseconds + 500);
      expect((await f).verdict, Judgement.unverified);
      expect(rig.events, isEmpty);
    });

    test('cancel() ends the listen as unverified, with no call', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      final f = rig.service.check(_sentence);
      await _flush();
      await rig.feed(_loud, 500);
      await rig.service.cancel();
      expect((await f).verdict, Judgement.unverified);
      expect(rig.recorder.stops, 1);
      expect(rig.events, isEmpty);
    });

    test('the timing constants are named and sane', () {
      expect(PronunciationService.silenceAfterSpeech, greaterThan(Duration.zero));
      expect(PronunciationService.listenCap,
          greaterThan(PronunciationService.silenceAfterSpeech));
      expect(PronunciationService.speechDbfs,
          greaterThan(PronunciationService.silenceDbfs));
    });
  });

  group('check(): live level (PIN-7)', () {
    test('streams a live level while recording and drops to 0 after', () async {
      final rig = _Rig(reply: _fixture(_goodFixture));
      final seen = <double>[];
      final sub = rig.service.levels.listen(seen.add);
      final listening = <bool>[];
      rig.service.listening.addListener(
          () => listening.add(rig.service.listening.value));

      final f = rig.service.check(_sentence);
      await _flush();
      expect(rig.service.listening.value, isTrue);
      await rig.feed(_quiet, 300);
      expect(rig.service.level.value, lessThan(0.1));
      await rig.feed(_loud, 300);
      expect(rig.service.level.value, greaterThan(0.5));
      await rig.feed(_quiet, 1500);
      await f;
      await _flush();

      expect(seen.where((v) => v > 0.5), isNotEmpty);
      expect(seen.where((v) => v < 0.1), isNotEmpty);
      expect(rig.service.level.value, 0);
      expect(rig.service.listening.value, isFalse);
      expect(listening, [true, false]);
      await sub.cancel();
    });
  });
}
