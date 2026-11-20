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
//     share the microphone. Stop and a pause while listening wait for it too, because a
//     recorder start still pending closes its microphone only once it resolves. Cancel on
//     the Checking panel retires the attempt instead: the microphone is already closed, so
//     a new Speak may start while the old score is still out, and that late score is
//     dropped.
//   * The app's own voice: Play waits on `SpeechService.speakAndWait`, so Speak stays
//     disabled until the voice has finished, and Speak stops any voice before the
//     microphone opens.
//   * The app going to the background (`paused`) retires the attempt and closes the
//     microphone, so no check runs behind the app.
//   * One position counter in the header. The tally waits for the end of the set, which
//     shows it on an end card instead of wrapping back to the first sentence.
//
// 🚨 NOTHING THAT CANNOT BE SCORED IS EVER MARKED WRONG (PIN-3).
//   * `correct` is marked right and shows the score.
//   * `close` shows the score in amber, then asks the learner: "Got it" or "Missed it".
//   * `wrong` is marked wrong and shows the score. Only a real Azure score can say wrong.
//   * `unverified` (no microphone, no speech, no network, a failed sign-in or call) asks
//     the same self-check question. The Got it or Missed it is kept with the attempt in
//     the score log, so no self-mark is lost.
// Every scored result shows the sentence with each hiragana letter colored by its syllable
// score (PIN-8). Every attempt's sentence, scores and verdict go to the study store as a
// `speak_score` event, which syncs with the account (plan 2026-11-19, Task 13, PIN-16), and the
// newest are listed under "Recent scores", so the operator can tune the cutoffs (PIN-4).
//
// The study record (plan 2026-11-02, Task 11). Each sentence belongs to a grammar point and
// one of its examples (`ex<i>`) or practice items (`p<i>`). One `Attempt` per scored or
// self-marked sentence goes to the [AttemptRecorder] with `Source.sayIt`, the Say-it track,
// which never counts toward the four clears and never moves the schedule (D4). The grade is
// the score log's own (`sayItGrade`): correct is clear, close is hinted, wrong is wrong, all
// written when the score lands; an unverified result writes only once marked, Got it as self
// and Missed it as unscored, because unverified is never wrong. A self-mark after a close
// stays in the score log only: the close already wrote its attempt. `SpeakScoreLog` stays as
// the tuning aid beside the record, as its own event kind that never reaches the replay.

import 'package:flutter/material.dart';

import '/components/pages/quiet_room_mastery/drill_recorder.dart';
import '/components/pages/quiet_room_mastery/item_catalog.dart'
    show kSayItTemplate;
import '/components/pages/quiet_room_mastery/jp_event.dart';
import '/components/pages/quiet_room_mastery/jp_store.dart'
    show JpStore, kLocalTieBump;
import '/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show sharedJpStore;
import '/components/pages/quiet_room_mastery/speak_lesson_events.dart'
    show importSpeakAndLessonPrefs;
import '/components/pages/quiet_room_mastery/study_export.dart' show sayItGrade;
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

/// One sentence of the drill: the hiragana shown and scored, its kanji surface, and English,
/// with the grammar point and the probe it came from.
class SpeakSentence {
  const SpeakSentence({
    required this.kana,
    required this.surface,
    required this.en,
    this.itemId,
    this.probeId,
  });

  final String kana;
  final String surface;
  final String en;

  /// The grammar point's id (`mari.L26.1`); null for a point with no id, which is not logged.
  final String? itemId;

  /// The example (`ex<i>`) or practice item (`p<i>`) of the point, as the catalog names it.
  /// The forms of one combined example share it.
  final String? probeId;
}

/// Several forms joined in one example: いこう／たべよう／しよう／こよう.
const String _joiner = '／';

