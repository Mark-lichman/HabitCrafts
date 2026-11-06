// Widget tests for the probe widgets (plan 2026-11-02, Task 19).
//
// Each probe kind is driven to each grade it can report, with fake speech and pronunciation
// services, and the test reads the `DrillAnswer` draft the widget hands on: the grade, the
// template, the hint level, the revealed flag, the Say-it flag and whether the answer was
// already on screen. Every widget shows the item's state pill as "n of 4 clears".
//
// The rules under test: a hinted answer is hinted, never clear (PIN-3); a hint ladder's
// revealing rung grades any answer wrong (D17); on a self-graded probe Got it after the
// reveal is clear and Missed it is wrong (PIN-13); unverified is never wrong; an empty Check
// is no attempt; a wrong never hides the answer, and a typed one shows the learner's too
// (operator ruling 2026-11-05); every typed answer box reads "Type in hiragana".

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/probe_widgets.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/pronunciation_service.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart';

// --- fakes -------------------------------------------------------------------

class _NoStt implements SttEngine {
  @override
  Future<bool> initialize(
          {required void Function(String code) onError}) async =>
      true;
  @override
  Future<void> listen({
    required Duration listenFor,
    required void Function(List<String> alternates) onFinal,
    required void Function(double raw) onLevel,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
  @override
  bool get isListening => false;
}

class _NoTts implements TtsEngine {
  @override
  set onDone(void Function()? f) {}
  @override
  Future<void> configure() async {}
  @override
  Future<List<Map<String, String>>> voices() async => const [];
  @override
  Future<List<String>> languages() async => const [];
  @override
  Future<void> use(Map<String, String> voice) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

/// A speech service whose every listen waits until the test answers it.
class FakeSpeech extends SpeechService {
  FakeSpeech() : super.withEngines(stt: _NoStt(), tts: _NoTts());

  final List<Completer<SpeechResult>> listens = [];
  final List<String> expected = [];
  int cancels = 0;

  /// When set, a cancel counts but leaves the listen open, so the test can end it itself.
  bool holdOnCancel = false;

  @override
  Future<SpeechResult> listenOnce({
    required String expectedKana,
    List<String> kanjiForms = const [],
    Duration limit = const Duration(seconds: 6),
  }) {
    expected.add(expectedKana);
    final c = Completer<SpeechResult>();
    listens.add(c);
    return c.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (holdOnCancel) return;
    for (final c in listens) {
      if (!c.isCompleted) {
        c.complete(const SpeechResult('', Judgement.unverified));
      }
    }
  }

  void answer(String heard, Judgement j) =>
      listens.last.complete(SpeechResult(heard, j));

  /// Ends the listen the way a recogniser that throws does.
  void fail(Object error) => listens.last.completeError(error);
}

class _NoRecorder implements PronRecorder {
  @override
  Future<Stream<Uint8List>?> start(int sampleRate) async => null;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// A pronunciation service whose every check waits until the test answers it.
class FakePronunciation extends PronunciationService {
  FakePronunciation()
      : super(
            recorder: _NoRecorder(),
            signIn: () async {},
            score: (_) async => null);

  final List<Completer<PronunciationResult>> checks = [];
  final List<String> referenceTexts = [];
  int cancels = 0;

  @override
  Future<PronunciationResult> check(String hiragana) {
    referenceTexts.add(hiragana);
    final c = Completer<PronunciationResult>();
    checks.add(c);
    return c.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    for (final c in checks) {
      if (!c.isCompleted) c.complete(const PronunciationResult.unverified());
    }
  }

  void answer(Judgement j) => checks.last.complete(PronunciationResult(
      verdict: j, overall: j == Judgement.unverified ? null : 70));
}

// --- items -------------------------------------------------------------------

final _grammar = ItemDef(
  id: 'mari.L26.1',
  kind: ItemKind.grammar,
  title: '〜んです',
  prereqLevel: 2,
  lesson: 26,
  probes: const [
    ProbeDef(
        id: 'p0', template: 'choose', text: 'あした テストが ＿＿んです。', answer: 'ある'),
    ProbeDef(
        id: 'p1',
        template: 'fill',
        text: 'きょうは しごとが やすみ＿＿。',
        answer: 'なんです',
        production: true),
    ProbeDef(
        id: 'ex0',
        template: kSayItTemplate,
        text: 'あたまが いたいんです。',
        answer: 'あたまが いたいんです。',
        production: true,
        selfGraded: true,
        scored: false),
  ],
);

final _word = ItemDef(
  id: 'L30_02',
  kind: ItemKind.word,
  title: 'かばん',
  prereqLevel: 1,
  lesson: 30,
  probes: const [
    ProbeDef(
        id: 'card',
        template: 'card',
        text: 'bag',
        answer: 'かばん',
        selfGraded: true),
    ProbeDef(
        id: 'spoken',
        template: 'spoken',
        text: 'bag',
        answer: 'かばん',
        production: true),
    ProbeDef(
        id: 'typed',
        template: 'typed',
        text: 'bag',
        answer: 'かばん',
        production: true),
  ],
);

final _conj = ItemDef(
  id: conjugationItemId('te', 1),
  kind: ItemKind.conjugation,
  title: 'te, group 1',
  prereqLevel: 0,
  probes: const [
    ProbeDef(
        id: 'かく',
        template: kConjugateTemplate,
        text: 'かく',
        answer: 'かいて',
        production: true,
        selfGraded: true),
  ],
);

final _pair = ItemDef(
  id: 'pair.aku',
  kind: ItemKind.pair,
  title: 'あく / あける',
  prereqLevel: 0,
  probes: const [
    ProbeDef(
        id: kPairToTransitive,
        template: kPairToTransitive,
        text: 'あく',
        answer: 'あける',
        selfGraded: true),
    ProbeDef(
        id: kPairToIntransitive,
        template: kPairToIntransitive,
        text: 'あける',
        answer: 'あく',
        selfGraded: true),
  ],
);

final _row = ItemDef(
  id: tableRowItemId('counters', 'ほん'),
  kind: ItemKind.tableRow,
  title: 'Counters: ほん',
  prereqLevel: 0,
  probes: const [
    ProbeDef(
        id: '3',
        template: kCellTemplate,
        text: 'ほん 3',
        answer: 'さんぼん',
        selfGraded: true,
        irregular: true),
  ],
);

ProbeDef _probe(ItemDef item, String id) =>
    item.probes.firstWhere((p) => p.id == id);

MasteryState _learning(String id, int n) => MasteryState(
      itemId: id,
      status: MasteryStatus.learning,
      clears: [
        for (var i = 0; i < n; i++)
          ClearRef(day: i, template: 't', production: false, probeId: 'p$i'),
      ],
    );

// --- harness -----------------------------------------------------------------

/// The drafts a widget handed on, in order.
class Answers {
  final List<DrillAnswer> list = [];
  void call(DrillAnswer a) => list.add(a);
  DrillAnswer get single {
    expect(list, hasLength(1), reason: 'exactly one answer reported');
    return list.single;
  }
}

Future<void> _pump(WidgetTester tester, Widget probe) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: probe))));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final f = find.text(label);
  expect(f, findsOneWidget, reason: 'a "$label" control');
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void _expectDraft(
  DrillAnswer a, {
  required String itemId,
  required String probeId,
  required String template,
  required Grade grade,
  int hintLevel = 0,
  bool revealed = false,
  bool? selfGraded,
  bool sayIt = false,
}) {
  expect(a.itemId, itemId);
  expect(a.probeId, probeId);
  expect(a.template, template);
  expect(a.grade, grade);
  expect(a.hintLevel, hintLevel);
  expect(a.revealed, revealed);
  if (selfGraded != null) expect(a.selfGraded, selfGraded);
  expect(a.sayIt, sayIt);
  // Every draft makes a valid Attempt: a clear never carries a hint (PIN-3).
  if (a.grade == Grade.clear) expect(a.hintLevel, 0);
}

