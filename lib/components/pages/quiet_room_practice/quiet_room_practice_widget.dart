// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Speaking practice. Shows the illustration from the source sheet, asks the learner to say the
// word, listens, and reports what it heard.
//
// 🚨 IT IS A RECALL DRILL, NOT PRONUNCIATION SCORING, and the copy says so. speech_to_text checks
// WHICH word was produced, never how well it was pronounced. See speech_service.dart.
//
// THE HINT LADDER is deliberately ordered from least to most revealing, and the learner chooses
// how far down it to go: English gloss, then the conjugation group, then the first mora, then the
// whole answer. Giving the answer as the only option makes the hint worthless as a hint.
//
// 🚨 THE TALLY IS HONEST (PIN-3). Every listen hands on a [PracticeResult] that carries the hint
// level and whether the answer was showing. Only a checked listen counts:
//   * `correct` with no hint is right; with a hint taken it is "with help".
//   * `close` is "with help", never right.
//   * `wrong` is missed, and so is any answer given while the whole answer was showing.
//   * `unverified` (no microphone, nothing heard, a kanji transcript) never counts by itself.
//     It asks the same self-check question as the speak drill, "Got it" or "Missed it", and
//     only the learner's mark counts.
//
// One listen at a time: Speak first stops the app's own voice, Next waits while the microphone
// is open, Stop and the app going to the background retire the listen so a late result is
// dropped, never shown.
//
// THE DECK is the lesson's illustrated words shuffled once, each shown once. The header shows
// the position, and the end of the deck shows the tally and Go again.
//
// Quiet Room: the illustration is the one loud object on the screen. Everything else -- the
// controls, the hints, the chrome -- stays inside the quiet band until the learner asks for it.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/quiet_room.dart';
import 'listening_bars.dart';
import 'speech_service.dart';

/// Where one result lands in the tally.
enum PracticeTally { right, hinted, missed, uncounted }

/// The hint ladder for [word], least revealing first. The last step is the whole answer.
List<String> practiceHintSteps(Map<String, dynamic> word) {
  final kana = word['kana'] as String;
  final group = word['verbGroup'] as int?;
  return <String>[
    'Meaning: ${word['gloss']}',
    if (group != null)
      'Group ${[
        '',
        'I',
        'II',
        'III'
      ][group]}${word['groupUncertain'] == true ? ', though the ます form alone cannot settle it' : ''}',
    'Starts with 「${kana.characters.first}」',
    kana,
  ];
}

/// One listen on one word, as the screen hands it on.
class PracticeResult {
  const PracticeResult({
    required this.word,
    required this.speech,
    required this.hintLevel,
    required this.revealed,
    this.selfMark,
  });

  /// The word card as the lesson file holds it (kana, gloss, image, ...).
  final Map<String, dynamic> word;
  final SpeechResult speech;

  /// How far down the hint ladder the learner had gone: 0 none, up to the ladder's length.
  final int hintLevel;

  /// True when the hint level had reached the last step, the whole answer.
  final bool revealed;

  /// The learner's own mark after a self-check: true for "Got it". Null before one, and
  /// always null for a checked listen.
  final bool? selfMark;

  /// True when the machine could not check the listen, so the learner is asked.
  bool get asksSelfCheck => speech.judgement == Judgement.unverified;

  PracticeResult marked(bool gotIt) => PracticeResult(
      word: word,
      speech: speech,
      hintLevel: hintLevel,
      revealed: revealed,
      selfMark: gotIt);

  PracticeTally get tally {
    final said = switch (speech.judgement) {
      Judgement.correct => true,
      Judgement.close => true,
      Judgement.wrong => false,
      Judgement.unverified => selfMark,
    };
    if (said == null) return PracticeTally.uncounted;
    if (!said || revealed) return PracticeTally.missed;
    if (speech.judgement == Judgement.close || hintLevel > 0) {
      return PracticeTally.hinted;
    }
    return PracticeTally.right;
  }
}

class QuietRoomPracticeWidget extends StatefulWidget {
  const QuietRoomPracticeWidget({
    super.key,
    this.lesson,
    this.speech,
    this.random,
    this.onResult,
  });

  /// Null practises every lesson at once.
  final int? lesson;

  /// Test seams. Null listens and speaks with [SpeechService.instance] and shuffles with a
  /// fresh [Random].
  final SpeechService? speech;
  final Random? random;

