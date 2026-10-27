// Widget tests for the grammar screen: the By use view, a choice question's feedback,
// the typed-answer box (PIN-3), the 漢字 toggle (PIN-4), the tap-a-word reading hint
// (PIN-16) and the speaking drill link (PIN-6).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart'
    show RubyTapText, rubyWords;
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/flutter_flow/quiet_room.dart';

import 'jp_screen_harness.dart';

/// The opening lesson, the one the screen shows first.
Map<String, dynamic> firstLesson() =>
    (readLessonFile()['grammar'] as List).first as Map<String, dynamic>;

/// The opening lesson's fill-in items, in screen order.
List<Map<String, dynamic>> firstFills() => [
      for (final p
          in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
        for (final q in (p['practice'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          if ((q['options'] as List? ?? const []).isEmpty) q,
    ];

/// The typed-answer boxes, in screen order. The search box has another hint.
final Finder answerBoxes = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Type the answer');

/// A fill-in prompt as the screen shows it before an answer.
String unanswered(String prompt) => prompt.replaceAll('＿＿', '＿＿＿');

/// A right pick names no wrong-option reason. The check reads each reason's own
/// text, which is the same whichever surface the 漢字 toggle shows, so it cannot
/// pass on a label mismatch. An item with no reason would make the loop empty
/// and the check vacuous, so the item must carry one.
void expectNoReason(Map<String, dynamic> item) {
  expect(item['why_wrong'], isNotEmpty,
      reason: 'the right-pick check needs a reason to look for');
  for (final reason in (item['why_wrong'] as Map? ?? const {}).values) {
    expect(find.textContaining(reason as String), findsNothing);
  }
}

void main() {
  testWidgets('By use lists every pattern tagged with the chosen use',
      (tester) async {
    final doc = readLessonFile();
    final use = (doc['uses'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((u) => u['id'] == 'advise');
    final patterns = [
      for (final l in (doc['grammar'] as List).cast<Map<String, dynamic>>())
        for (final p in (l['points'] as List).cast<Map<String, dynamic>>())
          if ((p['uses'] as List? ?? const []).contains('advise'))
            p['pattern'] as String,
    ];
    expect(patterns, isNotEmpty);

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());
    await tester.tap(find.text('By use'));
    await tester.pump();
    expect(find.text('Pick what you want to say.'), findsOneWidget);

    await tester.tap(find.text('${use['label']}  ${patterns.length}'));
    await tester.pump();
    await tester.pump();

    // The heading names the use, and the screen lists each of its patterns.
    expect(find.text(use['label'] as String), findsOneWidget);
    expect(find.textContaining('${patterns.length} patterns, from lessons'),
        findsOneWidget);
    for (final p in patterns) {
      expect(find.text(p), findsOneWidget);
    }
  });

  testWidgets('a wrong choice shows why that option is wrong', (tester) async {
    final doc = readLessonFile();
    final first = (doc['grammar'] as List).first as Map<String, dynamic>;
    // The first choice item in the opening lesson whose wrong options carry a reason.
    final item = [
      for (final p in (first['points'] as List).cast<Map<String, dynamic>>())
        for (final q in (p['practice'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          if ((q['options'] as List? ?? const []).isNotEmpty &&
              (q['why_wrong'] as Map? ?? const {}).isNotEmpty)
            q,
    ].first;
    final why = (item['why_wrong'] as Map).cast<String, String>();
    final wrong = why.keys.first;
    expect(wrong, isNot(item['answer']));

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());
    expect(find.textContaining('$wrong: ${why[wrong]}'), findsNothing);

    // No earlier widget in this lesson shows this option text, so .first is this item's option.
    await tester.tap(find.text(wrong).first);
    await tester.pump();

    expect(find.textContaining('$wrong: ${why[wrong]}'), findsOneWidget);
    if (item['hint'] != null) {
      expect(find.textContaining(item['hint'] as String), findsWidgets);
    }
  });

  testWidgets('a right choice shows no reason', (tester) async {
    final doc = readLessonFile();
    final first = (doc['grammar'] as List).first as Map<String, dynamic>;
    final item = [
      for (final p in (first['points'] as List).cast<Map<String, dynamic>>())
        for (final q in (p['practice'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          if ((q['options'] as List? ?? const []).isNotEmpty &&
              (q['why_wrong'] as Map? ?? const {}).isNotEmpty)
            q,
    ].first;

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());
    await tester.tap(find.text(item['answer'] as String).first);
    await tester.pump();

    // The prompt swaps ＿＿ for ［answer］ once a pick is made, so this proves the tap registered.
    expect(find.textContaining('［${item['answer']}］'), findsOneWidget);
    expectNoReason(item);
  });

  testWidgets('every typed-answer box asks for the Japanese keyboard',
      (tester) async {
    final fills = firstFills();
    expect(fills, isNotEmpty);

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

    expect(answerBoxes, findsNWidgets(fills.length));
    for (final box in tester.widgetList<TextField>(answerBoxes)) {
      expect(box.hintLocales, contains(const Locale('ja', 'JP')));
    }
  });

  group('typed answers', () {
    /// The first fill-in item in the opening lesson whose answer has a kanji version.
    ({int index, Map<String, dynamic> q}) kanjiFill() {
      final fills = firstFills();
      final i = fills.indexWhere(
          (q) => rubySurface(q['answer_ruby'] as String? ?? '') != q['answer']);
      expect(i, isNonNegative, reason: 'no fill-in answer has kanji');
      return (index: i, q: fills[i]);
    }

    testWidgets('the kanji version of the answer is marked correct',
        (tester) async {
      final f = kanjiFill();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(
          answerBoxes.at(f.index), rubySurface(f.q['answer_ruby'] as String));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Correct.'), findsOneWidget);
      // The prompt fills its blank with the answer, and the box goes away.
      expect(
          find.text(
              (f.q['prompt'] as String).replaceAll('＿＿', '［${f.q['answer']}］')),
          findsOneWidget);
      expect(answerBoxes, findsNWidgets(firstFills().length - 1));
    });

    testWidgets('the hiragana answer is marked correct', (tester) async {
      final q = firstFills().first;
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, q['answer'] as String);
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.text('Correct.'), findsOneWidget);
    });

    testWidgets('a wrong kana answer is rejected and the box stays',
        (tester) async {
      final fills = firstFills();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ぬぬぬ');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.text('Correct.'), findsNothing);
      expect(find.textContaining('Not quite.'), findsOneWidget);
      expect(answerBoxes, findsNWidgets(fills.length));
      expect(find.text(unanswered(fills.first['prompt'] as String)),
          findsOneWidget);
    });

    testWidgets('a wrong typed answer shows the hint once', (tester) async {
      final q = firstFills().first;
      final hint = q['hint'] as String?;
      expect(hint, isNotNull, reason: 'the opening fill item carries a hint');
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ぬぬぬ');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      // The 'Hint:' row under the box is the only place the hint appears.
      expect(find.textContaining('Not quite.'), findsOneWidget);
      expect(find.textContaining(hint!), findsOneWidget);
      expect(find.text('Hint: $hint'), findsOneWidget);
    });

    testWidgets('Show answer after a wrong answer drops the retry message',
        (tester) async {
      final q = firstFills().first;
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ぬぬぬ');
      await tester.tap(find.text('Check').first);
      await tester.pump();
      expect(find.textContaining('Not quite.'), findsOneWidget);

      await tester.tap(find.text('Show answer').first);
      await tester.pump();

      // The box and the retry message go together. The prompt shows the answer.
      expect(find.textContaining('Not quite.'), findsNothing);
      expect(
          find.text(
              (q['prompt'] as String).replaceAll('＿＿', '［${q['answer']}］')),
          findsOneWidget);
    });

    testWidgets('an answer it cannot compare goes to self-check, not wrong',
        (tester) async {
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ittara');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.textContaining('Not quite.'), findsNothing);
      expect(find.textContaining("Can't check that spelling"), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Missed it'), findsOneWidget);
    });
  });

  group('the 漢字 toggle', () {
    /// The opening lesson's first example whose kanji version differs from its hiragana.
    Map<String, dynamic> kanjiExample() => [
          for (final p
              in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
            for (final e in (p['examples'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
              if (rubySurface(e['jp_ruby'] as String? ?? '') != e['jp']) e,
        ].first;

    /// The opening lesson's first fill-in prompt whose kanji version differs.
    Map<String, dynamic> kanjiPrompt() => firstFills().firstWhere(
        (q) => rubySurface(q['prompt_ruby'] as String? ?? '') != q['prompt']);

    testWidgets('hiragana is shown by default', (tester) async {
      final e = kanjiExample();
      final q = kanjiPrompt();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      expect(find.text(e['jp'] as String), findsOneWidget);
      expect(find.text(rubySurface(e['jp_ruby'] as String)), findsNothing);
      expect(find.text(unanswered(q['prompt'] as String)), findsOneWidget);
      expect(find.text(unanswered(rubySurface(q['prompt_ruby'] as String))),
          findsNothing);
    });

    testWidgets('the toggle shows the kanji versions, and back again',
        (tester) async {
      final e = kanjiExample();
      final q = kanjiPrompt();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.tap(find.text('漢字'));
      await tester.pump();

      expect(find.text(rubySurface(e['jp_ruby'] as String)), findsOneWidget);
      expect(find.text(e['jp'] as String), findsNothing);
      expect(find.text(unanswered(rubySurface(q['prompt_ruby'] as String))),
          findsOneWidget);
      expect(find.text(unanswered(q['prompt'] as String)), findsNothing);

      await tester.tap(find.text('漢字'));
      await tester.pump();

      expect(find.text(e['jp'] as String), findsOneWidget);
      expect(find.text(rubySurface(e['jp_ruby'] as String)), findsNothing);
    });

    testWidgets('a choice still checks the right option in kanji',
        (tester) async {
      // The first choice item in the opening lesson whose answer has a kanji version.
      final item = [
        for (final p
            in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
          for (final q in (p['practice'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
            if ((q['options'] as List? ?? const []).isNotEmpty &&
                rubySurface(q['answer_ruby'] as String? ?? '') != q['answer'])
              q,
      ].first;
      final shown = rubySurface(item['answer_ruby'] as String);
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.tap(find.text('漢字'));
      await tester.pump();
      await tester.tap(find.text(shown).first);
      await tester.pump();

      expect(
          find.text(rubySurface(item['prompt_ruby'] as String)
              .replaceAll('＿＿', '［$shown］')),
          findsOneWidget);
      expectNoReason(item);
    });

    testWidgets('a wrong pick in kanji quotes the kanji option in its reason',
        (tester) async {
      // The first choice item in the opening lesson with a reason for a wrong option
      // whose kanji version differs from its hiragana.
      final item = [
        for (final p
            in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
          for (final q in (p['practice'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
            if ((q['options'] as List? ?? const []).isNotEmpty &&
                (q['why_wrong'] as Map? ?? const {}).keys.any((w) {
                  final i = (q['options'] as List).indexOf(w);
                  final ruby = (q['options_ruby'] as List?)?[i] as String?;
                  return ruby != null && rubySurface(ruby) != w;
                }))
              q,
      ].first;
      final options = (item['options'] as List).cast<String>();
      final optionsRuby = (item['options_ruby'] as List).cast<String>();
      final why = (item['why_wrong'] as Map).cast<String, String>();
      final wrong = why.keys
          .firstWhere((w) => rubySurface(optionsRuby[options.indexOf(w)]) != w);
      final shown = rubySurface(optionsRuby[options.indexOf(wrong)]);
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.tap(find.text('漢字'));
      await tester.pump();
      await tester.tap(find.text(shown).first);
      await tester.pump();

      // The reason quotes the option as shown, not its hiragana key.
      expect(find.textContaining('$shown: ${why[wrong]}'), findsOneWidget);
      expect(find.textContaining('$wrong: ${why[wrong]}'), findsNothing);
    });
  });

  group('the reading hint', () {
    /// The opening lesson's first example with a kanji word, with one kanji word and
    /// one plain word that each occur once in the shown sentence, so a tap on either
    /// can only land on that word.
    ({
      String ruby,
      String surface,
      String en,
      ({String text, String? reading}) kanji,
      ({String text, String? reading}) plain,
    }) hintExample() {
      for (final p
          in (firstLesson()['points'] as List).cast<Map<String, dynamic>>()) {
        for (final e in (p['examples'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          final ruby = e['jp_ruby'] as String?;
          if (ruby == null) continue;
          final surface = rubySurface(ruby);
          bool once(String w) =>
              w.trim().isNotEmpty &&
              surface.indexOf(w) == surface.lastIndexOf(w);
          final words = rubyWords(ruby);
          final kanji = words.where((w) => w.reading != null && once(w.text));
          final plain = words.where((w) => w.reading == null && once(w.text));
          if (kanji.isNotEmpty && plain.isNotEmpty) {
            return (
              ruby: ruby,
              surface: surface,
              en: e['en'] as String? ?? '',
              kanji: kanji.first,
              plain: plain.first,
            );
          }
        }
      }
      fail('no opening-lesson example has a kanji word and a plain word');
    }

    Finder sentence(String ruby) =>
        find.byWidgetPredicate((w) => w is RubyTapText && w.ruby == ruby);

    /// The sentence's spans: each word's own color, or the sentence color it inherits.
    Map<String, Color?> wordColors(WidgetTester tester, String ruby) {
      final text = tester.widget<Text>(find
          .descendant(of: sentence(ruby), matching: find.byType(Text))
          .first);
      return {
        for (final s in (text.textSpan! as TextSpan).children!.cast<TextSpan>())
          s.text!: s.style?.color ?? text.style?.color,
      };
    }

    Future<void> kanjiOn(WidgetTester tester, {bool dark = false}) async {
      await pumpStudyScreen(
          tester,
          dark
              ? Theme(
                  data: ThemeData(brightness: Brightness.dark),
                  child: const QuietRoomGrammarWidget())
              : const QuietRoomGrammarWidget());
      await tester.tap(find.text('漢字'));
      await tester.pump();
    }

    testWidgets('hiragana view has no tappable words', (tester) async {
      final ex = hintExample();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      expect(find.byType(RubyTapText), findsNothing);
      expect(sentence(ex.ruby), findsNothing);
    });

    testWidgets('a kanji word shows in the hint color, a plain word does not',
        (tester) async {
      final ex = hintExample();
      const day = DaylightTokens();
      await kanjiOn(tester);

      expect(sentence(ex.ruby), findsOneWidget);
      final colors = wordColors(tester, ex.ruby);
      expect(colors[ex.kanji.text], day.brand600);
      expect(colors[ex.plain.text], day.inkStrong);
      expect(colors[ex.plain.text], isNot(day.brand600));
    });

    testWidgets('the hint color is the Nightfall token in dark',
        (tester) async {
      final ex = hintExample();
      const night = NightfallTokens();
      await kanjiOn(tester, dark: true);

      final colors = wordColors(tester, ex.ruby);
      expect(colors[ex.kanji.text], night.brand600);
      expect(colors[ex.plain.text], night.inkStrong);
    });

    testWidgets('a tap shows the reading, a second tap hides it',
        (tester) async {
      final ex = hintExample();
      final reading = find.descendant(
          of: sentence(ex.ruby), matching: find.text(ex.kanji.reading!));
      await kanjiOn(tester);
      expect(reading, findsNothing);

      await tester.tapOnText(find.textRange
          .ofSubstring(ex.kanji.text, descendentOf: sentence(ex.ruby)));
      await tester.pump();

      // The reading sits above the word, which is still shown. The tap is the word's,
      // so the row's English stays hidden.
      expect(reading, findsOneWidget);
      if (ex.en.isNotEmpty) expect(find.text(ex.en), findsNothing);
      final word = find.descendant(
          of: sentence(ex.ruby), matching: find.text(ex.kanji.text));
      expect(word, findsOneWidget);
      expect(tester.getRect(reading).bottom,
          lessThanOrEqualTo(tester.getRect(word).top + 0.5));

      await tester.tap(word);
      await tester.pump();

      expect(reading, findsNothing);
      // Hidden again, the sentence reads as one line of text, as before the tap.
      expect(find.text(ex.surface), findsOneWidget);
    });

    testWidgets('a tap on a plain word shows no reading', (tester) async {
      final ex = hintExample();
      await kanjiOn(tester);

      final root = tester
          .widget<Text>(find
              .descendant(of: sentence(ex.ruby), matching: find.byType(Text))
              .first)
          .textSpan! as TextSpan;
      final span = root.children!
          .cast<TextSpan>()
          .firstWhere((s) => s.text == ex.plain.text);
      expect(span.recognizer, isNull);

      await tester.tapOnText(find.textRange
          .ofSubstring(ex.plain.text, descendentOf: sentence(ex.ruby)));
      await tester.pump();

      expect(find.text(ex.surface), findsOneWidget);
      for (final w in rubyWords(ex.ruby)) {
        if (w.reading == null) continue;
        expect(
            find.descendant(
                of: sentence(ex.ruby), matching: find.text(w.reading!)),
            findsNothing);
      }
    });

    testWidgets('a fill-in prompt takes the hint too', (tester) async {
      // The opening lesson's first fill-in prompt with a kanji word, as the kanji
      // view shows it before an answer: its blank is ＿＿＿. The tapped word occurs
      // once in that prompt, so the tap can only land on it.
      final q = firstFills().firstWhere((q) =>
          rubyWords(q['prompt_ruby'] as String? ?? '')
              .any((w) => w.reading != null));
      final ruby = unanswered(q['prompt_ruby'] as String);
      final surface = rubySurface(ruby);
      final kanji = rubyWords(ruby).firstWhere((w) =>
          w.reading != null &&
          surface.indexOf(w.text) == surface.lastIndexOf(w.text));
      final reading = find.descendant(
          of: sentence(ruby), matching: find.text(kanji.reading!));
      await kanjiOn(tester);

      expect(sentence(ruby), findsOneWidget);
      expect(find.text(surface), findsOneWidget);
      expect(wordColors(tester, ruby)[kanji.text],
          const DaylightTokens().brand600);
      expect(reading, findsNothing);

      await tester.tapOnText(
          find.textRange.ofSubstring(kanji.text, descendentOf: sentence(ruby)));
      await tester.pump();

      expect(reading, findsOneWidget);
    });
  });

  testWidgets('Speak this lesson opens the drill for the lesson shown',
      (tester) async {
    final lesson = firstLesson()['lesson'] as int;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const QuietRoomGrammarWidget()),
      GoRoute(
        name: QuietRoomSpeakWidget.routeName,
        path: QuietRoomSpeakWidget.routePath,
        builder: (_, state) =>
            Text('drill for ${state.uri.queryParameters['lesson']}'),
      ),
    ]);
    addTearDown(router.dispose);
    await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Speak this lesson'));
    await tester.pumpAndSettle();

    expect(find.text('drill for $lesson'), findsOneWidget);
  });
}
