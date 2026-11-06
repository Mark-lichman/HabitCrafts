// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The probe widgets (plan 2026-11-02, Task 19): one widget per probe kind, each asking one
// question about one mastery item and handing on one graded draft, a [DrillAnswer] (grade,
// template, hint level, revealed). The session runner writes the draft through an
// [AttemptRecorder]; a widget never writes to the store itself.
//
// | widget             | probe                         | check                               |
// |--------------------|-------------------------------|-------------------------------------|
// | [ChooseProbe]      | a grammar `choose` item       | the picked option                   |
// | [TypedFillProbe]   | a `fill` item, a particle cloze | `checkTypedAnswer` on the caller's item map (accepted forms), hint behind a tap |
// | [WordRecallProbe]  | a word: spoken, typed or card | `SpeechService`, `checkTypedAnswer`, or the learner after the reveal |
// | [ConjugationProbe] | a verb of a conjugation idea  | the learner after the reveal        |
// | [PairProbe]        | a pair, in either direction   | the learner after the reveal        |
// | [TableCellProbe]   | a cell of a table row         | the learner after the reveal        |
// | [SayItProbe]       | one form of a grammar example (Say-it) | `PronunciationService`     |
//
// Every grade comes from `gradeAnswer` (attempt.dart), so the rules hold the same on every
// screen (D17):
//   * 🚨 a hinted answer is hinted, never clear, and earns no credit (PIN-3);
//   * the word hint ladder's last rung shows the answer, so any answer after it is wrong;
//   * on a self-graded probe (conjugation, pair, table cell, word card) Got it or Knew it
//     after the reveal is clear and Missed it or Not yet is wrong (PIN-13); a hint taken
//     before the reveal makes Got it hinted;
//   * unverified is never wrong: a check that could not score asks the learner, Got it is
//     `self`; on the Say-it track Missed it after an unverified check is unscored, as the
//     speak drill grades it (study_export.dart `sayItGrade`);
//   * an empty Check is no attempt.
//
// Each widget reports one answer and then locks, so a probe is never answered twice. A widget
// keeps that lock when it is rebuilt in place (none implements didUpdateWidget), so the session
// runner gives each presentation its own key, built from the entry index and the re-ask count,
// never from the item and probe ids alone: a re-asked item (Task 18, PIN-11) shares both ids
// with its first showing. The speech widgets carry a listen token: a listen or a check that
// lands after the widget has gone, or after Skip, is dropped, and leaving mid-listen cancels
// it. A listen that throws frees the controls and goes to FlutterError.reportError, the route
// the recorder's lost write takes (S4), so the app's handler records it.
//
// A wrong answer never hides the answer (operator ruling 2026-11-05). A draft says whether
// the answer was already on screen (`DrillAnswer.answerShown`: a self-graded reveal, a
// compare, the ladder's last rung); the session moves straight on after such a wrong. After
// any other wrong (a typed or spoken miss, a wrong pick, Show answer) the widget shows the
// full answer, a fill-in as the whole sentence with the missing part filled in and marked,
// and the learner's own answer when there is one, and the session adds one Next.
//
// Every widget shows the item's state pill with its n of 4 clears ([ProbeStatePill]).

import 'dart:async';

import 'package:flutter/material.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import '../quiet_room_practice/pronunciation_service.dart';
import '../quiet_room_practice/speech_service.dart';
import 'attempt.dart';
import 'drill_recorder.dart' show DrillAnswer;
import 'item_catalog.dart';
import 'mastery_rule.dart';

/// Receives the one graded draft a probe widget hands on.
typedef ProbeAnswered = void Function(DrillAnswer answer);

/// The state pill's text: the n of 4 clears (D16), "0 of 4 clears". A New or Learning item
/// shows no state word, so the chip never clashes with the session's section line (operator
/// ruling 2026-11-05); the Mastered and Shaky markers stay. A Shaky item shows its regain
/// clears as a bare count, because regaining also needs the [kRegainGapDays] gap, and a
/// denominator would promise what the gap clause still blocks (as the study record page).
String probeStateLabel(MasteryState s) {
  final n = s.clearCount;
  switch (s.status) {
    case MasteryStatus.neu:
    case MasteryStatus.learning:
      return '$n of $kClearsToMaster clears';
    case MasteryStatus.mastered:
      return 'Mastered · $kClearsToMaster of $kClearsToMaster';
    case MasteryStatus.shaky:
      return 'Shaky · $n ${n == 1 ? 'clear' : 'clears'} toward regaining';
  }
}