/// Splits a hiragana text and its twin on ／ into one [SpeakSentence] per form. When the
/// two sides do not split alike, the whole pair is one sentence. The English splits
/// alongside (see [splitEnglish]). When it cannot, every form keeps the whole English.
Iterable<SpeakSentence> _sentencesOf(String jp, String ruby, String en,
    {String? itemId, String? probeId}) {
  final kanaParts = jp.split(_joiner);
  final rubyParts = ruby.split(_joiner);
  final pairs =
      kanaParts.length == rubyParts.length ? rubyParts : <String>[ruby];
  final ens = splitEnglish(en, pairs.length) ?? [for (final _ in pairs) en];
  return [
    for (var i = 0; i < pairs.length; i++)
      SpeakSentence(
        kana: rubyKana(pairs[i]),
        surface: rubySurface(pairs[i]),
        en: ens[i],
        itemId: itemId,
        probeId: probeId,
      )
  ];
}

/// The English of a combined example cut into [n] parts, one per form, or null when no
/// join gives exactly [n]. The joins are tried in order: ／, a spaced slash, a sentence end,
/// then a comma. In a comma list whose first part carries a lead (passive of よむ, たべる),
/// the bare items after it take that lead too.
List<String>? splitEnglish(String en, int n) {
  if (n < 2) return null;
  final sentenceEnd = RegExp(r'([.!?])\s+');
  final joins = <List<String> Function(String)>[
    (e) => e.split(_joiner),
    (e) => e.split(RegExp(r'\s+/\s+')),
    (e) =>
        e.replaceAllMapped(sentenceEnd, (m) => '${m[1]}\u0000').split('\u0000'),
    (e) => _sharedLead(e.split(RegExp(r',\s+'))),
  ];
  for (final join in joins) {
    final parts = [
      for (final p in join(en))
        if (p.trim().isNotEmpty) p.trim()
    ];
    if (parts.length == n) return parts;
  }
  return null;
}

/// passive of よむ, たべる becomes passive of よむ, passive of たべる. Only when every later
/// part is one bare word and the first part has a lead before its own item.
List<String> _sharedLead(List<String> parts) {
  if (parts.length < 2) return parts;
  final first = parts.first.trim();
  final cut = first.lastIndexOf(' ');
  final rest = parts.skip(1).map((p) => p.trim()).toList();
  if (cut <= 0 || rest.any((p) => p.contains(' '))) return parts;
  final lead = first.substring(0, cut + 1);
  return [first, for (final p in rest) '$lead$p'];
}

