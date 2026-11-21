// Say-it cards on the web (plan 2026-11-19, Task 9, End state 10, PIN-6). The say-it cards use
// speech where the browser can hear Japanese and fall back to type-it where it cannot, and a
// type-it answer logs no spoken attempt.
//
// The file runs in Chrome (`--platform chrome`) and on the VM, so it reads no file from disk.
// The browser's answer comes through the SpeechService seam (`web`, `browserSpeech`), so both
// fallbacks run in any browser. The real probe is run once against the page as well: a
// recognizer name no browser has must read as no recognizer in Chrome, and as `works` on the
// VM, where there is no browser to ask.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore;
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/probe_widgets.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart';

import 'support/fake_pronunciation.dart';

// --- fakes -------------------------------------------------------------------

class _Stt implements SttEngine {
  bool initialised = true;
  void Function(String code)? onError;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({required void Function(String code) onError}) async {
    this.onError = onError;
    return initialised;
  }

  @override
  Future<void> listen({
    required Duration listenFor,
    required void Function(List<String> alternates) onFinal,
    required void Function(double raw) onLevel,
  }) async =>
      _listening = true;

  @override
  Future<void> stop() async => _listening = false;

  @override
  Future<void> cancel() async => _listening = false;
}

class _Tts implements TtsEngine {
  @override
  set onDone(void Function()? f) {}
  @override
  Future<void> configure() async {}
  @override
  Future<List<Map<String, String>>> voices() async => const [
        {'name': 'ja', 'locale': 'ja-JP'}
      ];
  @override
  Future<List<String>> languages() async => const ['ja-JP'];
  @override
  Future<void> use(Map<String, String> voice) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

/// A speech service acting as the web build, where the browser answers [support].
SpeechService _webSpeech(SpeechSupport support, {_Stt? stt}) =>
    SpeechService.withEngines(
        stt: stt ?? _Stt(),
        tts: _Tts(),
        web: true,
        browserSpeech: () async => support);

// --- items -------------------------------------------------------------------

const _fill = ProbeDef(
    id: 'p1',
    template: 'fill',
    text: 'きょうは しごとが やすみ＿＿。',
    answer: 'なんです',
    production: true);

const _choose = ProbeDef(
    id: 'p0', template: 'choose', text: 'あした テストが ＿＿んです。', answer: 'ある');

final _grammar = ItemDef(
  id: 'mari.L26.1',
  kind: ItemKind.grammar,
  title: '〜んです',
  prereqLevel: 2,
  lesson: 26,
  probes: [
    _choose,
    _fill,
    ProbeDef(
        id: sayCardId('p0'),
        template: kSayCardTemplate,
        text: _choose.text,
        answer: 'あした テストが あるんです。',
        production: true),
    ProbeDef(
        id: sayCardId('p1'),
        template: kSayCardTemplate,
        text: _fill.text,
        answer: 'なんです',
        production: true),
    const ProbeDef(
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
    ProbeDef(
        id: kWordSayCardId,
        template: kSayCardTemplate,
        text: 'bag',
        answer: 'かばん',
        production: true),
  ],
);

/// A one-lesson grammar file for the speak drill: lesson 26, one example in kanji.
const _grammarDoc = {
  'grammar': [
    {
      'lesson': 26,
      'points': [
        {
          'id': 'mari.L26.1',
          'examples': [
            {
              'jp': 'あたまが いたいんです。',
              'jp_ruby': '頭{あたま}が 痛{いた}いんです。',
              'en': 'I have a headache.',
            },
          ],
        },
      ],
    },
  ],
};

ProbeDef _probe(ItemDef item, String id) =>
    item.probes.firstWhere((p) => p.id == id);

const _state = MasteryState.initial('x');

/// The templates no type-it answer may ever go out on.
const _spokenTemplates = {'spoken', kSayCardTemplate};

// --- harness -----------------------------------------------------------------

Future<void> _pump(WidgetTester tester, Widget probe) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: probe))));
  await tester.pump();
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

/// The enabled state of the button labelled [label].
VoidCallback? _action(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)))
    .onPressed;

final _noRecognizerLine = typeItLine(SpeechSupport.noRecognizer)!;
final _noJapaneseLine = typeItLine(SpeechSupport.noJapanese)!;

