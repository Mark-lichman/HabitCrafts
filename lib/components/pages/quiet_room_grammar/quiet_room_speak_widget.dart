// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The per-lesson speaking drill (2026-10-24 plan, PIN-6). It walks one grammar lesson's
// sentences point by point: each point's examples, then its practice items with the
// answer in the blank.
// For each one the learner plays the sentence, speaks it once, and the drill scores it.
//
// Scoring is BY SOUND, not by spelling (plan 2026-10-27, Task 3). The drill hands the
// sentence's hiragana to `PronunciationService.check` (PIN-1). The service records, stops
// by itself when the learner goes quiet, and asks Azure through the `scorePronunciation`
// function. The kana is the kanji twin's reading (every `漢字{かな}` bracket replaced by its
// reading), so an example the lesson prints in kanji still has a hiragana reference. An
// example that joins several forms with ／ becomes one sentence per form.
//
//   * The caller: the service's sign-in seam is `ensureCaller()`, so a hidden anonymous
//     sign-in happens only when a recording is ready to score (PIN-9).
//   * Listening: the live level animation is fed from the service's sound level, and the
//     service ends the listen after a silence that follows speech. No Stop tap is needed
//     (PIN-7). Stop stays as a way out of a false start.
//   * One check at a time: Speak and Next wait until the check returns, so two checks never
//     share the microphone.
//
// 🚨 NOTHING THAT CANNOT BE SCORED IS EVER MARKED WRONG (PIN-3).
//   * `correct` is marked right and shows the score.
//   * `close` shows the score in amber, then asks the learner: "Got it" or "Missed it".
//   * `wrong` is marked wrong and shows the score. Only a real Azure score can say wrong.
//   * `unverified` (no microphone, no speech, no network, a failed sign-in or call) asks
//     the same self-check question.
// Every scored result shows the sentence with each hiragana letter colored by its syllable
// score (PIN-8). Every attempt's sentence, scores and verdict stay on the device and the
// newest are listed under "Recent scores", so the operator can tune the cutoffs (PIN-4).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/components/pages/quiet_room_practice/anon_caller.dart';
import '/components/pages/quiet_room_practice/listening_bars.dart';
import '/components/pages/quiet_room_practice/pronunciation_service.dart';
import '/components/pages/quiet_room_practice/speech_service.dart'
    show SpeechService;
import '/flutter_flow/quiet_room.dart';
import 'jp_study_kit.dart';

// The drill's tests and callers read the twin helpers from here too.
export 'jp_study_kit.dart' show rubySurface, rubyKana;

/// Speaks Japanese text. Returns null on success, or a message saying why not.
typedef SpeakPlay = Future<String?> Function(String text);

/// Builds the drill's pronunciation service around the sign-in it must use. Tests pass a
/// service on fake seams; the default records with the real microphone.
typedef SpeakServiceFactory = PronunciationService Function(
    CallerSignIn signIn);

/// One sentence of the drill: the hiragana shown and scored, its kanji surface, and English.
class SpeakSentence {
  const SpeakSentence(
      {required this.kana, required this.surface, required this.en});

  final String kana;
  final String surface;
  final String en;
}

/// Several forms joined in one example: いこう／たべよう／しよう／こよう.
const String _joiner = '／';

/// Splits a hiragana text and its twin on ／ into one [SpeakSentence] per form. When the
/// two sides do not split alike, the whole pair is one sentence.
Iterable<SpeakSentence> _sentencesOf(String jp, String ruby, String en) {
  final kanaParts = jp.split(_joiner);
  final rubyParts = ruby.split(_joiner);
  final pairs =
      kanaParts.length == rubyParts.length ? rubyParts : <String>[ruby];
  return pairs.map((r) => SpeakSentence(
        kana: rubyKana(r),
        surface: rubySurface(r),
        en: en,
      ));
}