/// The item's state and its n of 4, shown at the top of every probe.
class ProbeStatePill extends StatelessWidget {
  const ProbeStatePill({super.key, required this.state});

  final MasteryState state;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final (fill, ink) = switch (state.status) {
      MasteryStatus.neu => (t.surface, t.inkMuted),
      MasteryStatus.learning => (t.surfaceTinted, t.brand600),
      MasteryStatus.mastered => (t.sage100, t.sage700),
      MasteryStatus.shaky => (t.amberSurface, t.amber700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(probeStateLabel(state),
          style: qrText(t, size: 12.5, weight: FontWeight.w600, color: ink)),
    );
  }
}

/// The asset path of a word's picture: the word id is its image stem (D19).
String wordImageAsset(String wordId) => 'assets/lessons/img/$wordId.webp';

/// The default hint ladder for a word, least revealing first; the last rung is the answer.
List<String> wordHintSteps(ProbeDef probe) => [
      if (probe.answer.isNotEmpty)
        'Starts with 「${probe.answer.characters.first}」',
      probe.answer,
    ];

/// The draft of one answer. [selfGraded] defaults to the probe's own flag; the Say-it probe
/// passes false, because the pronunciation score is a machine check (as the speak drill
/// writes it).
DrillAnswer _draft(ItemDef item, ProbeDef probe, Grade grade,
        {int hintLevel = 0,
        bool revealed = false,
        bool sayIt = false,
        bool answerShown = false,
        bool? selfGraded}) =>
    DrillAnswer(
      itemId: item.id,
      probeId: probe.id,
      template: probe.template,
      production: probe.production,
      selfGraded: selfGraded ?? probe.selfGraded,
      grade: grade,
      hintLevel: hintLevel,
      revealed: revealed,
      sayIt: sayIt,
      answerShown: answerShown,
    );

/// The line an answered probe leaves behind.
String _verdictText(Grade g) => switch (g) {
      Grade.clear => 'Clear.',
      Grade.hinted => 'Right with help. No credit this time.',
      Grade.wrong => 'Not quite.',
      Grade.unscored => 'Not counted.',
      Grade.self => 'Marked as got it. No credit this time.',
    };

/// The prompt with its blank (a run of ＿ or _) filled by [answer], as the text before, the
/// answer and the text after. A prompt with no blank reads as the answer alone.
(String, String, String) fillBlank(String prompt, String answer) {
  final m = RegExp(r'[＿_]+').firstMatch(prompt);
  if (m == null) return ('', answer, '');
  return (prompt.substring(0, m.start), answer, prompt.substring(m.end));
}

// --- shared pieces -------------------------------------------------------------

/// The pill, the prompt and the body, the way every probe lays them out.
class _ProbeFrame extends StatelessWidget {
  const _ProbeFrame({
    required this.state,
    required this.children,
  });

  final MasteryState state;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(QuietRoomMetrics.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: ProbeStatePill(state: state)),
            const SizedBox(height: QuietRoomMetrics.space16),
            ...children,
          ],
        ),
      );
}

Widget _label(QuietRoomTokens t, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: qrText(t, size: 13, color: t.inkMuted)),
    );

Widget _prompt(QuietRoomTokens t, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text,
          style:
              qrText(t, size: 22, weight: FontWeight.w600, color: t.inkStrong)),
    );

Widget _answerLine(QuietRoomTokens t, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style:
              qrText(t, size: 20, weight: FontWeight.w600, color: t.brand600)),
    );

/// The full answer: the prompt with the missing part filled in and marked.
Widget _fullAnswer(QuietRoomTokens t, String prompt, String answer) {
  final (before, filled, after) = fillBlank(prompt, answer);
  final base = qrText(t, size: 20, weight: FontWeight.w600, color: t.inkStrong);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text.rich(TextSpan(style: base, children: [
      TextSpan(text: before),
      TextSpan(
          text: filled,
          style: base.copyWith(
              color: t.brand600,
              decoration: TextDecoration.underline,
              decorationColor: t.brand600)),
      TextSpan(text: after),
    ])),
  );
}

Widget _quiet(QuietRoomTokens t, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: qrText(t, size: 13.5, color: t.inkMuted)),
    );