  /// Called with every result the screen keeps: once per checked or unchecked listen, and
  /// again with the learner's mark after a self-check.
  final ValueChanged<PracticeResult>? onResult;

  static String routeName = 'quietRoomPractice';
  static String routePath = '/quietRoomPractice';

  @override
  State<QuietRoomPracticeWidget> createState() =>
      _QuietRoomPracticeWidgetState();
}

class _QuietRoomPracticeWidgetState extends State<QuietRoomPracticeWidget>
    with WidgetsBindingObserver {
  late final SpeechService _speech = widget.speech ?? SpeechService.instance;
  late final Random _rng = widget.random ?? Random();

  /// The lesson's illustrated words, shuffled once. Each is shown once per pass.
  List<Map<String, dynamic>> _deck = const [];
  int _pos = 0;
  bool _finished = false;
  String? _error;

  Map<String, dynamic>? get _card =>
      _deck.isEmpty || _finished ? null : _deck[_pos];

  int _hintLevel =
      0; // 0 none, then one per ladder step; the last step is the answer
  bool _listening = false;

  /// Bumped by every Speak, Stop and pause. A listen whose attempt is no longer current drops
  /// its result instead of showing it.
  int _attempt = 0;

  /// 🚨 Set from SpeechService.lastError. Without it a recogniser failure was indistinguishable
  /// from a slow answer: the drill waited out its whole timeout and then said "could not
  /// check", which reads as the learner's fault rather than the device's.
  String? _micError;
  PracticeResult? _result;

  int _right = 0;
  int _hinted = 0;
  int _missed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attempt++;
    _speech.cancel();
    _speech.stopSpeaking();
    super.dispose();
  }

  /// The microphone never stays open behind the app: a listen in flight is retired on pause.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _speech.stopSpeaking();
    if (_listening) _stopListening();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/lessons/jp_lessons.json');
      final d = json.decode(raw) as Map<String, dynamic>;
      final lessons = (d['lessons'] as List).cast<Map<String, dynamic>>();
      final pool = <Map<String, dynamic>>[];
      for (final l in lessons) {
        if (widget.lesson != null && l['lesson'] != widget.lesson) continue;
        for (final i in (l['items'] as List).cast<Map<String, dynamic>>()) {
          // Only illustrated words can be a picture prompt.
          if (i['image'] != null) pool.add({...i, 'lesson': l['lesson']});
        }
      }
      if (!mounted) return;
      if (pool.isEmpty) {
        setState(() => _error = 'No illustrated words in this lesson.');
        return;
      }
      setState(() => _deck = pool..shuffle(_rng));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the vocabulary.');
    }
  }

  void _clearCard() {
    _hintLevel = 0;
    _result = null;
    _micError = null;
  }

  /// Ignored while listening, so a pending result is never credited to the next word.
  void _next() {
    if (_deck.isEmpty || _listening) return;
    setState(() {
      _clearCard();
      if (_pos + 1 >= _deck.length) {
        _finished = true;
      } else {
        _pos++;
      }
    });
  }

  void _again() {
    setState(() {
      _clearCard();
      _deck = List.of(_deck)..shuffle(_rng);
      _pos = 0;
      _finished = false;
      _right = _hinted = _missed = 0;
    });
  }

  void _count(PracticeTally t) {
    switch (t) {
      case PracticeTally.right:
        _right++;
      case PracticeTally.hinted:
        _hinted++;
      case PracticeTally.missed:
        _missed++;
      case PracticeTally.uncounted:
        break;
    }
  }

  void _keep(PracticeResult r) {
    setState(() {
      _result = r;
      _count(r.tally);
    });
    widget.onResult?.call(r);
  }

  Future<void> _listen() async {
    final card = _card;
    if (card == null || _listening) return;
    final attempt = ++_attempt;
    setState(() {
      _listening = true;
      _result = null;
      _heardVoice = false;
      _micError = null;
    });
    try {
      // The microphone must not hear the app's own voice.
      await _speech.stopSpeaking();
      if (!mounted || attempt != _attempt) return;
      final r = await _speech.listenOnce(
        expectedKana: card['kana'] as String,
        kanjiForms: ((card['kanji'] as List?) ?? const []).cast<String>(),
      );
      // Stop or a pause retired this attempt while it ran: its result is dropped.
      if (!mounted || attempt != _attempt) return;
      _keep(PracticeResult(
        word: card,
        speech: r,
        hintLevel: _hintLevel,
        revealed: _hintLevel >= practiceHintSteps(card).length,
      ));
    } finally {
      // Leaving the panel open on a throw would strand the drill mid-listen.
      if (mounted && attempt == _attempt) {
        setState(() {
          _listening = false;
          _micError = _speech.lastError;
        });
      }
    }
  }

  /// Retires the listen first, so its result is dropped, then closes the microphone.
  Future<void> _stopListening() async {
    _attempt++;
    setState(() => _listening = false);
    await _speech.cancel();
  }

  void _mark(bool gotIt) {
    final r = _result;
    if (r == null || !r.asksSelfCheck || r.selfMark != null) return;
    _keep(r.marked(gotIt));
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        surfaceTintColor: t.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.ink, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: Text(
          _deck.isEmpty
              ? 'Say it'
              : _finished
                  ? 'Done'
                  : '${_pos + 1} of ${_deck.length}',
          key: const ValueKey('practice-position'),
          style: GoogleFonts.schibstedGrotesk(
              fontSize: 14, fontWeight: FontWeight.w600, color: t.inkMuted),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _error != null
            ? Center(
                child: Text(_error!,
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 14, color: t.clay600)))
            : _finished
                ? _end(t)
                : _card == null
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(t.inkSubtle)),
                        ),
                      )
                    : _body(t, _card!),
      ),
    );
  }

  /// The end of the deck: the tally, and Go again.
  Widget _end(QuietRoomTokens t) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QuietRoomMetrics.readMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(
              'That’s all ${_deck.length} words',
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 22 * -0.015,
                color: t.inkStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_right on your own · $_hinted with help · $_missed missed',
              key: const ValueKey('practice-tally'),
              style:
                  GoogleFonts.schibstedGrotesk(fontSize: 14, color: t.inkMuted),
            ),
            const SizedBox(height: 22),
            Center(
              child: TextButton(
                onPressed: _again,
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
                child: Text('Go again',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.brand600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(QuietRoomTokens t, Map<String, dynamic> card) {
    final last = _pos + 1 >= _deck.length;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QuietRoomMetrics.readMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(
              'What is this?',
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 22 * -0.015,
                color: t.inkStrong,
              ),
            ),
            const SizedBox(height: 4),
            Text('Say it in Japanese.',
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 13.5, color: t.inkMuted)),
            const SizedBox(height: 16),

            // The one loud object -- but capped. Full-bleed at 265:200 it swallowed the
            // screen on anything wider than a phone and pushed the controls below the fold.
            Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 294, maxHeight: 222),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surfaceRaised,
                    border: Border.all(color: t.border, width: 1),
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusMd),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 265 / 200,
                    // 🚨 Labelled as the PROMPT, never with the word. The gloss here would
                    // read the answer aloud to exactly the learner being asked for it.
                    child: Image.asset(card['image'] as String,
                        fit: BoxFit.contain,
                        semanticLabel: 'Picture prompt for this word'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_listening) _listeningPanel(t) else _micRow(t, card),
            if (_micError != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: t.clay600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _micError!,
                      key: const ValueKey('practice-mic-error'),
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 12.5, color: t.clay600),
                    ),
                  ),
                ],
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 14),
              _verdict(t, card)
            ],

            const SizedBox(height: 18),
            _hints(t, card),

            const SizedBox(height: 22),
            Center(
              child: TextButton(
                // Disabled while listening, so a listen never lands on the next word.
                onPressed: _listening ? null : _next,
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
                child: Text(last ? 'Finish' : 'Next word',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _listening ? t.inkSubtle : t.brand600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// While the microphone is open. The label is deliberately different depending on
  /// whether the bars mean anything: on a platform that reports amplitude it says the
  /// voice is being heard, and where it does not it only claims to be listening.
  bool _heardVoice = false;

  Widget _listeningPanel(QuietRoomTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderControl, width: 1),
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
      ),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Column(
        children: [
          ListeningBars(
            level: _speech.level,
            onRealDetected: () {
              if (mounted && !_heardVoice) setState(() => _heardVoice = true);
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_heardVoice ? 'Hearing you' : 'Listening',
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.inkMuted)),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _stopListening,
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text('Stop',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.brand600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _micRow(QuietRoomTokens t, Map<String, dynamic> card) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: QuietRoomMetrics.targetMin,
            child: ElevatedButton.icon(
              onPressed: _listening ? null : _listen,
              icon: Icon(_listening ? Icons.graphic_eq : Icons.mic_none,
                  size: 20, color: t.onBrand),
              label: Text(_listening ? 'Listening…' : 'Speak',
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.onBrand)),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.brand600,
                disabledBackgroundColor: t.brand400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: QuietRoomMetrics.targetMin,
          width: QuietRoomMetrics.targetMin,
          child: OutlinedButton(
            onPressed: _listening
                ? null
                : () async {
                    final err = await _speech.speak(card['kana'] as String);
                    if (err != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err,
                            style: GoogleFonts.schibstedGrotesk(fontSize: 13)),
                        duration: const Duration(seconds: 5),
                      ));
                    }
                  },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(
                  color: t.borderControl,
                  width: QuietRoomMetrics.strokeControl),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(QuietRoomMetrics.radiusSm)),
            ),
            child: Icon(Icons.volume_up_outlined, size: 20, color: t.ink),
          ),
        ),
      ],
    );
  }

  Widget _verdict(QuietRoomTokens t, Map<String, dynamic> card) {
    final r = _result!;
    final s = r.speech;
    final kana = card['kana'] as String;
    late final Color c;
    late final String head;
    late final String body;
    switch (s.judgement) {
      case Judgement.correct:
        c = t.sage600;
        head = 'That’s it';
        body = kana;
      case Judgement.close:
        // Close is a hint from the recogniser, not a right answer (PIN-3).
        c = t.amber700;
        head = 'Close';
        body = 'Heard “${s.heard}” · answer $kana';
      case Judgement.wrong:
        c = t.clay600;
        head = 'Not quite';
        body = 'Heard “${s.heard}” · answer $kana';
      case Judgement.unverified:
        // Being unable to check is not the same as being wrong, and the copy must not blur them.
        c = t.amber700;
        head = 'Can’t check this one';
        body = s.heard.isEmpty
            ? 'This attempt couldn’t be checked. It needs a microphone and speech '
                'recognition. The answer is $kana. Did you say it?'
            : 'Heard “${s.heard}” in kanji, which can’t be checked against hiragana here. '
                'The answer is $kana. Did you say it?';
    }
    final mark = r.selfMark;
    final note = switch (r.tally) {
      PracticeTally.hinted => s.judgement == Judgement.close && r.hintLevel == 0
          ? 'Close counts as with help, not right.'
          : 'A hint was taken, so this counts as with help.',
      PracticeTally.missed when r.revealed && s.judgement != Judgement.wrong =>
        'The answer was showing, so this counts as missed.',
      _ => null,
    };
    return Container(
      key: const ValueKey('practice-verdict'),
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
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c)),
          const SizedBox(height: 3),
          Text(body,
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 13.5, height: 1.35, color: t.ink)),
          // When the machine genuinely cannot judge, ask the person rather than guess.
          // Scoring a correct answer as wrong is worse than admitting the limit.
          if (r.asksSelfCheck && mark == null) ...[
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton(
                onPressed: () => _mark(true),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.sage600, width: 1),
                    foregroundColor: t.sage700),
                child: Text('Got it',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.sage700)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _mark(false),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.border, width: 1),
                    foregroundColor: t.inkMuted),
                child: Text('Missed it',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.inkMuted)),
              ),
            ]),
          ],
          if (r.asksSelfCheck && mark != null) ...[
            const SizedBox(height: 8),
            Text(mark ? 'Marked as said.' : 'Marked to try again.',
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mark ? t.sage700 : t.inkMuted)),
          ],
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note,
                key: const ValueKey('practice-tally-note'),
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 12.5, color: t.inkMuted)),
          ],
        ],
      ),
    );
  }

  /// Least revealing first. The learner decides how much help to take.
  Widget _hints(QuietRoomTokens t, Map<String, dynamic> card) {
    final steps = practiceHintSteps(card);
    final maxLevel = steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('HINTS',
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 11 * 0.07,
                    color: t.inkMuted)),
            const Spacer(),
            if (_hintLevel < maxLevel)
              TextButton(
                onPressed: () => setState(() => _hintLevel++),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(_hintLevel == 0 ? 'Give me a hint' : 'More',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: t.brand600)),
              ),
          ],
        ),
        if (_hintLevel == 0)
          Text('None taken.',
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 12.5, color: t.inkSubtle))
        else
          ...steps.take(_hintLevel).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: t.surfaceTinted,
                    border: Border.all(color: t.border, width: 1),
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm),
                  ),
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                  child: Text(s,
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 13.5, height: 1.35, color: t.ink)),
                ),
              )),
      ],
    );
  }
}