/// Point by point, in the order the lesson teaches them: each point's examples, then
/// its practice items with the answer in the blank. An example that joins forms
/// with ／ gives one sentence per form, and no sentence contains ／.
List<SpeakSentence> lessonSentences(Map<String, dynamic> lesson) {
  final out = <SpeakSentence>[];
  for (final p in (lesson['points'] as List).cast<Map<String, dynamic>>()) {
    final id = p['id'] as String?;
    final examples =
        (p['examples'] as List? ?? const []).cast<Map<String, dynamic>>();
    for (var i = 0; i < examples.length; i++) {
      final e = examples[i];
      final jp = e['jp'] as String;
      out.addAll(_sentencesOf(
          jp, e['jp_ruby'] as String? ?? jp, e['en'] as String? ?? '',
          itemId: id, probeId: 'ex$i'));
    }
    final practice =
        (p['practice'] as List? ?? const []).cast<Map<String, dynamic>>();
    for (var i = 0; i < practice.length; i++) {
      final q = practice[i];
      final answer = q['answer'] as String;
      final prompt = q['prompt'] as String;
      final kana = prompt.replaceAll('＿＿', answer);
      final ruby = (q['prompt_ruby'] as String? ?? prompt)
          .replaceAll('＿＿', q['answer_ruby'] as String? ?? answer);
      out.addAll(_sentencesOf(kana, ruby, q['en'] as String? ?? '',
          itemId: id, probeId: 'p$i'));
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

/// One spoken attempt, as the score log keeps it (the body of a `speak_score` event).
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
    this.selfMark,
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

  /// The learner's own mark after a close or unverified result: true for Got it, false for
  /// Missed it, null when the drill scored it or nothing was marked.
  final bool? selfMark;

  /// This attempt with the learner's own mark.
  SpeakAttempt marked(bool gotIt) => SpeakAttempt(
        sentence: sentence,
        verdict: verdict,
        at: at,
        overall: overall,
        accuracy: accuracy,
        fluency: fluency,
        completeness: completeness,
        words: words,
        selfMark: gotIt,
      );

  /// The attempt's identity: one sentence at one instant, whatever zone [at] was read in.
  /// Every event of one attempt shares it (`SpeakScoreLog.fromEvents`).
  String get identityKey => '${at.toUtc().toIso8601String()}\u0000$sentence';

  static const String _gotIt = 'got_it';
  static const String _missedIt = 'missed_it';

  Map<String, Object?> toJson() => {
        'sentence': sentence,
        'verdict': verdict.name,
        // UTC with its offset, so another device reads the same instant (the log syncs).
        'at': at.toUtc().toIso8601String(),
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
        'selfMark': switch (selfMark) {
          true => _gotIt,
          false => _missedIt,
          null => null,
        },
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
      selfMark: switch (raw['selfMark']) {
        _gotIt => true,
        _missedIt => false,
        _ => null,
      },
    );
  }
}

/// Every attempt's sentence, scores and verdict, oldest first, so the operator can tune the
/// cutoffs from real scores (PIN-4). The log lives in the study store as `speak_score` events,
/// so it syncs with the account (plan 2026-11-19, Task 13, PIN-16; speak_lesson_events.dart).
class SpeakScoreLog {
  /// The SharedPreferences key an older build kept the log under. The store's one-time import
  /// reads it (`importSpeakAndLessonPrefs`); nothing writes it any more.
  static const String prefsKey = 'jp.speak.scores';

  /// The newest attempts shown. The store keeps every event (the log is append-only); older
  /// attempts drop off the list.
  static const int keep = 200;

  /// The log as [events] hold it, oldest first by the attempt's time: one entry per attempt
  /// (one sentence at one moment), from its latest event, so a self-mark replaces the entry it
  /// marks. An entry this build cannot read is skipped. The newest [keep] are kept. Pure.
  static List<SpeakAttempt> fromEvents(Iterable<JpEvent> events) {
    final latest = <String, (JpEvent, SpeakAttempt)>{};
    for (final e in events) {
      if (e.kind != JpEventKind.speakScore) continue;
      final a = SpeakAttempt.fromJson(e.body);
      if (a == null) continue;
      final old = latest[a.identityKey];
      if (old == null || compareEvents(e, old.$1) > 0) {
        latest[a.identityKey] = (e, a);
      }
    }
    final rows = latest.values.toList()
      ..sort((x, y) {
        final byAt = x.$2.at.compareTo(y.$2.at);
        return byAt != 0 ? byAt : compareEvents(x.$1, y.$1);
      });
    final list = [for (final r in rows) r.$2];
    if (list.length > keep) list.removeRange(0, list.length - keep);
    return list;
  }

  /// The log in [store], after the one-time import of the old SharedPreferences log. Never
  /// throws: an unreadable store reads as empty. A failed import still reads the store, so
  /// synced scores and a score that just landed still show (the writers report the failure).
  static Future<List<SpeakAttempt>> load(JpStore store) async {
    try {
      await importSpeakAndLessonPrefs(store);
    } catch (_) {
      // The import runs again on the next call, because its flag stays unset.
    }
    try {
      return fromEvents(await store.speakScores());
    } catch (_) {
      return [];
    }
  }

  /// Reports a failed score log write. The log syncs with the account (PIN-16), so a lost
  /// write is lost synced data and is never silent (S4). The drill still keeps running.
  static void reportFailure(Object e, StackTrace st) =>
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'say-it score log',
          context: ErrorDescription('while saving a say-it score')));

  /// Runs the one-time import and reports a failure. A failed import never skips the write
  /// after it: the import runs again on the next call, because its flag stays unset.
  static Future<void> _importReported(JpStore store) async {
    try {
      await importSpeakAndLessonPrefs(store);
    } catch (e, st) {
      reportFailure(e, st);
    }
  }

  /// Logs [a] as a `speak_score` event at its own time and returns the log as saved. Never
  /// throws: a failed save is reported, keeps the drill running and returns what could be
  /// read. The drill chains its saves, so two never overlap.
  static Future<List<SpeakAttempt>> add(JpStore store, SpeakAttempt a) async {
    await _importReported(store);
    try {
      await store.recordSpeakScore(a.toJson(), atUtc: a.at.toUtc());
    } catch (e, st) {
      reportFailure(e, st);
    }
    return load(store);
  }

  /// Keeps the learner's Got it or Missed it on the logged attempt [a]: a second event with
  /// the marked entry, at [nowUtc] (the store's clock by default) and always after [a]'s own
  /// time, so the mark wins. An attempt whose own save failed still gets its entry this way,
  /// so no mark is lost. Never throws.
  static Future<List<SpeakAttempt>> mark(
      JpStore store, SpeakAttempt a, bool gotIt,
      {DateTime? nowUtc}) async {
    await _importReported(store);
    try {
      final at = a.at.toUtc();
      var markAt = (nowUtc ?? store.clock()).toUtc();
      if (!markAt.isAfter(at)) markAt = at.add(kLocalTieBump);
      await store.recordSpeakScore(a.marked(gotIt).toJson(), atUtc: markAt);
    } catch (e, st) {
      // As in add: a lost mark is reported and never blocks the drill.
      reportFailure(e, st);
    }
    return load(store);
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
    this.speech,
    this.recorder,
    this.store,
  });

  /// The grammar lesson number, as in `grammar[].lesson`.
  final int? lesson;

  /// Test seams. Null plays and stops the voice with [SpeechService.instance], records with
  /// the real microphone, and signs in through Firebase. [play], when set, replaces only
  /// Play's voice. The stop before Speak still goes to [speech].
  final SpeakPlay? play;
  final SpeakServiceFactory? newService;
  final CallerAuth? callerAuth;
  final SpeechService? speech;

  /// Where the Say-it attempts go. Null writes to the app's study store, with one recorder
  /// per visit to the screen.
  final AttemptRecorder? recorder;

  /// Where the score log goes, as `speak_score` events. Null uses the app's one shared store
  /// (`sharedJpStore`).
  final JpStore? store;

  static String routeName = 'quietRoomSpeak';
  static String routePath = '/quietRoomSpeak';

  @override
  State<QuietRoomSpeakWidget> createState() => _QuietRoomSpeakWidgetState();
}