Widget _verdict(QuietRoomTokens t, Grade g) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(_verdictText(g),
          style: qrText(t,
              size: 14,
              weight: FontWeight.w600,
              color: g == Grade.clear ? t.sage700 : t.inkMuted)),
    );

Widget _button(QuietRoomTokens t, String label, VoidCallback? onPressed,
        {bool primary = false}) =>
    SizedBox(
      height: QuietRoomMetrics.targetMin,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: primary ? t.brand600 : t.surface,
          side: BorderSide(color: primary ? t.brand600 : t.borderControl),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm)),
        ),
        child: Text(label,
            style: qrText(t,
                size: 14.5,
                weight: FontWeight.w600,
                color: primary ? t.onBrand : t.ink)),
      ),
    );

Widget _quietButton(QuietRoomTokens t, String label, VoidCallback? onPressed) =>
    TextButton(
      onPressed: onPressed,
      child: Text(label,
          style: qrText(t,
              size: 13.5, weight: FontWeight.w600, color: t.brand600)),
    );

/// The wrong mark on the left and the right mark on the right, as every drill places them.
Widget _marks(QuietRoomTokens t,
        {required String miss,
        required String got,
        required void Function(bool gotIt) onMark}) =>
    Row(children: [
      Expanded(child: _button(t, miss, () => onMark(false))),
      const SizedBox(width: 10),
      Expanded(child: _button(t, got, () => onMark(true), primary: true)),
    ]);

/// The hint ladder: least revealing first, one more rung per tap.
Widget _ladder(
    QuietRoomTokens t, List<String> steps, int level, VoidCallback? onMore) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < level && i < steps.length; i++) _quiet(t, steps[i]),
      if (level < steps.length)
        _quietButton(t, level == 0 ? 'Give me a hint' : 'More', onMore),
    ],
  );
}

// --- choose --------------------------------------------------------------------

/// A choice item: tap one of [options]. The right option is clear, any other is wrong. A
/// choice item has no hint before the pick (the grammar screen's rule), so a pick is never
/// hinted.
class ChooseProbe extends StatefulWidget {
  const ChooseProbe({
    super.key,
    required this.item,
    required this.probe,
    required this.state,
    required this.options,
    required this.onAnswer,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final List<String> options;
  final ProbeAnswered onAnswer;

  @override
  State<ChooseProbe> createState() => _ChooseProbeState();
}

class _ChooseProbeState extends State<ChooseProbe> {
  String? _picked;
  Grade? _grade;

  void _pick(String option) {
    if (_picked != null) return;
    final grade = gradeAnswer(
        outcome: option == widget.probe.answer ? Outcome.right : Outcome.wrong,
        selfGraded: false);
    setState(() {
      _picked = option;
      _grade = grade;
    });
    widget.onAnswer(_draft(widget.item, widget.probe, grade));
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return _ProbeFrame(state: widget.state, children: [
      _label(t, 'Choose the missing part'),
      _prompt(t, widget.probe.text),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in widget.options)
          _button(t, o, _picked == null ? () => _pick(o) : null,
              primary: _picked != null && o == widget.probe.answer),
      ]),
      if (_grade != null) _verdict(t, _grade!),
      // A wrong pick: the answer was not on screen, so the full sentence shows.
      if (_grade == Grade.wrong) ...[
        _quiet(t, 'Your answer: ${_picked!}'),
        _fullAnswer(t, widget.probe.text, widget.probe.answer),
      ],
    ]);
  }
}

// --- typed fill ----------------------------------------------------------------