void main() {
  group('SpeechService detects what the browser offers', () {
    test('off the web speech works at once and the browser is never asked',
        () async {
      var asked = 0;
      final s = SpeechService.withEngines(
          stt: _Stt(),
          tts: _Tts(),
          browserSpeech: () async {
            asked++;
            return SpeechSupport.noRecognizer;
          });
      expect(s.speechSupport, SpeechSupport.works);
      expect(await s.checkSpeechSupport(), SpeechSupport.works);
      expect(asked, 0);
    });

    test('on the web the answer is unknown until the browser is asked, once',
        () async {
      var asked = 0;
      final s = SpeechService.withEngines(
          stt: _Stt(),
          tts: _Tts(),
          web: true,
          browserSpeech: () async {
            asked++;
            return SpeechSupport.noJapanese;
          });
      expect(s.speechSupport, isNull);
      final both =
          await Future.wait([s.checkSpeechSupport(), s.checkSpeechSupport()]);
      expect(both, [SpeechSupport.noJapanese, SpeechSupport.noJapanese]);
      expect(await s.checkSpeechSupport(), SpeechSupport.noJapanese);
      expect(s.speechSupport, SpeechSupport.noJapanese);
      expect(asked, 1);
    });

    test('a probe that throws cannot rule speech out', () async {
      final s = SpeechService.withEngines(
          stt: _Stt(),
          tts: _Tts(),
          web: true,
          browserSpeech: () async => throw StateError('no answer'));
      expect(await s.checkSpeechSupport(), SpeechSupport.works);
    });

    test('a recognizer that refuses ja_JP downgrades to no Japanese', () async {
      final stt = _Stt();
      final s = _webSpeech(SpeechSupport.works, stt: stt);
      expect(await s.checkSpeechSupport(), SpeechSupport.works);
      final listen = s.listenOnce(
          expectedKana: 'かばん', limit: const Duration(milliseconds: 10));
      await Future<void>.delayed(Duration.zero);
      stt.onError!('language-not-supported');
      await listen;
      expect(s.speechSupport, SpeechSupport.noJapanese);
      expect(await s.checkSpeechSupport(), SpeechSupport.noJapanese);
    });

    test('a recognizer that will not start on the web reads as none', () async {
      final s =
          _webSpeech(SpeechSupport.works, stt: _Stt()..initialised = false);
      expect(await s.prepareMic(), isFalse);
      expect(s.speechSupport, SpeechSupport.noRecognizer);
    });

    test('the phone keeps works after a recognizer error', () async {
      final stt = _Stt()..initialised = false;
      final s = SpeechService.withEngines(stt: stt, tts: _Tts());
      expect(await s.prepareMic(), isFalse);
      expect(s.speechSupport, SpeechSupport.works);
    });

    test('isLanguageUnsupported reads every platform spelling', () {
      for (final c in [
        'error_language_not_supported',
        'error_language_unavailable',
        'language-not-supported',
      ]) {
        expect(SpeechService.isLanguageUnsupported(c), isTrue, reason: c);
      }
      expect(SpeechService.isLanguageUnsupported('no-speech'), isFalse);
    });

    test('the real probe finds no recognizer under a name no browser has',
        () async {
      final s = await browserSpeechSupport(
          recognizerNames: const ['habitCraftsNoSuchRecognizer']);
      expect(s, kIsWeb ? SpeechSupport.noRecognizer : SpeechSupport.works);
    });

    test('the real probe answers for this browser without throwing', () async {
      final s = await browserSpeechSupport();
      expect(SpeechSupport.values, contains(s));
    });

    test('typeItLine names the reason and is null where speech works', () {
      expect(typeItLine(SpeechSupport.works), isNull);
      expect(typeItLine(null), isNull);
      expect(_noRecognizerLine, contains('type it instead'));
      expect(_noJapaneseLine, contains('Japanese'));
    });
  });

  group('the say card falls back to type-it', () {
    late FakePronunciation pron;
    late List<DrillAnswer> answers;

    Future<void> open(WidgetTester tester, ItemDef item, String probeId,
        {SpeechSupport support = SpeechSupport.noRecognizer}) async {
      pron = FakePronunciation();
      answers = [];
      await _pump(
          tester,
          SayCardProbe(
              item: item,
              probe: _probe(item, probeId),
              state: _state,
              pronunciation: pron,
              speech: _webSpeech(support),
              onAnswer: answers.add));
    }

    testWidgets('no Say it, the type-it form and the reason instead',
        (tester) async {
      await open(tester, _grammar, 'say.p1');
      expect(find.text('Say it'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(_noRecognizerLine), findsOneWidget);
    });

    testWidgets('a right typed answer is a clear on the type-it twin',
        (tester) async {
      await open(tester, _grammar, 'say.p1');
      await _type(tester, 'なんです');
      await _tap(tester, 'Check');
      final a = answers.single;
      expect(a.probeId, 'p1');
      expect(a.template, 'fill');
      expect(a.grade, Grade.clear);
      expect(a.selfGraded, isFalse);
      expect(pron.checks, isEmpty, reason: 'nothing was recorded');
    });

    testWidgets('a wrong typed answer is wrong on the twin', (tester) async {
      await open(tester, _grammar, 'say.p1');
      await _type(tester, 'です');
      await _tap(tester, 'Check');
      expect(answers.single.probeId, 'p1');
      expect(answers.single.grade, Grade.wrong);
    });

    testWidgets('a twin that is not a type-it card is unscored, never a clear',
        (tester) async {
      await open(tester, _grammar, 'say.p0');
      await _type(tester, 'あした テストが あるんです。');
      await _tap(tester, 'Check');
      final a = answers.single;
      expect(a.probeId, 'p0');
      expect(a.template, 'choose');
      expect(a.grade, Grade.unscored);
    });

    testWidgets('a word say card goes on the typed probe', (tester) async {
      await open(tester, _word, kWordSayCardId,
          support: SpeechSupport.noJapanese);
      expect(find.text(_noJapaneseLine), findsOneWidget);
      await _type(tester, 'かばん');
      await _tap(tester, 'Check');
      expect(answers.single.probeId, 'typed');
      expect(answers.single.template, 'typed');
      expect(answers.single.grade, Grade.clear);
    });

    testWidgets('an unjudged typed answer asks, and Got it is self',
        (tester) async {
      await open(tester, _word, kWordSayCardId);
      await _type(tester, '鞄');
      await _tap(tester, 'Check');
      expect(answers, isEmpty, reason: 'waits for the mark');
      await _tap(tester, 'Got it');
      expect(answers.single.probeId, 'typed');
      expect(answers.single.grade, Grade.self);
    });

    testWidgets('Skip is unscored on the twin, not the say card',
        (tester) async {
      await open(tester, _grammar, 'say.p1');
      await _tap(tester, 'Skip');
      expect(answers.single.probeId, 'p1');
      expect(answers.single.grade, Grade.unscored);
    });

    testWidgets('where speech works the card asks for speech as before',
        (tester) async {
      await open(tester, _grammar, 'say.p1', support: SpeechSupport.works);
      expect(find.byType(TextField), findsNothing);
      await _tap(tester, 'Say it');
      expect(pron.checks, hasLength(1));
    });

    testWidgets('Say it waits, disabled, until the browser answers',
        (tester) async {
      pron = FakePronunciation();
      final answer = Completer<SpeechSupport>();
      await _pump(
          tester,
          SayCardProbe(
              item: _grammar,
              probe: _probe(_grammar, 'say.p1'),
              state: _state,
              pronunciation: pron,
              speech: SpeechService.withEngines(
                  stt: _Stt(),
                  tts: _Tts(),
                  web: true,
                  browserSpeech: () => answer.future),
              onAnswer: (_) {}));
      expect(_action(tester, 'Say it'), isNull);
      answer.complete(SpeechSupport.works);
      await tester.pump();
      await tester.pump();
      expect(_action(tester, 'Say it'), isNotNull);
    });
  });

  group('the word card and the Say-it sentence fall back to type-it', () {
    testWidgets('the word card drops Say it and Skip logs on typed',
        (tester) async {
      final pron = FakePronunciation();
      final answers = <DrillAnswer>[];
      await _pump(
          tester,
          WordRecallProbe(
              item: _word,
              probe: _probe(_word, 'spoken'),
              state: _state,
              pronunciation: pron,
              speech: _webSpeech(SpeechSupport.noRecognizer),
              onAnswer: answers.add));
      expect(find.text('Say it'), findsNothing);
      expect(find.text('Type the word'), findsOneWidget);
      expect(find.text(_noRecognizerLine), findsOneWidget);
      await _tap(tester, 'Skip');
      expect(answers.single.probeId, 'typed');
      expect(_spokenTemplates, isNot(contains(answers.single.template)));
      expect(pron.checks, isEmpty);
    });

    testWidgets('the word card still types and checks', (tester) async {
      final answers = <DrillAnswer>[];
      await _pump(
          tester,
          WordRecallProbe(
              item: _word,
              probe: _probe(_word, 'spoken'),
              state: _state,
              pronunciation: FakePronunciation(),
              speech: _webSpeech(SpeechSupport.noJapanese),
              onAnswer: answers.add));
      await _type(tester, 'かばん');
      await _tap(tester, 'Check');
      expect(answers.single.probeId, 'typed');
      expect(answers.single.grade, Grade.clear);
    });

    testWidgets('a typed Say-it sentence is unscored and records nothing',
        (tester) async {
      final pron = FakePronunciation();
      final answers = <DrillAnswer>[];
      await _pump(
          tester,
          SayItProbe(
              item: _grammar,
              probe: _probe(_grammar, 'ex0'),
              state: _state,
              pronunciation: pron,
              speech: _webSpeech(SpeechSupport.noRecognizer),
              onAnswer: answers.add));
      expect(find.text('Say it'), findsNothing);
      expect(find.text('Type the sentence'), findsOneWidget);
      await _type(tester, 'あたまが いたいんです');
      await _tap(tester, 'Check');
      expect(find.text('Typed right.'), findsOneWidget);
      final a = answers.single;
      expect(a.probeId, 'ex0');
      expect(a.sayIt, isTrue);
      expect(a.grade, Grade.unscored);
      expect(pron.checks, isEmpty);
    });
  });

  group('the speak drill falls back to type-it', () {
    late FakePronunciation pron;
    late JpStoreMemory store;
    late AttemptRecorder recorder;
    late SpeakSentence first;

    Future<void> open(WidgetTester tester, SpeechSupport support) async {
      SharedPreferences.setMockInitialValues({});
      store = JpStoreMemory();
      debugSetSharedJpStore(store);
      addTearDown(() => debugSetSharedJpStore(null));
      recorder = AttemptRecorder.on(store);
      pron = FakePronunciation();
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // The grammar file comes through the asset channel, served here from a one-lesson doc:
      // a browser test cannot read the file from disk. Every other asset goes on as before.
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer
            .asUint8List(message.offsetInBytes, message.lengthInBytes));
        if (Uri.decodeFull(key) == 'assets/lessons/jp_grammar.json') {
          final bytes = utf8.encode(json.encode(_grammarDoc));
          return ByteData.sublistView(Uint8List.fromList(bytes));
        }
        return messenger.delegate.send('flutter/assets', message);
      });
      addTearDown(
          () => messenger.setMockMessageHandler('flutter/assets', null));
      final doc = (await tester.runAsync(JpGrammarData.load))!;
      final lesson = (doc['grammar'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((l) => l['lesson'] == 26);
      first = lessonSentences(lesson).first;
      await tester.pumpWidget(MaterialApp(
          home: QuietRoomSpeakWidget(
        lesson: 26,
        newService: (_) => pron,
        speech: _webSpeech(support),
        play: (_) async => null,
        recorder: recorder,
        store: store,
      )));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    testWidgets('Speak gives way to the type-it form, and nothing is logged',
        (tester) async {
      await open(tester, SpeechSupport.noRecognizer);
      expect(find.text('Speak'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text(_noRecognizerLine), findsOneWidget);
      await _type(tester, first.kana);
      await _tap(tester, 'Check');
      expect(find.text('Typed right.'), findsOneWidget);
      await _type(tester, 'ちがう');
      await _tap(tester, 'Check');
      expect(find.text('Not quite. Compare it with the sentence.'),
          findsOneWidget);
      await tester.pump();
      expect(pron.checks, isEmpty, reason: 'the microphone never opened');
      expect(await store.speakScores(), isEmpty,
          reason: 'no speak_score event');
      expect(await store.attempts(), isEmpty, reason: 'no Say-it attempt');
    });

    testWidgets('where speech works the drill offers Speak as before',
        (tester) async {
      await open(tester, SpeechSupport.works);
      expect(find.text('Speak'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(_action(tester, 'Speak'), isNotNull);
    });
  });
}