void main() {
  group('state pill', () {
    test(
        'New and Learning show only the n of 4 clears; Mastered and Shaky keep their '
        'marker (operator ruling 2026-11-05)', () {
      expect(probeStateLabel(const MasteryState.initial('x')), '0 of 4 clears');
      expect(probeStateLabel(_learning('x', 2)), '2 of 4 clears');
      expect(
          probeStateLabel(const MasteryState(
              itemId: 'x', status: MasteryStatus.mastered, masteredOn: 40)),
          'Mastered · 4 of 4');
      expect(
          probeStateLabel(const MasteryState(
              itemId: 'x',
              status: MasteryStatus.shaky,
              clears: [
                ClearRef(day: 3, template: 't', production: false, probeId: 'p')
              ])),
          'Shaky · 1 clear toward regaining');
    });

    testWidgets('every probe widget shows the pill', (tester) async {
      final state = _learning('any', 3);
      final speech = FakeSpeech();
      final pron = FakePronunciation();
      final widgets = <Widget>[
        ChooseProbe(
            item: _grammar,
            probe: _probe(_grammar, 'p0'),
            state: state,
            options: const ['ある', 'あります', 'あって'],
            onAnswer: (_) {}),
        TypedFillProbe(
            item: _grammar,
            probe: _probe(_grammar, 'p1'),
            state: state,
            checkItem: const {'answer': 'なんです'},
            onAnswer: (_) {}),
        WordRecallProbe(
            item: _word,
            probe: _probe(_word, 'spoken'),
            state: state,
            speech: speech,
            onAnswer: (_) {}),
        ConjugationProbe(
            item: _conj,
            probe: _conj.probes.single,
            state: state,
            onAnswer: (_) {}),
        PairProbe(
            item: _pair,
            probe: _probe(_pair, kPairToTransitive),
            state: state,
            onAnswer: (_) {}),
        TableCellProbe(
            item: _row,
            probe: _row.probes.single,
            state: state,
            onAnswer: (_) {}),
        SayItProbe(
            item: _grammar,
            probe: _probe(_grammar, 'ex0'),
            state: state,
            pronunciation: pron,
            onAnswer: (_) {}),
      ];
      for (final w in widgets) {
        await _pump(tester, w);
        expect(find.text('3 of 4 clears'), findsOneWidget,
            reason: '${w.runtimeType} shows the pill');
        expect(find.textContaining('Learning'), findsNothing,
            reason: '${w.runtimeType}: no state word beside the section line');
      }
    });

    testWidgets('a new item reads 0 of 4 clears', (tester) async {
      await _pump(
          tester,
          ConjugationProbe(
              item: _conj,
              probe: _conj.probes.single,
              state: const MasteryState.initial('conj.te.g1'),
              onAnswer: (_) {}));
      expect(find.text('0 of 4 clears'), findsOneWidget);
      expect(find.textContaining('New'), findsNothing);
    });
  });

  group('typed answer boxes (operator ruling 2026-11-05)', () {
    testWidgets('every typed answer box asks for hiragana in words',
        (tester) async {
      for (final w in [
        TypedFillProbe(
            item: _grammar,
            probe: _probe(_grammar, 'p1'),
            state: const MasteryState.initial('mari.L26.1'),
            checkItem: const {'answer': 'なんです'},
            onAnswer: (_) {}),
        WordRecallProbe(
            item: _word,
            probe: _probe(_word, 'spoken'),
            state: const MasteryState.initial('L30_02'),
            speech: FakeSpeech(),
            onAnswer: (_) {}),
      ]) {
        await _pump(tester, w);
        expect(find.text('Type in hiragana'), findsOneWidget,
            reason: '${w.runtimeType}');
        expect(find.text('ひらがな'), findsNothing, reason: '${w.runtimeType}');
      }
    });
  });

  group('choose', () {
    Future<Answers> pick(WidgetTester tester, String option) async {
      final answers = Answers();
      await _pump(
          tester,
          ChooseProbe(
              item: _grammar,
              probe: _probe(_grammar, 'p0'),
              state: const MasteryState.initial('mari.L26.1'),
              options: const ['ある', 'あります', 'あって'],
              onAnswer: answers.call));
      await _tap(tester, option);
      return answers;
    }

    testWidgets('the right option is clear', (tester) async {
      final a = await pick(tester, 'ある');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p0',
          template: 'choose',
          grade: Grade.clear,
          selfGraded: false);
    });

    testWidgets('a wrong option is wrong, and the options lock',
        (tester) async {
      final a = await pick(tester, 'あります');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p0',
          template: 'choose',
          grade: Grade.wrong);
      await tester.tap(find.text('ある'));
      await tester.pump();
      expect(a.list, hasLength(1), reason: 'one answer per probe');
    });

    testWidgets('the English is free: a right pick after it is still clear',
        (tester) async {
      final answers = Answers();
      await _pump(
          tester,
          ChooseProbe(
              item: _grammar,
              probe: _probe(_grammar, 'p0'),
              state: const MasteryState.initial('mari.L26.1'),
              options: const ['ある', 'あります', 'あって'],
              english: 'I have a test tomorrow, you see.',
              onAnswer: answers.call));
      expect(find.text('I have a test tomorrow, you see.'), findsNothing);
      await _tap(tester, 'Show English');
      expect(find.text('I have a test tomorrow, you see.'), findsOneWidget);
      await _tap(tester, 'ある');
      _expectDraft(answers.single,
          itemId: 'mari.L26.1',
          probeId: 'p0',
          template: 'choose',
          grade: Grade.clear,
          selfGraded: false);
    });
  });

  group('typed fill', () {
    Future<Answers> open(WidgetTester tester,
        {Map<String, dynamic> checkItem = const {'answer': 'なんです'}}) async {
      final answers = Answers();
      await _pump(
          tester,
          TypedFillProbe(
              item: _grammar,
              probe: _probe(_grammar, 'p1'),
              state: const MasteryState.initial('mari.L26.1'),
              hint: 'A noun needs な before んです',
              english: 'Today is my day off, you see.',
              checkItem: checkItem,
              onAnswer: answers.call));
      return answers;
    }

    testWidgets('the hint stays behind a tap', (tester) async {
      await open(tester);
      expect(find.text('A noun needs な before んです'), findsNothing);
      await _tap(tester, 'Show grammar hint');
      expect(find.text('A noun needs な before んです'), findsOneWidget);
    });

    testWidgets('the English stays behind its own tap', (tester) async {
      await open(tester);
      expect(find.text('Today is my day off, you see.'), findsNothing);
      await _tap(tester, 'Show English');
      expect(find.text('Today is my day off, you see.'), findsOneWidget);
      expect(find.text('Show English'), findsNothing);
      expect(find.text('Show grammar hint'), findsOneWidget,
          reason: 'the grammar hint is still on offer');
    });

    testWidgets('a right answer after the English is still clear (ruling)',
        (tester) async {
      final a = await open(tester);
      await _tap(tester, 'Show English');
      await _type(tester, 'なんです');
      await _tap(tester, 'Check');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.clear,
          selfGraded: false);
    });

    testWidgets('the English and the grammar hint together are hinted',
        (tester) async {
      final a = await open(tester);
      await _tap(tester, 'Show English');
      await _tap(tester, 'Show grammar hint');
      await _type(tester, 'なんです');
      await _tap(tester, 'Check');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.hinted,
          hintLevel: 1);
    });

    testWidgets('a right answer with no hint is clear', (tester) async {
      final a = await open(tester);
      await _type(tester, 'なんです');
      await _tap(tester, 'Check');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.clear,
          selfGraded: false);
      expect(a.single.production, isTrue);
    });

    testWidgets('a right answer after the hint is hinted (PIN-3)',
        (tester) async {
      final a = await open(tester);
      await _tap(tester, 'Show grammar hint');
      await _type(tester, 'なんです');
      await _tap(tester, 'Check');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.hinted,
          hintLevel: 1);
    });

    testWidgets('a wrong kana answer is wrong', (tester) async {
      final a = await open(tester);
      await _type(tester, 'です');
      await _tap(tester, 'Check');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.wrong);
      // Both answers show: the learner's, and the sentence with the part filled in.
      expect(find.text('Your answer: です'), findsOneWidget);
      expect(find.text('きょうは しごとが やすみなんです。'), findsOneWidget,
          reason: 'the full answer shows');
      expect(find.text('Not this time.'), findsNothing);
      expect(a.single.answerShown, isFalse,
          reason: 'the answer was not on screen before the check');
    });

    testWidgets('Show answer is wrong and recorded as revealed',
        (tester) async {
      final a = await open(tester);
      await _tap(tester, 'Show answer');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.wrong,
          revealed: true);
      expect(find.text('きょうは しごとが やすみなんです。'), findsOneWidget,
          reason: 'Show answer shows the full answer');
      expect(find.textContaining('Your answer'), findsNothing,
          reason: 'nothing was typed');
      expect(a.single.answerShown, isFalse);
    });

    test('the blank is filled with the answer, the parts around it kept', () {
      expect(fillBlank('きょうは しごとが やすみ＿＿。', 'なんです'),
          ('きょうは しごとが やすみ', 'なんです', '。'));
      expect(fillBlank('no blank', 'x'), ('', 'x', ''));
    });

    testWidgets('an empty Check is not an attempt', (tester) async {
      final a = await open(tester);
      await _tap(tester, 'Check');
      expect(a.list, isEmpty);
    });

    testWidgets('the empty-Check message clears once an answer is checked',
        (tester) async {
      final a = await open(tester);
      await _tap(tester, 'Check');
      expect(find.text('Type an answer first.'), findsOneWidget);
      await _type(tester, 'なんです');
      await _tap(tester, 'Check');
      expect(a.single.grade, Grade.clear);
      expect(find.text('Type an answer first.'), findsNothing);
    });

    testWidgets('an accepted alternate form is clear', (tester) async {
      final a = await open(tester, checkItem: const {
        'answer': 'いったら',
        'accepted': ['いけば'],
      });
      await _type(tester, 'いけば');
      await _tap(tester, 'Check');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.clear,
          selfGraded: false);
    });

    testWidgets('an answer the matcher cannot judge: Got it is self',
        (tester) async {
      final a = await open(tester);
      await _type(tester, '何です');
      await _tap(tester, 'Check');
      expect(a.list, isEmpty, reason: 'waits for the self-mark');
      await _tap(tester, 'Got it');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.self);
    });

    testWidgets('an answer the matcher cannot judge: Missed it is wrong',
        (tester) async {
      final a = await open(tester);
      await _type(tester, '何です');
      await _tap(tester, 'Check');
      await _tap(tester, 'Missed it');
      _expectDraft(a.single,
          itemId: 'mari.L26.1',
          probeId: 'p1',
          template: 'fill',
          grade: Grade.wrong);
    });
  });

  group('word recall', () {
    late FakeSpeech speech;
    late Answers answers;

    Future<void> open(WidgetTester tester, {String probe = 'spoken'}) async {
      speech = FakeSpeech();
      answers = Answers();
      await _pump(
          tester,
          WordRecallProbe(
              item: _word,
              probe: _probe(_word, probe),
              state: _learning('L30_02', 1),
              speech: speech,
              hintSteps: const ['Meaning: bag', 'Starts with 「か」', 'かばん'],
              onAnswer: answers.call));
    }

    Future<void> say(WidgetTester tester, String heard, Judgement j) async {
      await _tap(tester, 'Say it');
      expect(speech.expected.last, 'かばん');
      speech.answer(heard, j);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the picture prompt shows the meaning', (tester) async {
      await open(tester);
      expect(find.text('bag'), findsOneWidget);
    });

    testWidgets('the picture shows when an image asset is given',
        (tester) async {
      expect(wordImageAsset('L30_02'), 'assets/lessons/img/L30_02.webp');
      await open(tester);
      expect(find.byType(Image), findsNothing, reason: 'no asset, no picture');
      await _pump(
          tester,
          WordRecallProbe(
              item: _word,
              probe: _probe(_word, 'spoken'),
              state: _learning('L30_02', 1),
              speech: speech,
              imageAsset: wordImageAsset('L30_02'),
              onAnswer: answers.call));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('said right with no hint is clear', (tester) async {
      await open(tester);
      await say(tester, 'かばん', Judgement.correct);
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.clear,
          selfGraded: false);
    });

    testWidgets('a speech close is hinted', (tester) async {
      await open(tester);
      await say(tester, 'かば', Judgement.close);
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.hinted);
    });

    testWidgets('said wrong is wrong', (tester) async {
      await open(tester);
      await say(tester, 'かさ', Judgement.wrong);
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.wrong);
    });

    testWidgets('right after one hint is hinted, with the level carried',
        (tester) async {
      await open(tester);
      await _tap(tester, 'Give me a hint');
      expect(find.text('Meaning: bag'), findsOneWidget);
      await say(tester, 'かばん', Judgement.correct);
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.hinted,
          hintLevel: 1);
    });

    testWidgets('the revealing hint level grades a right answer wrong',
        (tester) async {
      await open(tester);
      await _tap(tester, 'Give me a hint');
      await _tap(tester, 'More');
      await _tap(tester, 'More');
      expect(find.text('More'), findsNothing, reason: 'the ladder has ended');
      await say(tester, 'かばん', Judgement.correct);
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.wrong,
          hintLevel: 3,
          revealed: true);
    });

    testWidgets('an unverified listen is never wrong: Got it is self',
        (tester) async {
      await open(tester);
      await say(tester, '鞄', Judgement.unverified);
      expect(answers.list, isEmpty, reason: 'waits for the self-mark');
      expect(find.textContaining('鞄'), findsOneWidget,
          reason: 'what was heard shows');
      await _tap(tester, 'Got it');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.self);
    });

    testWidgets('an unverified listen marked Missed it is wrong',
        (tester) async {
      await open(tester);
      await say(tester, '鞄', Judgement.unverified);
      await _tap(tester, 'Missed it');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.wrong);
    });

    testWidgets('the controls are disabled while listening', (tester) async {
      await open(tester);
      await _tap(tester, 'Say it');
      expect(find.text('Say it'), findsNothing);
      await tester.tap(find.text('Listening'), warnIfMissed: false);
      await tester.pump();
      expect(speech.listens, hasLength(1), reason: 'one listen at a time');
      await tester.tap(find.text('Skip'), warnIfMissed: false);
      await tester.pump();
      expect(answers.list, isEmpty, reason: 'no answer while listening');
      speech.answer('かばん', Judgement.correct);
      await tester.pump();
      expect(answers.list, hasLength(1));
    });

    testWidgets('leaving the probe mid-listen cancels it and drops the result',
        (tester) async {
      await open(tester);
      await _tap(tester, 'Say it');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(speech.cancels, 1);
      await tester.pump();
      expect(answers.list, isEmpty);
    });

    testWidgets(
        'a listen that throws frees the controls, reports the error and writes no draft',
        (tester) async {
      await open(tester);
      await _tap(tester, 'Say it');
      expect(find.text('Listening'), findsOneWidget);
      speech.fail(StateError('recogniser gone'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isA<StateError>(),
          reason: 'the failure reaches the app handler');
      expect(answers.list, isEmpty, reason: 'a failed listen is no attempt');
      expect(find.text('Listening'), findsNothing);
      expect(find.text('Say it'), findsOneWidget);
      // The controls work again: the hint ladder, then a Skip that reports.
      await _tap(tester, 'Give me a hint');
      expect(find.text('Meaning: bag'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await _tap(tester, 'Skip');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.unscored,
          hintLevel: 1);
    });

    testWidgets(
        'a listen that throws after the probe has gone touches no state',
        (tester) async {
      await open(tester);
      speech.holdOnCancel = true;
      await _tap(tester, 'Say it');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(speech.cancels, 1);
      speech.fail(StateError('recogniser gone'));
      await tester.pump();
      // One exception, the listen's own: a setState after dispose would be a second.
      expect(tester.takeException(), isA<StateError>());
      expect(answers.list, isEmpty);
    });

    testWidgets('an empty Check says so and writes no draft', (tester) async {
      await open(tester);
      await _tap(tester, 'Check');
      expect(find.text('Type an answer first.'), findsOneWidget);
      expect(answers.list, isEmpty, reason: 'an empty Check is no attempt');
      await _type(tester, 'かばん');
      await _tap(tester, 'Check');
      expect(find.text('Type an answer first.'), findsNothing,
          reason: 'cleared by the answer');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'typed',
          template: 'typed',
          grade: Grade.clear);
    });

    testWidgets('the empty-Check message clears on an unverified typed answer',
        (tester) async {
      await open(tester);
      await _tap(tester, 'Check');
      expect(find.text('Type an answer first.'), findsOneWidget);
      await _type(tester, '鞄');
      await _tap(tester, 'Check');
      expect(find.text('Type an answer first.'), findsNothing);
      expect(find.textContaining('You typed: 鞄'), findsOneWidget);
      expect(answers.list, isEmpty, reason: 'waits for the self-mark');
    });

    testWidgets('typing the reading right is clear on the typed probe',
        (tester) async {
      await open(tester);
      await _type(tester, 'カバン');
      await _tap(tester, 'Check');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'typed',
          template: 'typed',
          grade: Grade.clear);
    });

    testWidgets('typing the reading wrong is wrong', (tester) async {
      await open(tester);
      await _type(tester, 'かさ');
      await _tap(tester, 'Check');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'typed',
          template: 'typed',
          grade: Grade.wrong);
      expect(answers.single.answerShown, isFalse);
      expect(find.text('Your answer: かさ'), findsOneWidget);
      expect(find.text('かばん'), findsOneWidget, reason: 'the answer shows');
    });

    testWidgets('a typed answer the matcher cannot judge says what was typed',
        (tester) async {
      await open(tester);
      await _type(tester, '鞄');
      await _tap(tester, 'Check');
      expect(answers.list, isEmpty, reason: 'waits for the self-mark');
      expect(find.textContaining('鞄'), findsOneWidget);
      expect(find.textContaining('You typed: 鞄'), findsOneWidget);
      expect(find.textContaining('Heard:'), findsNothing);
      await _tap(tester, 'Got it');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'typed',
          template: 'typed',
          grade: Grade.self);
    });

    testWidgets('Skip is unscored', (tester) async {
      await open(tester);
      await _tap(tester, 'Skip');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.unscored);
    });

    testWidgets('Skip after the revealing hint is wrong', (tester) async {
      await open(tester);
      await _tap(tester, 'Give me a hint');
      await _tap(tester, 'More');
      await _tap(tester, 'More');
      await _tap(tester, 'Skip');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'spoken',
          template: 'spoken',
          grade: Grade.wrong,
          hintLevel: 3,
          revealed: true);
    });

    testWidgets('the card probe: Knew it after the reveal is clear (PIN-13)',
        (tester) async {
      await open(tester, probe: 'card');
      expect(find.text('Say it'), findsNothing);
      await _tap(tester, 'Show me');
      expect(find.text('かばん'), findsOneWidget);
      await _tap(tester, 'Knew it');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'card',
          template: 'card',
          grade: Grade.clear,
          revealed: true,
          selfGraded: true);
    });

    testWidgets('the card probe: Not yet is wrong', (tester) async {
      await open(tester, probe: 'card');
      await _tap(tester, 'Show me');
      await _tap(tester, 'Not yet');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'card',
          template: 'card',
          grade: Grade.wrong,
          revealed: true,
          selfGraded: true);
      expect(answers.single.answerShown, isTrue,
          reason: 'the card showed the answer before Not yet');
    });

    testWidgets('the card probe: a hint before the reveal is hinted',
        (tester) async {
      await open(tester, probe: 'card');
      await _tap(tester, 'Give me a hint');
      await _tap(tester, 'Show me');
      await _tap(tester, 'Knew it');
      _expectDraft(answers.single,
          itemId: 'L30_02',
          probeId: 'card',
          template: 'card',
          grade: Grade.hinted,
          hintLevel: 1,
          revealed: true);
    });
  });

  group('self-graded reveals (PIN-13)', () {
    Future<Answers> open(
        WidgetTester tester, Widget Function(Answers) build) async {
      final answers = Answers();
      await _pump(tester, build(answers));
      return answers;
    }

    testWidgets('conjugation: Got it after the reveal is clear',
        (tester) async {
      final a = await open(
          tester,
          (a) => ConjugationProbe(
              item: _conj,
              probe: _conj.probes.single,
              state: const MasteryState.initial('conj.te.g1'),
              onAnswer: a.call));
      expect(find.text('かく'), findsOneWidget);
      expect(find.text('かいて'), findsNothing, reason: 'hidden until revealed');
      expect(find.text('Got it'), findsNothing,
          reason: 'no mark before reveal');
      await _tap(tester, 'Show answer');
      expect(find.text('かいて'), findsOneWidget);
      await _tap(tester, 'Got it');
      _expectDraft(a.single,
          itemId: 'conj.te.g1',
          probeId: 'かく',
          template: kConjugateTemplate,
          grade: Grade.clear,
          revealed: true,
          selfGraded: true);
      expect(a.single.production, isTrue);
    });

    test('conjugation form labels are hiragana first, never a raw key', () {
      expect(conjugationFormLabel('te'), 'て form');
      expect(conjugationFormLabel('masu'), 'ます form');
      expect(conjugationFormLabel('nai'), 'ない form');
      expect(
          conjugationFormLabel('causative_passive'), 'causative passive form');
      expect(conjugationFormLabel('prohibitive'), 'do not (な) form');
      expect(conjugationFormLabel('some_new_key'), 'some new key form',
          reason: 'an unlisted key still reads as words');
      for (final form in [
        'masu',
        'te',
        'ta',
        'nai',
        'potential',
        'volitional',
        'conditional',
        'imperative',
        'prohibitive',
        'passive',
        'causative',
        'causative_passive',
      ]) {
        expect(conjugationFormLabel(form), isNot(contains('_')));
        expect(conjugationFormLabel(form), endsWith(' form'));
      }
    });

    testWidgets('conjugation: the instruction names the form in hiragana',
        (tester) async {
      await open(
          tester,
          (a) => ConjugationProbe(
              item: _conj,
              probe: _conj.probes.single,
              state: const MasteryState.initial('conj.te.g1'),
              onAnswer: a.call));
      expect(find.text('Give the て form'), findsOneWidget);
      expect(find.textContaining('te form'), findsNothing);
    });

    testWidgets('conjugation: no instruction shows an underscore',
        (tester) async {
      final item = ItemDef(
        id: conjugationItemId('causative_passive', 2),
        kind: ItemKind.conjugation,
        title: 'causative_passive, group 2',
        prereqLevel: 0,
        probes: const [
          ProbeDef(
              id: 'たべる',
              template: kConjugateTemplate,
              text: 'たべる',
              answer: 'たべさせられる',
              production: true,
              selfGraded: true),
        ],
      );
      await open(
          tester,
          (a) => ConjugationProbe(
              item: item,
              probe: item.probes.single,
              state: MasteryState.initial(item.id),
              onAnswer: a.call));
      expect(find.text('Give the causative passive form'), findsOneWidget);
      expect(find.textContaining('_'), findsNothing);
    });

    testWidgets('conjugation: Missed it is wrong', (tester) async {
      final a = await open(
          tester,
          (a) => ConjugationProbe(
              item: _conj,
              probe: _conj.probes.single,
              state: const MasteryState.initial('conj.te.g1'),
              onAnswer: a.call));
      await _tap(tester, 'Show answer');
      await _tap(tester, 'Missed it');
      _expectDraft(a.single,
          itemId: 'conj.te.g1',
          probeId: 'かく',
          template: kConjugateTemplate,
          grade: Grade.wrong,
          revealed: true,
          selfGraded: true);
      expect(a.single.answerShown, isTrue);
    });

    testWidgets('conjugation: a hint before the reveal makes Got it hinted',
        (tester) async {
      final a = await open(
          tester,
          (a) => ConjugationProbe(
              item: _conj,
              probe: _conj.probes.single,
              state: const MasteryState.initial('conj.te.g1'),
              hint: 'く becomes いて',
              onAnswer: a.call));
      await _tap(tester, 'Show hint');
      expect(find.text('く becomes いて'), findsOneWidget);
      await _tap(tester, 'Show answer');
      await _tap(tester, 'Got it');
      _expectDraft(a.single,
          itemId: 'conj.te.g1',
          probeId: 'かく',
          template: kConjugateTemplate,
          grade: Grade.hinted,
          hintLevel: 1,
          revealed: true);
    });

    testWidgets('pair, intransitive to transitive: Got it is clear',
        (tester) async {
      final a = await open(
          tester,
          (a) => PairProbe(
              item: _pair,
              probe: _probe(_pair, kPairToTransitive),
              state: const MasteryState.initial('pair.aku'),
              onAnswer: a.call));
      expect(find.text('あく'), findsOneWidget);
      expect(find.text('Give its transitive partner'), findsOneWidget);
      expect(find.text('Give its intransitive partner'), findsNothing);
      await _tap(tester, 'Show answer');
      expect(find.text('あける'), findsOneWidget);
      await _tap(tester, 'Got it');
      _expectDraft(a.single,
          itemId: 'pair.aku',
          probeId: kPairToTransitive,
          template: kPairToTransitive,
          grade: Grade.clear,
          revealed: true,
          selfGraded: true);
    });

    testWidgets('pair, transitive to intransitive: Missed it is wrong',
        (tester) async {
      final a = await open(
          tester,
          (a) => PairProbe(
              item: _pair,
              probe: _probe(_pair, kPairToIntransitive),
              state: const MasteryState.initial('pair.aku'),
              onAnswer: a.call));
      expect(find.text('あける'), findsOneWidget);
      expect(find.text('Give its intransitive partner'), findsOneWidget);
      expect(find.text('Give its transitive partner'), findsNothing);
      await _tap(tester, 'Show answer');
      expect(find.text('あく'), findsOneWidget);
      await _tap(tester, 'Missed it');
      _expectDraft(a.single,
          itemId: 'pair.aku',
          probeId: kPairToIntransitive,
          template: kPairToIntransitive,
          grade: Grade.wrong,
          revealed: true,
          selfGraded: true);
    });

    testWidgets('table cell: Got it is clear', (tester) async {
      final a = await open(
          tester,
          (a) => TableCellProbe(
              item: _row,
              probe: _row.probes.single,
              state: const MasteryState.initial('ref.counters.ほん'),
              onAnswer: a.call));
      expect(find.text('ほん 3'), findsOneWidget);
      await _tap(tester, 'Show answer');
      expect(find.text('さんぼん'), findsOneWidget);
      await _tap(tester, 'Got it');
      _expectDraft(a.single,
          itemId: 'ref.counters.ほん',
          probeId: '3',
          template: kCellTemplate,
          grade: Grade.clear,
          revealed: true,
          selfGraded: true);
    });

    testWidgets('table cell: Missed it is wrong', (tester) async {
      final a = await open(
          tester,
          (a) => TableCellProbe(
              item: _row,
              probe: _row.probes.single,
              state: const MasteryState.initial('ref.counters.ほん'),
              onAnswer: a.call));
      await _tap(tester, 'Show answer');
      await _tap(tester, 'Missed it');
      _expectDraft(a.single,
          itemId: 'ref.counters.ほん',
          probeId: '3',
          template: kCellTemplate,
          grade: Grade.wrong,
          revealed: true,
          selfGraded: true);
    });
  });

  group('spoken sentence (Say-it)', () {
    late FakePronunciation pron;
    late Answers answers;

    Future<void> open(WidgetTester tester) async {
      pron = FakePronunciation();
      answers = Answers();
      await _pump(
          tester,
          SayItProbe(
              item: _grammar,
              probe: _probe(_grammar, 'ex0'),
              state: _learning('mari.L26.1', 2),
              pronunciation: pron,
              onAnswer: answers.call));
    }

    Future<void> say(WidgetTester tester, Judgement j) async {
      await _tap(tester, 'Say it');
      expect(pron.referenceTexts.last, 'あたまが いたいんです。');
      pron.answer(j);
      await tester.pump();
      await tester.pump();
    }

    void expectSayIt(Grade grade) => _expectDraft(answers.single,
        itemId: 'mari.L26.1',
        probeId: 'ex0',
        template: kSayItTemplate,
        grade: grade,
        selfGraded: false,
        sayIt: true);

    testWidgets('a correct score is clear on the Say-it track', (tester) async {
      await open(tester);
      await say(tester, Judgement.correct);
      expectSayIt(Grade.clear);
    });

    testWidgets('a close score is hinted', (tester) async {
      await open(tester);
      await say(tester, Judgement.close);
      expectSayIt(Grade.hinted);
    });

    testWidgets('a wrong score is wrong', (tester) async {
      await open(tester);
      await say(tester, Judgement.wrong);
      expectSayIt(Grade.wrong);
    });

    testWidgets('unverified then Got it is self', (tester) async {
      await open(tester);
      await say(tester, Judgement.unverified);
      expect(answers.list, isEmpty, reason: 'waits for the self-mark');
      await _tap(tester, 'Got it');
      expectSayIt(Grade.self);
    });

    testWidgets('unverified then Missed it is unscored, never wrong',
        (tester) async {
      await open(tester);
      await say(tester, Judgement.unverified);
      await _tap(tester, 'Missed it');
      expectSayIt(Grade.unscored);
    });

    testWidgets('Skip is unscored', (tester) async {
      await open(tester);
      await _tap(tester, 'Skip');
      expectSayIt(Grade.unscored);
    });

    testWidgets('one form of a ／-joined example is shown and scored',
        (tester) async {
      pron = FakePronunciation();
      answers = Answers();
      const joined = ProbeDef(
          id: 'ex1',
          template: kSayItTemplate,
          text: 'いこう／たべよう',
          answer: 'いこう／たべよう',
          production: true,
          selfGraded: true,
          scored: false);
      await _pump(
          tester,
          SayItProbe(
              item: _grammar,
              probe: joined,
              state: _learning('mari.L26.1', 2),
              pronunciation: pron,
              sentence: 'いこう',
              onAnswer: answers.call));
      expect(find.text('いこう'), findsOneWidget);
      expect(find.text('いこう／たべよう'), findsNothing);
      await _tap(tester, 'Say it');
      expect(pron.referenceTexts.last, 'いこう');
      pron.answer(Judgement.correct);
      await tester.pump();
      await tester.pump();
      _expectDraft(answers.single,
          itemId: 'mari.L26.1',
          probeId: 'ex1',
          template: kSayItTemplate,
          grade: Grade.clear,
          selfGraded: false,
          sayIt: true);
    });

    testWidgets('leaving mid-check cancels it and drops the result',
        (tester) async {
      await open(tester);
      await _tap(tester, 'Say it');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(pron.cancels, 1);
      await tester.pump();
      expect(answers.list, isEmpty);
    });
  });

  testWidgets('a draft writes through the recorder to the attempt log',
      (tester) async {
    final store = JpStoreMemory();
    final recorder = AttemptRecorder.on(store,
        lookup: (id) => id == _conj.id ? _conj : null);
    await _pump(
        tester,
        ConjugationProbe(
            item: _conj,
            probe: _conj.probes.single,
            state: const MasteryState.initial('conj.te.g1'),
            onAnswer: (d) => recorder.record(d)));
    await _tap(tester, 'Show answer');
    await _tap(tester, 'Got it');
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await recorder.idle;
    final written = await store.attempts();
    expect(written, hasLength(1));
    final a = written.single;
    expect(a.itemId, 'conj.te.g1');
    expect(a.probeId, 'かく');
    expect(a.grade, Grade.clear);
    expect(a.rating, kRatingGood);
    expect(a.selfGraded, isTrue);
    expect(a.revealed, isTrue);
  });

  group('lesson review (plan 2026-11-06, Task 2, PIN-5)', () {
    DrillAnswer drawn(ItemDef item, String probeId, Grade g,
            {int hintLevel = 0,
            bool revealed = false,
            bool sayIt = false,
            DateTime? atUtc}) =>
        DrillAnswer(
            itemId: item.id,
            probeId: probeId,
            template: _probe(item, probeId).template,
            production: _probe(item, probeId).production,
            selfGraded: false,
            grade: g,
            hintLevel: hintLevel,
            revealed: revealed,
            sayIt: sayIt,
            answerShown: true,
            atUtc: atUtc);

    test('a clear after a review is hinted at hint level 1, the rest kept', () {
      final d = afterLessonReview(drawn(_grammar, 'p1', Grade.clear));
      expect(d.grade, Grade.hinted);
      expect(d.hintLevel, 1);
      expect(d.itemId, _grammar.id);
      expect(d.probeId, 'p1');
      expect(d.template, 'fill');
      expect(d.production, isTrue);
      expect(d.selfGraded, isFalse);
      expect(d.answerShown, isTrue);
      expect(d.revealed, isFalse);
      expect(d.sayIt, isFalse);
      expect(d.atUtc, isNull);
    });

    test('a say-it clear after a review keeps sayIt, revealed and atUtc', () {
      final at = DateTime.utc(2026, 11, 6, 10);
      final d = afterLessonReview(drawn(_grammar, 'ex0', Grade.clear,
          revealed: true, sayIt: true, atUtc: at));
      expect(d.grade, Grade.hinted);
      expect(d.hintLevel, 1);
      expect(d.sayIt, isTrue, reason: 'still the spoken track (Source.sayIt)');
      expect(d.revealed, isTrue);
      expect(d.atUtc, at);
      expect(d.probeId, 'ex0');
      expect(d.template, kSayItTemplate);
    });

    test('a choose clear after a review is hinted (a choose card has no hint)',
        () {
      final d = afterLessonReview(drawn(_grammar, 'p0', Grade.clear));
      expect(d.grade, Grade.hinted);
      expect(d.hintLevel, 1);
      expect(d.template, 'choose');
    });

    test('a grammar hint plus a review is not counted twice', () {
      final hinted = drawn(_grammar, 'p1', Grade.hinted, hintLevel: 1);
      final d = afterLessonReview(hinted);
      expect(d.grade, Grade.hinted);
      expect(d.hintLevel, 1);
    });

    test('wrong, self and unscored are untouched', () {
      for (final g in [Grade.wrong, Grade.self, Grade.unscored]) {
        final before = drawn(_word, 'typed', g, revealed: g == Grade.wrong);
        final d = afterLessonReview(before);
        expect(identical(d, before), isTrue, reason: g.name);
        expect(d.grade, g);
        expect(d.hintLevel, 0);
      }
    });

    test('the link names the lesson and the idea of each kind', () {
      final particle = ItemDef(
          id: 'mari.particle.1',
          kind: ItemKind.particle,
          title: 'は',
          prereqLevel: 0,
          lesson: 21,
          probes: const []);
      final untaught = ItemDef(
          id: 'mari.particle.2',
          kind: ItemKind.particle,
          title: 'へ',
          prereqLevel: 0,
          probes: const []);
      expect(reviewLessonDetail(_grammar), '第26課 · 〜んです');
      expect(reviewLessonDetail(_word), '第30課 · かばん');
      expect(reviewLessonDetail(particle), '第21課 · は');
      expect(reviewLessonDetail(untaught), 'Particles · へ');
      expect(reviewLessonDetail(_conj), 'Conjugation · te, group 1');
      expect(reviewLessonDetail(_pair), 'Verb pairs · あく / あける');
      expect(reviewLessonDetail(_row), 'Reference tables · Counters: ほん');
    });

    testWidgets('the link shows its name, runs its tap, and marks a review',
        (tester) async {
      var taps = 0;
      await _pump(
          tester, ReviewLessonLink(item: _grammar, onTap: () => taps++));
      expect(find.text(kReviewTheLesson), findsOneWidget);
      expect(find.text('第26課 · 〜んです'), findsOneWidget);
      expect(find.text(kLessonReviewed), findsNothing);
      await _tap(tester, kReviewTheLesson);
      expect(taps, 1);

      await _pump(tester,
          ReviewLessonLink(item: _grammar, reviewed: true, onTap: () {}));
      expect(find.text(kReviewTheLesson), findsOneWidget);
      expect(find.text(kLessonReviewed), findsOneWidget);
    });
  });
}