/// A fill-in item or a particle cloze, typed on the Japanese keyboard and judged by
/// `checkTypedAnswer`. The [hint] names the rule, never the answer, and sits behind a
/// "Show grammar hint" tap: a right answer after it is hinted. The [english] sentence sits
/// behind "Show English" and is free: a right answer after it is still a clear (operator
/// ruling, 2026-11-05). "Show answer" is wrong and is recorded
/// as revealed. An answer the matcher cannot judge shows the answer and asks the learner: Got
/// it is self, Missed it is wrong. An empty Check is no attempt.
class TypedFillProbe extends StatefulWidget {
  const TypedFillProbe({
    super.key,
    required this.item,
    required this.probe,
    required this.state,
    required this.onAnswer,
    required this.checkItem,
    this.hint,
    this.english,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final ProbeAnswered onAnswer;
  final String? hint;

  /// The whole sentence in English. Seeing it changes no grade.
  final String? english;

  /// The practice item `checkTypedAnswer` judges against, with its accepted forms and ruby
  /// twins. Required, because a [ProbeDef] carries no accepted forms and a catalog fill item
  /// may accept several (いったら and いけば): the runner passes the raw practice map, or
  /// `{'answer': probe.answer}` for a particle cloze.
  final Map<String, dynamic> checkItem;

  @override
  State<TypedFillProbe> createState() => _TypedFillProbeState();
}

class _TypedFillProbeState extends State<TypedFillProbe> {
  final TextEditingController _typed = TextEditingController();
  bool _hintTaken = false;
  bool _englishShown = false;
  bool _selfCheck = false;
  bool _showAnswer = false;
  bool _empty = false;
  Grade? _grade;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  int get _hintLevel => _hintTaken ? 1 : 0;

  /// What the learner typed, shown beside the answer after a wrong.
  String? _given;

  /// [answerShown] is true only after the compare: the answer was on screen before the mark.
  void _report(Grade grade,
      {bool revealed = false, bool answerShown = false, String? given}) {
    setState(() {
      _grade = grade;
      _given = given;
      _showAnswer = true;
      _empty = false;
    });
    widget.onAnswer(_draft(widget.item, widget.probe, grade,
        hintLevel: _hintLevel, revealed: revealed, answerShown: answerShown));
  }

  void _check() {
    if (_grade != null || _selfCheck) return;
    final v = checkTypedAnswer(_typed.text, widget.checkItem);
    switch (v) {
      case TypedVerdict.empty:
        setState(() => _empty = true);
      case TypedVerdict.right:
        _report(gradeAnswer(
            outcome: Outcome.right, selfGraded: false, hintLevel: _hintLevel));
      case TypedVerdict.wrong:
        _report(
            gradeAnswer(
                outcome: Outcome.wrong,
                selfGraded: false,
                hintLevel: _hintLevel),
            given: _typed.text.trim());
      case TypedVerdict.selfCheck:
        setState(() {
          _selfCheck = true;
          _showAnswer = true;
          _empty = false;
        });
    }
  }

  void _mark(bool gotIt) => _report(
      gradeAnswer(
          outcome: gotIt ? Outcome.none : Outcome.wrong,
          selfGraded: false,
          hintLevel: _hintLevel,
          selfOverride: gotIt),
      answerShown: true);

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final open = _grade == null && !_selfCheck;
    return _ProbeFrame(state: widget.state, children: [
      _label(t, 'Fill in the missing part'),
      _prompt(t, widget.probe.text),
      TextField(
        controller: _typed,
        enabled: open,
        decoration: const InputDecoration(hintText: 'Type in hiragana'),
        onSubmitted: (_) => _check(),
      ),
      if (_empty) _quiet(t, 'Type an answer first.'),
      const SizedBox(height: 10),
      if (open)
        Row(children: [
          Expanded(child: _button(t, 'Check', _check, primary: true)),
          const SizedBox(width: 10),
          Expanded(
              child: _button(
                  t,
                  'Show answer',
                  () => _report(
                      gradeAnswer(
                          outcome: Outcome.wrong,
                          selfGraded: false,
                          hintLevel: _hintLevel,
                          revealed: true),
                      revealed: true))),
        ]),
      if (open &&
          ((widget.english != null && !_englishShown) ||
              (widget.hint != null && !_hintTaken)))
        Wrap(spacing: 4, children: [
          if (widget.english != null && !_englishShown)
            _quietButton(
                t, 'Show English', () => setState(() => _englishShown = true)),
          if (widget.hint != null && !_hintTaken)
            _quietButton(t, 'Show grammar hint',
                () => setState(() => _hintTaken = true)),
        ]),
      if (widget.english != null && _englishShown) _quiet(t, widget.english!),
      if (widget.hint != null && _hintTaken) _quiet(t, widget.hint!),
      if (_grade == Grade.wrong && (_given ?? '').isNotEmpty)
        _quiet(t, 'Your answer: ${_given!}'),
      if (_showAnswer) _fullAnswer(t, widget.probe.text, widget.probe.answer),
      if (_selfCheck && _grade == null) ...[
        _quiet(t, 'This could not be checked. Compare it with the answer.'),
        _marks(t, miss: 'Missed it', got: 'Got it', onMark: _mark),
      ],
      if (_grade != null) _verdict(t, _grade!),
    ]);
  }
}

// --- word recall ---------------------------------------------------------------

/// A word: the picture and the meaning, then the learner says the word through
/// [SpeechService] or types its reading. The hint ladder runs least revealing first; its last
/// rung is the answer, so any answer after it is wrong (D17).
///
/// A spoken answer is written on the item's `spoken` probe and a typed one on its `typed`
/// probe. A speech close is hinted. An unverified listen shows what was heard and asks the
/// learner: Got it is self, Missed it is wrong. Skip is unscored, or wrong after the revealing
/// rung. The controls are disabled while listening.
///
/// Given the `card` probe, the widget asks card recall instead: think of the word, "Show me",
/// then Knew it (clear) or Not yet (wrong), self-graded (PIN-13); a hint before the reveal
/// makes Knew it hinted.
class WordRecallProbe extends StatefulWidget {
  const WordRecallProbe({
    super.key,
    required this.item,
    required this.probe,
    required this.state,
    required this.speech,
    required this.onAnswer,
    this.hintSteps,
    this.kanjiForms = const [],
    this.imageAsset,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final SpeechService speech;
  final ProbeAnswered onAnswer;

  /// The ladder, least revealing first, the answer last. Null uses [wordHintSteps].
  final List<String>? hintSteps;

  /// The word's kanji spellings, for the speech judge and the typed check.
  final List<String> kanjiForms;

  /// The picture; null shows none. See [wordImageAsset].
  final String? imageAsset;

  @override
  State<WordRecallProbe> createState() => _WordRecallProbeState();
}

class _WordRecallProbeState extends State<WordRecallProbe> {
  final TextEditingController _typed = TextEditingController();
  int _hintLevel = 0;
  bool _listening = false;
  bool _cardRevealed = false;

  /// Set by an empty Check; cleared by an answer or an unverified one (as [TypedFillProbe]).
  bool _empty = false;

  /// Bumped by Skip, an answer and dispose; a listen holding an older token is dropped.
  int _token = 0;

  /// The unverified listen or typed answer waiting for the learner's mark, and its probe.
  ProbeDef? _awaiting;
  String? _heard;
  Grade? _grade;
  ProbeDef? _answeredOn;

  /// The learner's own answer on a wrong, typed or heard; null on any other grade.
  String? _given;

  bool get _card => widget.probe.template == 'card';

  List<String> get _steps => widget.hintSteps ?? wordHintSteps(widget.probe);

  bool get _revealedByHint => _hintLevel >= _steps.length;

  ProbeDef _probeFor(String template) =>
      widget.item.probes.where((p) => p.template == template).firstOrNull ??
      widget.probe;

  @override
  void dispose() {
    _token++;
    if (_listening) unawaited(widget.speech.cancel());
    _typed.dispose();
    super.dispose();
  }

  Grade _grade0(Outcome outcome, {bool selfOverride = false}) => gradeAnswer(
        outcome: outcome,
        selfGraded: false,
        hintLevel: _hintLevel,
        revealingHintLevel: _steps.length,
        revealed: _revealedByHint,
        selfOverride: selfOverride,
      );

  /// [given] is what the learner typed or was heard to say, shown beside the answer after a
  /// wrong. The answer was on screen before the answer when the card was revealed, a compare
  /// was waiting, or the ladder reached its last rung.
  void _report(ProbeDef probe, Grade grade, {bool? revealed, String? given}) {
    _token++;
    final answerShown = _cardRevealed || _awaiting != null || _revealedByHint;
    setState(() {
      _grade = grade;
      _answeredOn = probe;
      _given = given;
      _awaiting = null;
      _empty = false;
    });
    widget.onAnswer(_draft(widget.item, probe, grade,
        hintLevel: _hintLevel,
        revealed: revealed ?? _revealedByHint,
        answerShown: answerShown));
  }

  Future<void> _say() async {
    if (_listening || _grade != null || _awaiting != null) return;
    final token = ++_token;
    setState(() => _listening = true);
    try {
      final r = await widget.speech.listenOnce(
          expectedKana: widget.probe.answer, kanjiForms: widget.kanjiForms);
      if (!mounted || token != _token) return;
      setState(() => _listening = false);
      final spoken = _probeFor('spoken');
      switch (r.judgement) {
        case Judgement.correct:
          _report(spoken, _grade0(Outcome.right));
        case Judgement.close:
          _report(spoken, _grade0(Outcome.close));
        case Judgement.wrong:
          _report(spoken, _grade0(Outcome.wrong), given: r.heard);
        case Judgement.unverified:
          setState(() {
            _awaiting = spoken;
            _heard = r.heard;
            _empty = false;
          });
      }
    } catch (e, s) {
      // The app's handler is FlutterError.onError, which an error on a dropped future never
      // reaches, so the listen's failure goes the recorder's way (S4). No draft is written.
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room probes',
          context: ErrorDescription(
              'while listening for ${widget.item.id} ${widget.probe.id}')));
    } finally {
      // 🚨 A throw from `listenOnce` would otherwise leave Say it, Check, Skip and the hint
      // disabled for good: one dead card until the learner leaves the session.
      if (mounted && token == _token && _listening) {
        setState(() => _listening = false);
      }
    }
  }