/// Point by point, in the order the lesson teaches them: each point's examples, then
/// its practice items with the answer in the blank. An example that joins forms
/// with ／ gives one sentence per form, and no sentence contains ／.
List<SpeakSentence> lessonSentences(Map<String, dynamic> lesson) {
  final out = <SpeakSentence>[];
  for (final p in (lesson['points'] as List).cast<Map<String, dynamic>>()) {
    for (final e
        in (p['examples'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final jp = e['jp'] as String;
      out.addAll(_sentencesOf(
          jp, e['jp_ruby'] as String? ?? jp, e['en'] as String? ?? ''));
    }
    for (final q
        in (p['practice'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final answer = q['answer'] as String;
      final prompt = q['prompt'] as String;
      final kana = prompt.replaceAll('＿＿', answer);
      final ruby = (q['prompt_ruby'] as String? ?? prompt)
          .replaceAll('＿＿', q['answer_ruby'] as String? ?? answer);
      out.addAll(_sentencesOf(kana, ruby, q['en'] as String? ?? ''));
    }
  }
  return out;
}

/// The color of a letter or word scored [score]: green at the correct cutoff and up, amber
/// at the close cutoff and up, red below (PIN-8, on the PIN-4 cutoffs).
Color scoreColor(QuietRoomTokens t, double score) {
  if (score >= PronunciationService.correctCutoff) return t.sage600;
  if (score >= PronunciationService.closeCutoff) return t.amber700;
  return t.clay600;
}

/// A score as the drill prints it: 98.6, or 70 when it is whole.
String formatScore(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// --- the score log (PIN-4) ---------------------------------------------------

/// One spoken attempt, as the device keeps it.
class SpeakAttempt {
  const SpeakAttempt({
    required this.sentence,
    required this.verdict,
    required this.at,
    this.overall,
    this.accuracy,
    this.fluency,
    this.completeness,
    this.words = const [],
  });

  factory SpeakAttempt.of(
          String sentence, PronunciationResult r, DateTime at) =>
      SpeakAttempt(
        sentence: sentence,
        verdict: r.verdict,
        at: at,
        overall: r.overall,
        accuracy: r.accuracy,
        fluency: r.fluency,
        completeness: r.completeness,
        words: r.words,
      );

  final String sentence;
  final Judgement verdict;
  final DateTime at;

  /// PronScore, the score that decided [verdict]. Null when unverified.
  final double? overall;
  final double? accuracy;
  final double? fluency;
  final double? completeness;
  final List<WordScore> words;

  Map<String, Object?> toJson() => {
        'sentence': sentence,
        'verdict': verdict.name,
        'at': at.toIso8601String(),
        'overall': overall,
        'accuracy': accuracy,
        'fluency': fluency,
        'completeness': completeness,
        'words': [
          for (final w in words)
            {
              'word': w.word,
              'score': w.score,
              'errorType': w.errorType,
              'syllables': w.syllableScores,
            }
        ],
      };

  /// Null for an entry this build cannot read, so one bad entry never hides the rest.
  static SpeakAttempt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final sentence = raw['sentence'];
    final verdict =
        Judgement.values.where((j) => j.name == raw['verdict']).firstOrNull;
    if (sentence is! String || verdict == null) return null;
    double? num_(Object? v) => v is num ? v.toDouble() : null;
    final words = <WordScore>[];
    for (final w in (raw['words'] is List ? raw['words'] as List : const [])) {
      if (w is! Map || w['word'] is! String) continue;
      words.add(WordScore(
        word: w['word'] as String,
        score: num_(w['score']) ?? 0,
        errorType: w['errorType'] is String ? w['errorType'] as String : 'None',
        syllableScores: [
          for (final s
              in (w['syllables'] is List ? w['syllables'] as List : []))
            if (s is num) s.toDouble()
        ],
      ));
    }
    return SpeakAttempt(
      sentence: sentence,
      verdict: verdict,
      at: DateTime.tryParse('${raw['at']}') ?? DateTime(0),
      overall: num_(raw['overall']),
      accuracy: num_(raw['accuracy']),
      fluency: num_(raw['fluency']),
      completeness: num_(raw['completeness']),
      words: words,
    );
  }
}

/// Every attempt's sentence, scores and verdict, kept on the device, oldest first, so the
/// operator can tune the cutoffs from real scores (PIN-4). There is no account to sync to.
class SpeakScoreLog {
  static const String prefsKey = 'jp.speak.scores';

  /// The newest attempts kept. Older ones drop off.
  static const int keep = 200;

  /// Never throws: an unreadable log reads as empty.
  static Future<List<SpeakAttempt>> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(prefsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(SpeakAttempt.fromJson).whereType<SpeakAttempt>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Appends [a] and returns the log as saved. Never throws: a failed save keeps the drill
  /// running and returns what could be read. The drill runs one check at a time, so two
  /// saves never overlap.
  static Future<List<SpeakAttempt>> add(SpeakAttempt a) async {
    final list = await load();
    list.add(a);
    if (list.length > keep) list.removeRange(0, list.length - keep);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          prefsKey, jsonEncode([for (final e in list) e.toJson()]));
    } catch (_) {
      // The score log is a tuning aid; losing one entry never blocks the drill.
    }
    return list;
  }
}

// --- the drill ---------------------------------------------------------------

class QuietRoomSpeakWidget extends StatefulWidget {
  const QuietRoomSpeakWidget({
    super.key,
    required this.lesson,
    this.play,
    this.newService,
    this.callerAuth,
  });

  /// The grammar lesson number, as in `grammar[].lesson`.
  final int? lesson;

  /// Test seams. Null plays with [SpeechService.instance], records with the real
  /// microphone, and signs in through Firebase.
  final SpeakPlay? play;
  final SpeakServiceFactory? newService;
  final CallerAuth? callerAuth;

  static String routeName = 'quietRoomSpeak';
  static String routePath = '/quietRoomSpeak';

  @override
  State<QuietRoomSpeakWidget> createState() => _QuietRoomSpeakWidgetState();
}

class _QuietRoomSpeakWidgetState extends State<QuietRoomSpeakWidget> {
  late final PronunciationService _svc;

  int _index = 0;

  /// True from Speak until the check returns. Speak and Next wait meanwhile, so one check
  /// owns the microphone at a time.
  bool _busy = false;

  /// True once this check's microphone has opened, and [_scoring] once it has closed again:
  /// the recording is on its way to Azure.
  bool _micOpened = false;
  bool _scoring = false;

  /// True after Stop. The check winds down and its result is dropped.
  bool _stopped = false;
  bool _heardVoice = false;

  /// True while Play's voice is speaking. Play and Speak are disabled meanwhile, so the
  /// microphone never hears the app's own voice.
  bool _playing = false;

  /// The last attempt on this sentence, or null before one.
  PronunciationResult? _result;

  /// The learner's own mark after a self-check: true for "Got it".
  bool? _selfMark;

  int _seen = 0;
  int _right = 0;

  /// Bumped by every Speak and Stop. A check whose attempt is no longer current drops its
  /// result instead of showing it.
  int _attempt = 0;

  /// The device's score log, oldest first.
  List<SpeakAttempt> _log = const [];

  @override
  void initState() {
    super.initState();
    final make =
        widget.newService ?? (signIn) => PronunciationService(signIn: signIn);
    _svc = make(_signIn);
    _svc.listening.addListener(_onMic);
    SpeakScoreLog.load().then((log) {
      if (mounted && log.isNotEmpty) setState(() => _log = log);
    });
  }

  /// The caller the function needs, made only when a recording is ready to score (PIN-9).
  Future<void> _signIn() =>
      ensureCaller(auth: widget.callerAuth ?? const FirebaseCallerAuth());

  void _onMic() {
    if (!mounted || !_busy) return;
    if (_svc.listening.value) {
      _micOpened = true;
    } else if (_micOpened && !_stopped && !_scoring) {
      setState(() => _scoring = true);
    }
  }

  @override
  void dispose() {
    _svc.listening.removeListener(_onMic);
    _svc.dispose();
    if (widget.play == null) SpeechService.instance.stopSpeaking();
    super.dispose();
  }

  Future<String?> _say(String text) =>
      widget.play?.call(text) ?? SpeechService.instance.speak(text);

  Future<void> _play(SpeakSentence s) async {
    if (_playing || _busy) return;
    setState(() => _playing = true);
    try {
      // Spoken as a pause, the way quiet_room_grammar_widget.dart reads a joined example.
      // Off the web, speak() returns when the voice has finished or at
      // SpeechService.speakWait, whichever comes first, so the buttons stay disabled until
      // then. On the web it returns at once.
      final err = await _say(s.kana.replaceAll(_joiner, '、'));
      if (err != null && mounted) {
        final t = QuietRoomTokens.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err, style: qrText(t, size: 13, color: t.onBrand)),
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      // In a finally so a throw from the voice never leaves Speak disabled for good.
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _speak(SpeakSentence s) async {
    if (_busy || _playing) return;
    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _micOpened = false;
      _scoring = false;
      _stopped = false;
      _heardVoice = false;
      _result = null;
      _selfMark = null;
    });
    try {
      // check() never throws: anything it cannot score comes back unverified (PIN-3).
      final r = await _svc.check(s.kana);
      // Stop retired this attempt while it ran: its result is dropped, not kept.
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _result = r;
        if (r.verdict == Judgement.correct) {
          _seen++;
          _right++;
        } else if (r.verdict == Judgement.wrong) {
          _seen++;
        }
      });
      SpeakScoreLog.add(SpeakAttempt.of(s.kana, r, DateTime.now())).then((log) {
        if (mounted) setState(() => _log = log);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _scoring = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    // Retire the attempt first, so its result is dropped.
    _attempt++;
    setState(() => _stopped = true);
    await _svc.cancel();
  }

  void _mark(bool gotIt) {
    if (_selfMark != null) return;
    setState(() {
      _selfMark = gotIt;
      _seen++;
      if (gotIt) _right++;
    });
  }

  /// Ignored during a check, so a pending result is never credited to the next sentence.
  void _next(int count) {
    if (_busy) return;
    setState(() {
      _index = (_index + 1) % count;
      _result = null;
      _selfMark = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return QrStudyScaffold(
      child: QrLoad(builder: (context, doc) {
        final lesson = (doc['grammar'] as List)
            .cast<Map<String, dynamic>>()
            .where((l) => l['lesson'] == widget.lesson)
            .firstOrNull;
        if (lesson == null) {
          return Center(
              child: Text('No grammar lesson ${widget.lesson ?? ''}.',
                  style: qrText(t, color: t.clay600)));
        }
        final sentences = lessonSentences(lesson);
        if (sentences.isEmpty) {
          return Center(
              child: Text('This lesson has no sentences to speak.',
                  style: qrText(t, color: t.clay600)));
        }
        final s = sentences[_index % sentences.length];
        final Widget action;
        if (_busy && !_stopped) {
          action = _scoring ? _checkingPanel(t) : _listeningPanel(t);
        } else {
          action = _controls(t, s);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Speak lesson ${lesson['lesson']}',
                        style: qrTitle(t, size: 22))),
                Text(_seen == 0 ? 'Say it' : '$_right of $_seen',
                    style: qrText(t,
                        size: 14, weight: FontWeight.w600, color: t.inkMuted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Sentence ${_index % sentences.length + 1} of ${sentences.length}. '
                'Play it, then say it once.',
                style: qrText(t, size: 13.5, color: t.inkMuted)),
            const SizedBox(height: 16),
            QrCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.kana, style: qrText(t, size: 20, height: 1.5)),
                  if (s.en.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(s.en, style: qrText(t, size: 13.5, color: t.inkMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            action,
            if (_result != null) ...[
              const SizedBox(height: 14),
              _verdictCard(t, s),
            ],
            const SizedBox(height: 22),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _next(sentences.length),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
                child: Text('Next sentence',
                    style: qrText(t,
                        size: 14, weight: FontWeight.w600, color: t.brand600)),
              ),
            ),
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 18),
              _recentScores(t),
            ],
          ],
        );
      }),
    );
  }

  Widget _controls(QuietRoomTokens t, SpeakSentence s) {
    final idle = !_playing && !_busy;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: QuietRoomMetrics.targetMin,
            child: OutlinedButton.icon(
              onPressed: idle ? () => _play(s) : null,
              icon: Icon(Icons.volume_up_outlined, size: 20, color: t.ink),
              label: Text('Play',
                  style: qrText(t, size: 15, weight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: t.borderControl,
                    width: QuietRoomMetrics.strokeControl),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: QuietRoomMetrics.targetMin,
            child: ElevatedButton.icon(
              onPressed: idle ? () => _speak(s) : null,
              icon: Icon(Icons.mic_none, size: 20, color: t.onBrand),
              label: Text('Speak',
                  style: qrText(t,
                      size: 15, weight: FontWeight.w600, color: t.onBrand)),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.brand600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _panel(QuietRoomTokens t) => BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderControl, width: 1),
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
      );

  /// The live level while the microphone is open (PIN-7). The service ends the listen by
  /// itself; Stop only throws away a false start.
  Widget _listeningPanel(QuietRoomTokens t) {
    return Container(
      decoration: _panel(t),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Column(
        children: [
          ListeningBars(
            level: _svc.level,
            onRealDetected: () {
              if (mounted && !_heardVoice) setState(() => _heardVoice = true);
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_heardVoice ? 'Hearing you' : 'Listening',
                  style: qrText(t,
                      size: 13, weight: FontWeight.w600, color: t.inkMuted)),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _stop,
                child: Text('Stop',
                    style: qrText(t,
                        size: 13, weight: FontWeight.w600, color: t.brand600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The recording is on its way to Azure.
  Widget _checkingPanel(QuietRoomTokens t) {
    return Container(
      decoration: _panel(t),
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
      child: Center(
        child: Text('Checking…',
            style: qrText(t,
                size: 13, weight: FontWeight.w600, color: t.inkMuted)),
      ),
    );
  }

  /// The sentence with each hiragana letter colored by its syllable score (PIN-8). When the
  /// scored words do not line up with the sentence, the scored words are shown instead, one
  /// space apart, so no letter Azure scored is left uncolored.
  Widget _letters(QuietRoomTokens t, String sentence, PronunciationResult r) {
    final base = qrText(t, size: 18, height: 1.5);
    TextStyle lit(double score) =>
        base.copyWith(color: scoreColor(t, score), fontWeight: FontWeight.w600);
    final kana = RegExp(r'[ぁ-ゖァ-ヺー]');
    final spans = <TextSpan>[];
    final letters = r.sentenceLetters(sentence);
    final lined =
        letters.every((l) => l.score != null || !kana.hasMatch(l.text));
    final words = r.words.where((w) => !w.isInserted).toList();
    if (lined || words.isEmpty) {
      for (final l in letters) {
        spans.add(TextSpan(
            text: l.text, style: l.score == null ? base : lit(l.score!)));
      }
    } else {
      for (var i = 0; i < words.length; i++) {
        if (i > 0) spans.add(TextSpan(text: ' ', style: base));
        for (final l in words[i].letters) {
          spans.add(TextSpan(text: l.text, style: lit(l.score)));
        }
      }
    }
    return Text.rich(
        key: const ValueKey('speak-letters'), TextSpan(children: spans));
  }

  /// Words the learner said that are not in the sentence, struck through.
  Widget? _inserted(QuietRoomTokens t, PronunciationResult r) {
    final extra = r.words.where((w) => w.isInserted).toList();
    if (extra.isEmpty) return null;
    final base = qrText(t, size: 13.5, color: t.inkMuted);
    return Text.rich(
      key: const ValueKey('speak-inserted'),
      TextSpan(children: [
        TextSpan(text: 'Extra: ', style: base),
        for (var i = 0; i < extra.length; i++) ...[
          if (i > 0) TextSpan(text: ' ', style: base),
          TextSpan(
              text: extra[i].word,
              style: base.copyWith(
                  color: t.clay600, decoration: TextDecoration.lineThrough)),
        ],
      ]),
    );
  }

  Widget _verdictCard(QuietRoomTokens t, SpeakSentence s) {
    final r = _result!;
    final mark = _selfMark;
    final c = _verdictColor(t, r);
    late final String head;
    final body = <Widget>[];
    final scored = r.verdict != Judgement.unverified && r.overall != null;
    if (scored) {
      body
        ..add(Text('Score ${formatScore(r.overall!)}',
            key: const ValueKey('speak-score'),
            style: qrText(t, size: 13.5, weight: FontWeight.w600, color: c)))
        ..add(const SizedBox(height: 6))
        ..add(_letters(t, s.kana, r));
      final extra = _inserted(t, r);
      if (extra != null) {
        body
          ..add(const SizedBox(height: 4))
          ..add(extra);
      }
      body.add(const SizedBox(height: 4));
    }
    switch (r.verdict) {
      case Judgement.correct:
        head = 'That’s it';
        // The kana is on the sentence card above. A kanji surface adds the written form.
        if (s.surface != s.kana) {
          body.add(Text(s.surface, style: qrText(t, size: 13.5)));
        }
      case Judgement.wrong:
        head = 'Not quite';
        body.add(Text(
            'The red letters were furthest off. Play it and try again.',
            style: qrText(t, size: 13.5)));
      case Judgement.close:
        head = 'Close';
        body.add(Text('Nearly there. Did you say the whole sentence?',
            style: qrText(t, size: 13.5)));
      case Judgement.unverified:
        // Being unable to score is not the same as being wrong (PIN-3).
        head = 'Can’t check this one';
        body.add(Text(
            'This attempt couldn’t be scored. It needs the internet and a '
            'microphone. Did you say it?',
            style: qrText(t, size: 13.5)));
    }
    final asks =
        r.verdict == Judgement.close || r.verdict == Judgement.unverified;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: c, width: 1),
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
      ),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head,
              style: qrText(t, size: 14, weight: FontWeight.w600, color: c)),
          const SizedBox(height: 3),
          ...body,
          if (asks && mark == null) ...[
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton(
                onPressed: () => _mark(true),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.sage600, width: 1)),
                child: Text('Got it',
                    style: qrText(t,
                        size: 13, weight: FontWeight.w600, color: t.sage700)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _mark(false),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.border, width: 1)),
                child: Text('Missed it',
                    style: qrText(t,
                        size: 13, weight: FontWeight.w600, color: t.inkMuted)),
              ),
            ]),
          ],
          if (asks && mark != null) ...[
            const SizedBox(height: 8),
            Text(mark ? 'Marked as said.' : 'Marked to try again.',
                style: qrText(t,
                    size: 13,
                    weight: FontWeight.w600,
                    color: mark ? t.sage700 : t.inkMuted)),
          ],
        ],
      ),
    );
  }

  /// The verdict's color: the card's border, its heading and its score line.
  Color _verdictColor(QuietRoomTokens t, PronunciationResult r) =>
      switch (r.verdict) {
        Judgement.correct => t.sage600,
        Judgement.wrong => t.clay600,
        _ => t.amber700,
      };

  /// How many attempts the drill lists under Recent scores.
  static const int _recentShown = 8;

  /// The newest attempts from the device's score log, newest first (PIN-4).
  Widget _recentScores(QuietRoomTokens t) {
    final newest = _log.reversed.take(_recentShown);
    return Column(
      key: const ValueKey('speak-recent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent scores',
            style: qrText(t,
                size: 13, weight: FontWeight.w600, color: t.inkMuted)),
        const SizedBox(height: 4),
        for (final a in newest)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
                '${a.overall == null ? 'no score' : formatScore(a.overall!)}'
                ' · ${a.verdict.name} · ${a.sentence}',
                style: qrText(t, size: 12.5, color: t.inkMuted)),
          ),
      ],
    );
  }
}
