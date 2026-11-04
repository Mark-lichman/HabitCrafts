// Widget tests for the probe widgets (plan 2026-11-02, Task 19).
//
// Each probe kind is driven to each grade it can report, with fake speech and pronunciation
// services, and the test reads the `DrillAnswer` draft the widget hands on: the grade, the
// template, the hint level, the revealed flag and the Say-it flag. Every widget shows the
// item's state pill with its n of 4.
//
// The rules under test: a hinted answer is hinted, never clear (PIN-3); a hint ladder's
// revealing rung grades any answer wrong (D17); on a self-graded probe Got it after the
// reveal is clear and Missed it is wrong (PIN-13); unverified is never wrong; an empty Check
// is no attempt.

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
    for (final c in listens) {
      if (!c.isCompleted) {
        c.complete(const SpeechResult('', Judgement.unverified));
      }
    }
  }

  void answer(String heard, Judgement j) =>
      listens.last.complete(SpeechResult(heard, j));
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
    test('every state names itself and its n of 4', () {
      expect(probeStateLabel(const MasteryState.initial('x')), 'New · 0 of 4');
      expect(probeStateLabel(_learning('x', 2)), 'Learning · 2 of 4');
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
        expect(find.text('Learning · 3 of 4'), findsOneWidget,
            reason: '${w.runtimeType} shows the pill');
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
  });

  group('typed fill', () {
    Future<Answers> open(WidgetTester tester) async {
      final answers = Answers();
      await _pump(
          tester,
          TypedFillProbe(
              item: _grammar,
              probe: _probe(_grammar, 'p1'),
              state: const MasteryState.initial('mari.L26.1'),
              hint: 'A noun needs な before んです',
              onAnswer: answers.call));
      return answers;
    }

    testWidgets('the hint stays behind a tap', (tester) async {
      await open(tester);
      expect(find.text('A noun needs な before んです'), findsNothing);
      await _tap(tester, 'Show hint');
      expect(find.text('A noun needs な before んです'), findsOneWidget);
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
      await _tap(tester, 'Show hint');
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
      expect(find.text('なんです'), findsOneWidget, reason: 'the answer shows');
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
    });

    testWidgets('an empty Check is not an attempt', (tester) async {
      final a = await open(tester);
      await _tap(tester, 'Check');
      expect(a.list, isEmpty);
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
      expect(find.textContaining('transitive partner'), findsOneWidget);
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
      expect(find.textContaining('intransitive partner'), findsOneWidget);
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
}