  void _check() {
    if (_listening || _grade != null || _awaiting != null) return;
    final typedProbe = _probeFor('typed');
    final v = checkTypedAnswer(_typed.text, {
      'answer': widget.probe.answer,
      'accepted': widget.kanjiForms,
    });
    switch (v) {
      case TypedVerdict.empty:
        setState(() => _empty = true);
      case TypedVerdict.right:
        _report(typedProbe, _grade0(Outcome.right));
      case TypedVerdict.wrong:
        _report(typedProbe, _grade0(Outcome.wrong), given: _typed.text.trim());
      case TypedVerdict.selfCheck:
        setState(() {
          _awaiting = typedProbe;
          _heard = _typed.text;
          _empty = false;
        });
    }
  }

  void _mark(bool gotIt) => _report(_awaiting!,
      _grade0(gotIt ? Outcome.none : Outcome.wrong, selfOverride: gotIt));

  void _skip() {
    if (_listening || _grade != null) return;
    _report(_awaiting ?? _probeFor('spoken'), _grade0(Outcome.none));
  }

  void _cardMark(bool knewIt) => _report(
      widget.probe,
      gradeAnswer(
        outcome: knewIt ? Outcome.right : Outcome.wrong,
        selfGraded: true,
        hintLevel: _hintLevel,
        revealingHintLevel: _steps.length,
        revealed: true,
      ),
      revealed: true);

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final busy = _listening;
    final open = _grade == null && _awaiting == null;
    final children = <Widget>[
      if (widget.imageAsset != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Image.asset(widget.imageAsset!,
              height: 160,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      _label(
          t, _card ? 'Think of the word, then check' : 'Say or type the word'),
      _prompt(t, widget.probe.text),
      if (open && !_cardRevealed)
        _ladder(t, _steps, _hintLevel,
            busy ? null : () => setState(() => _hintLevel++))
      else
        for (var i = 0; i < _hintLevel && i < _steps.length; i++)
          _quiet(t, _steps[i]),
    ];
    if (_card) {
      children.addAll([
        if (!_cardRevealed && _grade == null)
          _button(t, 'Show me', () => setState(() => _cardRevealed = true),
              primary: true),
        if (_cardRevealed) _answerLine(t, widget.probe.answer),
        if (_cardRevealed && _grade == null)
          _marks(t, miss: 'Not yet', got: 'Knew it', onMark: _cardMark),
      ]);
    } else {
      children.addAll([
        if (open) ...[
          _button(t, _listening ? 'Listening' : 'Say it', busy ? null : _say,
              primary: true),
          const SizedBox(height: 12),
          TextField(
            controller: _typed,
            enabled: !busy,
            decoration: const InputDecoration(hintText: 'Type in hiragana'),
            onSubmitted: (_) => _check(),
          ),
          if (_empty) _quiet(t, 'Type an answer first.'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _button(t, 'Check', busy ? null : _check)),
            const SizedBox(width: 10),
            Expanded(child: _button(t, 'Skip', busy ? null : _skip)),
          ]),
        ],
        if (_awaiting != null) ...[
          _quiet(
              t,
              _awaiting!.template == 'typed'
                  ? 'You typed: ${_heard ?? ''}. This could not be checked.'
                  : 'Heard: ${_heard ?? ''}. This could not be checked.'),
          _answerLine(t, widget.probe.answer),
          _marks(t, miss: 'Missed it', got: 'Got it', onMark: _mark),
        ],
        if (_grade == Grade.wrong && (_given ?? '').isNotEmpty)
          _quiet(
              t,
              _answeredOn?.template == 'typed'
                  ? 'Your answer: ${_given!}'
                  : 'Heard: ${_given!}'),
        if (_grade != null && _answeredOn != null)
          _answerLine(t, widget.probe.answer),
      ]);
    }
    if (_grade != null) children.add(_verdict(t, _grade!));
    return _ProbeFrame(state: widget.state, children: children);
  }
}