class _QuietRoomSpeakWidgetState extends State<QuietRoomSpeakWidget>
    with WidgetsBindingObserver {
  late final PronunciationService _svc;
  late final SpeechService _voice = widget.speech ?? SpeechService.instance;
  late final AttemptRecorder _recorder = widget.recorder ?? AttemptRecorder();

  int _index = 0;

  /// True once Next has passed the last sentence: the end card shows the tally.
  bool _done = false;

  /// True from Speak until the check returns, or until a retire on the Checking panel
  /// (Cancel, a pause) frees it early. A retire while listening (Stop, a pause) waits for
  /// the check. Speak and Next wait meanwhile, so one check owns the microphone at a time.
  bool _busy = false;

  /// True once this check's microphone has opened, and [_scoring] once it has closed again:
  /// the recording is on its way to Azure.
  bool _micOpened = false;
  bool _scoring = false;

  /// True after Stop or a pause. The check winds down and its result is dropped.
  bool _stopped = false;

  /// The check in flight, so a retire while listening can wait for it. The service marks a
  /// check cancelled only once its recorder start has resolved, so a retire that freed Speak
  /// at once could let a second check open the microphone the first is about to close.
  /// A Cancel on Checking leaves the dropped check here until its score lands, so Speak
  /// clears it first: a Stop before the new microphone opens must not wait on that score.
  Future<PronunciationResult>? _check;
  bool _heardVoice = false;

  /// True while Play's voice is speaking. Play and Speak are disabled meanwhile, so the
  /// microphone never hears the app's own voice.
  bool _playing = false;

  /// The last attempt on this sentence, or null before one.
  PronunciationResult? _result;

  /// The logged entry for [_result], so a self-mark lands on the attempt it answers.
  SpeakAttempt? _logged;

  /// The sentence [_result] answers, so its self-mark is recorded against the same probe.
  SpeakSentence? _loggedSentence;

  /// The learner's own mark after a self-check: true for "Got it".
  bool? _selfMark;

  int _seen = 0;
  int _right = 0;

  /// Bumped by every Speak and every retire (Stop, Cancel, a pause, dispose). A check whose
  /// attempt is no longer current drops its result instead of showing or keeping it.
  int _attempt = 0;

  /// The score log from the study store, oldest first.
  List<SpeakAttempt> _log = const [];

  /// Every log write runs after the one before, so a self-mark never races the save of the
  /// attempt it marks.
  Future<void> _logWrites = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final make =
        widget.newService ?? (signIn) => PronunciationService(signIn: signIn);
    _svc = make(_signIn);
    _svc.listening.addListener(_onMic);
    // The first read runs on the write chain too, so its one-time import never races a save.
    _writeLog(SpeakScoreLog.load);
  }

  /// The store the score log lives in.
  Future<JpStore> _logStore() async => widget.store ?? await sharedJpStore();

  /// Queues a log write after the ones before it and shows the log it saved. A store that
  /// cannot open loses the write, which is reported, and leaves the list as it was.
  void _writeLog(Future<List<SpeakAttempt>> Function(JpStore store) write) {
    _logWrites = _logWrites.then((_) async {
      try {
        final log = await write(await _logStore());
        if (mounted && log.isNotEmpty) setState(() => _log = log);
      } catch (e, st) {
        // As in SpeakScoreLog.add: the drill keeps running.
        SpeakScoreLog.reportFailure(e, st);
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _attempt++;
    _svc.listening.removeListener(_onMic);
    _svc.dispose();
    _voice.stopSpeaking();
    super.dispose();
  }

  /// The microphone and the voice never run behind the app: a pause retires the attempt.
  /// Inactive and hidden do not, because a permission dialog makes the app inactive too.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _voice.stopSpeaking();
    if (_busy) _retire();
  }

  Future<String?> _say(String text) =>
      widget.play?.call(text) ?? _voice.speakAndWait(text);

  Future<void> _play(SpeakSentence s) async {
    if (_playing || _busy) return;
    setState(() => _playing = true);
    try {
      // Spoken as a pause, the way quiet_room_grammar_widget.dart reads a joined example.
      // speakAndWait returns when the voice says it has finished (or at its safety cap), so
      // Play and Speak stay disabled for the whole sentence, not only for speak()'s cap.
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
      _logged = null;
      _loggedSentence = null;
      _selfMark = null;
      // The check a Cancel on Checking left behind is not this attempt's: a Stop that
      // lands while the voice stop below is pending must not wait for its score.
      _check = null;
    });
    Future<PronunciationResult>? check;
    try {
      // The app's own voice must never reach the microphone: stop it before it opens.
      await _voice.stopSpeaking();
      if (!mounted || attempt != _attempt) return;
      // check() never throws: anything it cannot score comes back unverified (PIN-3).
      check = _check = _svc.check(s.kana);
      final r = await check;
      // Stop, Cancel or a pause retired this attempt while it ran: its result is dropped,
      // not shown, counted or kept.
      if (!mounted || attempt != _attempt) return;
      final entry = SpeakAttempt.of(s.kana, r, DateTime.now());
      setState(() {
        _result = r;
        _logged = entry;
        _loggedSentence = s;
        if (r.verdict == Judgement.correct) {
          _seen++;
          _right++;
        } else if (r.verdict == Judgement.wrong) {
          _seen++;
        }
      });
      _writeLog((store) => SpeakScoreLog.add(store, entry));
      // A scored result is the attempt; an unverified one waits for its self-mark.
      if (r.verdict != Judgement.unverified) _recordSayIt(s, entry);
    } finally {
      // A newer attempt may have cleared or replaced _check by now (after a Cancel on
      // Checking): leave what it holds.
      if (check != null && identical(_check, check)) _check = null;
      // Only the current attempt frees the buttons. A retired one was freed by its retire,
      // and may since have been followed by a newer attempt that still owns them.
      if (mounted && attempt == _attempt) {
        setState(() {
          _busy = false;
          _scoring = false;
        });
      }
    }
  }

  /// Retires the attempt in flight, so its result is dropped, then frees the buttons once
  /// the microphone is closed. Stop, Cancel on Checking, and a pause all end here.
  Future<void> _retire() async {
    final retired = ++_attempt;
    setState(() => _stopped = true);
    // While listening the check still owns the microphone, so the buttons wait for it to
    // return: a recorder start still pending resolves, sees the cancel and closes the
    // microphone it opened. While checking it is already closed, so Speak is free at once
    // and the score still out is dropped when it lands.
    final inFlight = _scoring ? null : _check;
    await _svc.cancel();
    await inFlight;
    if (!mounted || retired != _attempt) return;
    setState(() {
      _busy = false;
      _scoring = false;
      _stopped = false;
    });
  }

  void _mark(bool gotIt) {
    if (_selfMark != null) return;
    final entry = _logged;
    final sentence = _loggedSentence;
    setState(() {
      _selfMark = gotIt;
      _seen++;
      if (gotIt) _right++;
    });
    // Kept with the attempt it answers, after that attempt's own save (no mark is lost).
    if (entry != null) {
      _writeLog((store) => SpeakScoreLog.mark(store, entry, gotIt));
    }
    // An unverified result is recorded once it is marked. A close one already was.
    if (entry != null &&
        sentence != null &&
        entry.verdict == Judgement.unverified) {
      _recordSayIt(sentence, entry.marked(gotIt));
    }
  }

  /// Writes one Say-it attempt for [s], graded as the score log grades [entry], at the
  /// instant the sentence was spoken. Never waits and never fails the drill. A write that
  /// is lost (the recorder has reported it) tells the learner through [_notSaved], so the
  /// result on screen is never taken for a saved attempt.
  void _recordSayIt(SpeakSentence s, SpeakAttempt entry) {
    final itemId = s.itemId, probeId = s.probeId;
    if (itemId == null || probeId == null) return;
    _recorder
        .record(DrillAnswer(
      itemId: itemId,
      probeId: probeId,
      template: kSayItTemplate,
      grade: sayItGrade(entry),
      production: true,
      selfGraded: false,
      sayIt: true,
      atUtc: entry.at,
    ))
        .then((a) {
      if (a == null) _notSaved();
    });
  }

  /// Shown when a Say-it attempt did not reach the study record (S4: the learner sees it).
  void _notSaved() {
    if (!mounted) return;
    final t = QuietRoomTokens.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content:
          Text(kAnswerNotSaved, style: qrText(t, size: 13, color: t.onBrand)),
      duration: const Duration(seconds: 5),
    ));
  }

  /// Ignored during a check, so a pending result is never credited to the next sentence.
  /// Past the last sentence the set ends on the tally card, and never wraps silently.
  void _next(int count) {
    if (_busy) return;
    setState(() {
      if (_index + 1 >= count) {
        _done = true;
      } else {
        _index++;
      }
      _result = null;
      _logged = null;
      _loggedSentence = null;
      _selfMark = null;
    });
  }

  /// Starts the set and its tally again from the first sentence.
  void _again() {
    setState(() {
      _index = 0;
      _done = false;
      _seen = 0;
      _right = 0;
      _result = null;
      _logged = null;
      _loggedSentence = null;
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
        final title = Text('Speak lesson ${lesson['lesson']}',
            style: qrTitle(t, size: 22));
        if (_done) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              title,
              const SizedBox(height: 16),
              _endCard(t, sentences.length),
              if (_log.isNotEmpty) ...[
                const SizedBox(height: 18),
                _recentScores(t),
              ],
            ],
          );
        }
        final index = _index.clamp(0, sentences.length - 1);
        final s = sentences[index];
        final last = index == sentences.length - 1;
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
                Expanded(child: title),
                // The one position counter. The tally waits for the end card.
                Text('${index + 1} of ${sentences.length}',
                    key: const ValueKey('speak-position'),
                    style: qrText(t,
                        size: 14, weight: FontWeight.w600, color: t.inkMuted)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Play it, then say it once.',
                style: qrText(t, size: 13.5, color: t.inkMuted)),
            const SizedBox(height: 16),
            QrCard(
              // A fixed minimum height, so a short sentence does not pull Next up.
              child: ConstrainedBox(
                key: const ValueKey('speak-sentence-box'),
                constraints: BoxConstraints(minHeight: _sentenceBoxMin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.kana,
                        style: qrText(t,
                            size: _kanaSize, height: _kanaLineHeight)),
                    if (s.en.isNotEmpty) ...[
                      const SizedBox(height: _enGap),
                      Text(s.en,
                          style: qrText(t,
                              size: _enSize,
                              height: _enLineHeight,
                              color: t.inkMuted)),
                    ],
                  ],
                ),
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
                child: Text(last ? 'Finish' : 'Next sentence',
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
                onPressed: _retire,
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

  /// The recording is on its way to Azure. Cancel retires the attempt, so the score that
  /// lands later is dropped and Speak is free at once.
  Widget _checkingPanel(QuietRoomTokens t) {
    return Container(
      decoration: _panel(t),
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Checking…',
              style: qrText(t,
                  size: 13, weight: FontWeight.w600, color: t.inkMuted)),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _retire,
            style: TextButton.styleFrom(
                minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
            child: Text('Cancel',
                style: qrText(t,
                    size: 13, weight: FontWeight.w600, color: t.brand600)),
          ),
        ],
      ),
    );
  }

  /// The end of the set: the tally of what was scored or self-marked, and Go again.
  Widget _endCard(QuietRoomTokens t, int count) {
    return QrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('End of the lesson',
              style: qrText(t, size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('You went through all $count sentences.',
              style: qrText(t, size: 13.5, color: t.inkMuted)),
          const SizedBox(height: 10),
          if (_seen == 0)
            Text('Nothing was scored this time.',
                style: qrText(t, size: 13.5, color: t.inkMuted))
          else ...[
            Text('$_right of $_seen',
                key: const ValueKey('speak-tally'),
                style: qrTitle(t, size: 22)),
            const SizedBox(height: 2),
            Text('said right, scored or marked by you',
                style: qrText(t, size: 13, color: t.inkMuted)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: QuietRoomMetrics.targetMin,
            child: ElevatedButton(
              onPressed: _again,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.brand600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
              child: Text('Go again',
                  style: qrText(t,
                      size: 15, weight: FontWeight.w600, color: t.onBrand)),
            ),
          ),
        ],
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

  /// The sentence text metrics: the kana line, the gap, and the English line. The box's
  /// least height is built from them, so the two cannot drift apart.
  static const double _kanaSize = 20;
  static const double _kanaLineHeight = 1.5;
  static const double _enGap = 6;
  static const double _enSize = 13.5;
  static const double _enLineHeight = 1.4;

  /// The sentence box's least height: three lines of kana and two of English, so Next
  /// stays put from sentence to sentence. A taller sentence still grows the box. Each
  /// line is rounded up as the engine draws it, on whole pixels.
  static final double _sentenceBoxMin =
      3 * (_kanaSize * _kanaLineHeight).ceilToDouble() +
          _enGap +
          2 * (_enSize * _enLineHeight).ceilToDouble();

  /// How many attempts the drill lists under Recent scores.
  static const int _recentShown = 8;

  /// The newest attempts from the score log, newest first (PIN-4).
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
                ' · ${a.verdict.name}'
                '${switch (a.selfMark) {
                  true => ' · got it',
                  false => ' · missed it',
                  null => '',
                }}'
                ' · ${a.sentence}',
                style: qrText(t, size: 12.5, color: t.inkMuted)),
          ),
      ],
    );
  }
}