// --- self-graded reveals -------------------------------------------------------

/// Think of the answer, reveal it, grade it: Got it is clear and Missed it is wrong
/// (PIN-13). A hint taken before the reveal makes Got it hinted.
class _RevealProbe extends StatefulWidget {
  const _RevealProbe({
    required this.item,
    required this.probe,
    required this.state,
    required this.onAnswer,
    required this.instruction,
    this.hint,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final ProbeAnswered onAnswer;
  final String instruction;
  final String? hint;

  @override
  State<_RevealProbe> createState() => _RevealProbeState();
}

class _RevealProbeState extends State<_RevealProbe> {
  bool _hintTaken = false;
  bool _revealed = false;
  Grade? _grade;

  void _mark(bool gotIt) {
    if (_grade != null) return;
    final hintLevel = _hintTaken ? 1 : 0;
    final grade = gradeAnswer(
        outcome: gotIt ? Outcome.right : Outcome.wrong,
        selfGraded: true,
        hintLevel: hintLevel,
        revealed: true);
    setState(() => _grade = grade);
    // The mark comes after the reveal, so the answer is already on screen.
    widget.onAnswer(_draft(widget.item, widget.probe, grade,
        hintLevel: hintLevel, revealed: true, answerShown: true));
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return _ProbeFrame(state: widget.state, children: [
      _label(t, widget.instruction),
      _prompt(t, widget.probe.text),
      if (widget.hint != null && !_hintTaken && !_revealed)
        _quietButton(t, 'Show hint', () => setState(() => _hintTaken = true)),
      if (widget.hint != null && _hintTaken) _quiet(t, widget.hint!),
      if (!_revealed)
        _button(t, 'Show answer', () => setState(() => _revealed = true),
            primary: true),
      if (_revealed) _answerLine(t, widget.probe.answer),
      if (_revealed && _grade == null)
        _marks(t, miss: 'Missed it', got: 'Got it', onMark: _mark),
      if (_grade != null) _verdict(t, _grade!),
    ]);
  }
}

/// The form key of a conjugation idea, from its id `conj.<form>.g<group>`.
String _conjugationForm(ItemDef item) {
  final parts = item.id.split('.');
  return parts.length >= 3 ? parts[1] : item.title;
}

/// The learner-facing names of the form keys, hiragana first: the drills screen's labels
/// (quiet_room_drills_widget.dart `_formLabels`) with "form" on each.
const _formLabels = {
  'masu': 'ます form',
  'te': 'て form',
  'ta': 'た form',
  'nai': 'ない form',
  'potential': 'potential form',
  'volitional': 'volitional form',
  'conditional': 'conditional (ば) form',
  'imperative': 'imperative form',
  'prohibitive': 'do not (な) form',
  'passive': 'passive form',
  'causative': 'causative form',
  'causative_passive': 'causative passive form',
};

/// The label a learner reads for a conjugation form key (`te`, `causative_passive`). A key
/// outside [_formLabels] reads as its words plus "form", never as the raw key.
String conjugationFormLabel(String form) =>
    _formLabels[form] ?? '${form.replaceAll('_', ' ')} form';

/// One verb of a conjugation idea: say its form to yourself, reveal, grade.
class ConjugationProbe extends StatelessWidget {
  const ConjugationProbe({
    super.key,
    required this.item,
    required this.probe,
    required this.state,
    required this.onAnswer,
    this.hint,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final ProbeAnswered onAnswer;
  final String? hint;

  @override
  Widget build(BuildContext context) => _RevealProbe(
        item: item,
        probe: probe,
        state: state,
        onAnswer: onAnswer,
        hint: hint,
        instruction: 'Give the ${conjugationFormLabel(_conjugationForm(item))}',
      );
}

/// One direction of a verb pair: shown one verb, recall its partner.
class PairProbe extends StatelessWidget {
  const PairProbe({
    super.key,
    required this.item,
    required this.probe,
    required this.state,
    required this.onAnswer,
    this.hint,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final ProbeAnswered onAnswer;
  final String? hint;

  @override
  Widget build(BuildContext context) => _RevealProbe(
        item: item,
        probe: probe,
        state: state,
        onAnswer: onAnswer,
        hint: hint,
        instruction: probe.template == kPairToIntransitive
            ? 'Give its intransitive partner'
            : 'Give its transitive partner',
      );
}

/// One cell of a reference table row: read the cell, reveal, grade.
class TableCellProbe extends StatelessWidget {
  const TableCellProbe({
    super.key,
    required this.item,
    required this.probe,
    required this.state,
    required this.onAnswer,
    this.hint,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final ProbeAnswered onAnswer;
  final String? hint;

  @override
  Widget build(BuildContext context) => _RevealProbe(
        item: item,
        probe: probe,
        state: state,
        onAnswer: onAnswer,
        hint: hint,
        instruction: 'Read it',
      );
}

// --- the spoken sentence (Say-it) ----------------------------------------------

/// A grammar example said aloud and scored by [PronunciationService], on the Say-it track: it
/// is written with `sayIt`, so it never counts toward the four clears (D4). Correct is clear,
/// close is hinted, wrong is wrong. An unverified check asks the learner: Got it is self,
/// Missed it is unscored, because unverified is never wrong. Skip is unscored.
///
/// [sentence] is the one form the learner says and the scorer hears. The catalog joins some
/// examples with ／ (いこう／たべよう／しよう／こよう), and the scorer takes one sentence, so the
/// caller passes one form, as the speak drill splits them. Null uses the probe's answer.
class SayItProbe extends StatefulWidget {
  const SayItProbe({
    super.key,
    required this.item,
    required this.probe,
    required this.state,
    required this.pronunciation,
    required this.onAnswer,
    this.sentence,
  });

  final ItemDef item;
  final ProbeDef probe;
  final MasteryState state;
  final PronunciationService pronunciation;
  final ProbeAnswered onAnswer;

  /// The one sentence shown and scored; null uses [ProbeDef.answer].
  final String? sentence;

  String get _sentence => sentence ?? probe.answer;

  @override
  State<SayItProbe> createState() => _SayItProbeState();
}

class _SayItProbeState extends State<SayItProbe> {
  bool _checking = false;
  bool _unverified = false;
  int _token = 0;
  Grade? _grade;

  @override
  void dispose() {
    _token++;
    if (_checking) unawaited(widget.pronunciation.cancel());
    super.dispose();
  }

  void _report(Grade grade) {
    _token++;
    setState(() {
      _grade = grade;
      _unverified = false;
    });
    // The sentence said is on screen the whole time.
    widget.onAnswer(_draft(widget.item, widget.probe, grade,
        sayIt: true, selfGraded: false, answerShown: true));
  }

  Future<void> _say() async {
    if (_checking || _grade != null || _unverified) return;
    final token = ++_token;
    setState(() => _checking = true);
    final r = await widget.pronunciation.check(widget._sentence);
    if (!mounted || token != _token) return;
    setState(() => _checking = false);
    switch (r.verdict) {
      case Judgement.correct:
        _report(gradeAnswer(outcome: Outcome.right, selfGraded: false));
      case Judgement.close:
        _report(gradeAnswer(outcome: Outcome.close, selfGraded: false));
      case Judgement.wrong:
        _report(gradeAnswer(outcome: Outcome.wrong, selfGraded: false));
      case Judgement.unverified:
        setState(() => _unverified = true);
    }
  }

  void _mark(bool gotIt) => _report(gradeAnswer(
      outcome: Outcome.none, selfGraded: false, selfOverride: gotIt));

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final open = _grade == null && !_unverified;
    return _ProbeFrame(state: widget.state, children: [
      _label(t, 'Say the sentence'),
      _prompt(t, widget.sentence ?? widget.probe.text),
      if (open)
        Row(children: [
          Expanded(
              child: _button(t, _checking ? 'Listening' : 'Say it',
                  _checking ? null : _say,
                  primary: true)),
          const SizedBox(width: 10),
          Expanded(
              child: _button(
                  t, 'Skip', _checking ? null : () => _report(Grade.unscored))),
        ]),
      if (_unverified) ...[
        _quiet(t, 'This could not be scored. How did it go?'),
        _marks(t, miss: 'Missed it', got: 'Got it', onMark: _mark),
      ],
      if (_grade != null) _verdict(t, _grade!),
    ]);
  }
}
