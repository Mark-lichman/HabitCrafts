// Tests for the grades (D17, D22) and the mastery rule (D4, D16, PIN-3, PIN-4, PIN-13, PIN-14,
// PIN-15). Every case is an attempt list replayed through `masteryAfter`, so each clause of the
// rule is pinned by history alone (PIN-1), in the style of streak_test.dart.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';

class _Item implements ItemDefLike {
  const _Item(this.id, this.kind,
      {this.templateCount = 1,
      this.hasProductionProbe = false,
      this.probeCount = 1});
  @override
  final String id;
  @override
  final ItemKind kind;
  @override
  final int templateCount;
  @override
  final bool hasProductionProbe;
  @override
  final int probeCount;
}

// One template, one probe: each particle's one cloze (PIN-15).
const particle = _Item('mari.particle.14', ItemKind.particle);
// Card recall, spoken recall, reading typed: three templates, two of them production.
const word = _Item('L30_02', ItemKind.word,
    templateCount: 3, hasProductionProbe: true, probeCount: 3);
// Choose and typed fill over four practice items and two examples.
const grammar = _Item('mari.L31.3', ItemKind.grammar,
    templateCount: 2, hasProductionProbe: true, probeCount: 6);
// One reveal template over the verbs of the group.
const conj = _Item('conj.te.g2', ItemKind.conjugation, probeCount: 8);
// Both directions are the two templates; no production probe yet (A8).
const pair =
    _Item('s02_pairs_mari.1.1', ItemKind.pair, templateCount: 2, probeCount: 2);
const row = _Item('ref.counters.hon', ItemKind.tableRow, probeCount: 5);
const oneCellRow = _Item('ref.counters.one', ItemKind.tableRow);

var _seq = 0;

Attempt att(
  int day,
  Grade grade, {
  ItemDefLike item = particle,
  String probe = 'p1',
  String template = 't1',
  bool production = false,
  bool due = true,
  Source source = Source.review,
  int hint = 0,
  bool revealed = false,
  bool spokenClose = false,
}) {
  _seq++;
  return Attempt(
    itemId: item.id,
    probeId: probe,
    template: template,
    production: production,
    selfGraded: false,
    atUtc: DateTime.utc(2026, 1, 1, 12).add(Duration(days: day)),
    localDay: day,
    grade: grade,
    rating: fsrsRatingFor(grade),
    hintLevel: hint,
    revealed: revealed,
    wasDue: due,
    source: source,
    durationMs: 8000,
    sessionId: 's$_seq',
    spokenClose: spokenClose,
  );
}

MasteryState replay(List<Attempt> attempts, [ItemDefLike item = particle]) =>
    masteryFromAttempts(item, attempts);

/// Four due clears on days 0, 2, 8 and [last], all on one template.
List<Attempt> fourClears(int last, {ItemDefLike item = particle}) => [
      for (final d in [0, 2, 8, last]) att(d, Grade.clear, item: item),
    ];

void main() {
  group('grades (D17, D22)', () {
    test('machine-checked: right with no hint is clear', () {
      expect(
          gradeAnswer(outcome: Outcome.right, selfGraded: false), Grade.clear);
    });

    test('machine-checked: any hint below the revealing level is hinted', () {
      expect(
          gradeAnswer(
              outcome: Outcome.right,
              selfGraded: false,
              hintLevel: 1,
              revealingHintLevel: 3),
          Grade.hinted);
      expect(
          gradeAnswer(
              outcome: Outcome.right,
              selfGraded: false,
              hintLevel: 2,
              revealingHintLevel: 3),
          Grade.hinted);
    });

    test('a hint level at or above the revealing one is wrong', () {
      for (final level in [3, 4]) {
        expect(
            gradeAnswer(
                outcome: Outcome.right,
                selfGraded: false,
                hintLevel: level,
                revealingHintLevel: 3),
            Grade.wrong);
        expect(
            gradeAnswer(
                outcome: Outcome.right,
                selfGraded: true,
                hintLevel: level,
                revealingHintLevel: 3),
            Grade.wrong);
      }
      expect(
          gradeAnswer(
              outcome: Outcome.none,
              selfGraded: false,
              hintLevel: 3,
              revealingHintLevel: 3),
          Grade.wrong);
    });

    test('a reveal on a machine-checked probe is wrong, even before trying',
        () {
      expect(
          gradeAnswer(
              outcome: Outcome.right, selfGraded: false, revealed: true),
          Grade.wrong);
      expect(
          gradeAnswer(outcome: Outcome.none, selfGraded: false, revealed: true),
          Grade.wrong);
    });

    test('speech close and a second try are hinted', () {
      expect(
          gradeAnswer(outcome: Outcome.close, selfGraded: false), Grade.hinted);
      expect(
          gradeAnswer(
              outcome: Outcome.right, selfGraded: false, secondTry: true),
          Grade.hinted);
    });

    test('wrong is wrong, nothing heard is unscored, a self override is self',
        () {
      expect(
          gradeAnswer(outcome: Outcome.wrong, selfGraded: false), Grade.wrong);
      expect(gradeAnswer(outcome: Outcome.none, selfGraded: false),
          Grade.unscored);
      expect(
          gradeAnswer(
              outcome: Outcome.none, selfGraded: false, selfOverride: true),
          Grade.self);
    });

    test('a self override never replaces a verified verdict', () {
      expect(
          gradeAnswer(
              outcome: Outcome.wrong, selfGraded: false, selfOverride: true),
          Grade.wrong);
      expect(
          gradeAnswer(
              outcome: Outcome.close, selfGraded: false, selfOverride: true),
          Grade.hinted);
      expect(
          gradeAnswer(
              outcome: Outcome.right, selfGraded: false, selfOverride: true),
          Grade.clear);
    });

    test('an Attempt refuses a clear that carries a hint level (PIN-3)', () {
      expect(() => att(0, Grade.clear, hint: 1), throwsAssertionError);
      expect(att(0, Grade.hinted, hint: 1).grade, Grade.hinted);
    });

    test('self-graded: Got it after the reveal is clear, Missed it is wrong',
        () {
      expect(
          gradeAnswer(outcome: Outcome.right, selfGraded: true, revealed: true),
          Grade.clear);
      expect(
          gradeAnswer(outcome: Outcome.wrong, selfGraded: true, revealed: true),
          Grade.wrong);
    });

    test('self-graded: a hint taken before the reveal makes Got it hinted', () {
      expect(
          gradeAnswer(
              outcome: Outcome.right,
              selfGraded: true,
              revealed: true,
              hintLevel: 1,
              revealingHintLevel: 3),
          Grade.hinted);
    });

    test('the FSRS rating of each grade (D12)', () {
      expect(fsrsRatingFor(Grade.clear), kRatingGood);
      expect(fsrsRatingFor(Grade.hinted), kRatingHard);
      expect(fsrsRatingFor(Grade.self), kRatingHard);
      expect(fsrsRatingFor(Grade.wrong), kRatingAgain);
      expect(fsrsRatingFor(Grade.unscored), isNull);
    });

    test('only clear earns mastery credit; hinted never does (PIN-3)', () {
      expect(earnsMasteryCredit(Grade.clear), isTrue);
      for (final g in [Grade.hinted, Grade.self, Grade.wrong, Grade.unscored]) {
        expect(earnsMasteryCredit(g), isFalse, reason: '$g');
      }
    });

    test('earnsMasteryCredit and masteryAfter agree on every grade (PIN-3)',
        () {
      for (final g in Grade.values) {
        final s = replay([att(0, g)]);
        expect(s.clearCount, earnsMasteryCredit(g) ? 1 : 0, reason: '$g');
      }
    });
  });

  group('the four spaced clears (D4 clause 1 and 2)', () {
    test('no attempts is New', () {
      final s = replay(const []);
      expect(s.status, MasteryStatus.neu);
      expect(s.clearCount, 0);
    });

    test('four due clears on four days, the fourth 21 days on, is Mastered',
        () {
      final s = replay(fourClears(29));
      expect(s.status, MasteryStatus.mastered);
      expect(s.masteredOn, 29);
      expect(s.clearCount, 4);
    });

    test('a 20-day final gap is not Mastered, and the count shows 4 of 4', () {
      final s = replay(fourClears(28));
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 4);
    });

    test('a later clear 21 days on masters it after a short fourth gap', () {
      final s = replay([...fourClears(28), att(49, Grade.clear)]);
      expect(s.status, MasteryStatus.mastered);
      expect(s.masteredOn, 49);
    });

    test('the gap runs from the previous scored review, hinted included', () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.clear),
        att(8, Grade.clear),
        att(20, Grade.hinted),
        att(29, Grade.clear),
      ]);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 4);
    });

    test('an unscored attempt is not a scored review for the gap', () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.clear),
        att(8, Grade.clear),
        att(20, Grade.unscored),
        att(29, Grade.clear),
      ]);
      expect(s.status, MasteryStatus.mastered);
      expect(s.lastScoredDay, 29);
    });

    test('a clear while not due does not count', () {
      final s = replay([
        att(0, Grade.clear),
        att(1, Grade.clear, due: false),
        att(2, Grade.clear),
      ]);
      expect(s.clearCount, 2);
    });

    test('one clear per item per day', () {
      final s = replay([
        att(0, Grade.clear),
        att(0, Grade.clear, probe: 'p2'),
        att(2, Grade.clear),
        att(2, Grade.clear),
      ]);
      expect(s.clearCount, 2);
    });

    test('one clear per day even when the local day steps back', () {
      // A timezone change can make the local day run 10, 9, 10.
      final s = replay([
        att(10, Grade.clear),
        att(9, Grade.clear),
        att(10, Grade.clear),
      ]);
      expect(s.clearCount, 2);
    });

    test('a keep-sharp review counts like a review', () {
      final s = replay([
        for (final d in [0, 2, 8, 29])
          att(d, Grade.clear, source: Source.keepSharp),
      ]);
      expect(s.status, MasteryStatus.mastered);
    });
  });

  group('wrong and hinted (D4 clause 3, D3)', () {
    test('a wrong resets the count to zero', () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.clear),
        att(5, Grade.wrong),
      ]);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 0);
    });

    test('no wrong since the first: the clears before a wrong never come back',
        () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.clear),
        att(8, Grade.clear),
        att(9, Grade.wrong),
        att(30, Grade.clear),
      ]);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 1);
    });

    test('one hinted earns no credit and does not reset', () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.clear),
        att(5, Grade.hinted, hint: 1),
        att(8, Grade.clear),
      ]);
      expect(s.clearCount, 3);
      expect(s.hintStreak, 0);
    });

    test('two hinted in a row reset the count', () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.clear),
        att(5, Grade.hinted, hint: 1),
        att(6, Grade.hinted, hint: 2),
      ]);
      expect(s.clearCount, 0);
      expect(s.status, MasteryStatus.learning);
    });

    test('a clear between two hinted breaks the row', () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.hinted),
        att(3, Grade.clear),
        att(5, Grade.hinted),
      ]);
      expect(s.clearCount, 2);
      expect(s.hintStreak, 1);
    });

    test('self earns no credit and is neutral for the hinted row (ASK-3)', () {
      final learning = replay([
        att(0, Grade.clear),
        att(2, Grade.self),
        att(3, Grade.self),
      ]);
      expect(learning.clearCount, 1, reason: 'no credit, and no reset');
      expect(learning.hintStreak, 0);
      expect(learning.lastScoredDay, 3, reason: 'the review is recorded');

      final mastered = replay([
        ...fourClears(29),
        att(40, Grade.self),
        att(42, Grade.self),
      ]);
      expect(mastered.status, MasteryStatus.mastered);
      expect(mastered.hintStreak, 0);
      expect(mastered.keptReviews, 2);
      expect(mastered.keptClear, 0);

      final afterSelf = replay([
        ...fourClears(29),
        att(40, Grade.self),
        att(42, Grade.hinted),
      ]);
      expect(afterSelf.status, MasteryStatus.mastered);
      expect(afterSelf.hintStreak, 1,
          reason: 'a hinted after a self starts at 1');
    });

    test(
        'a spoken close earns no credit and is neutral for the hinted row '
        '(PIN-10, plan 2026-11-06 Task 5)', () {
      Attempt close(int day, {ItemDefLike item = word}) => att(day, Grade.hinted,
          item: item, template: 'spoken', production: true, spokenClose: true);
      final learning = replay([
        att(0, Grade.clear, item: word),
        close(2),
        close(3),
      ], word);
      expect(learning.clearCount, 1, reason: 'no credit, and no reset');
      expect(learning.hintStreak, 0);
      expect(learning.lastScoredDay, 3, reason: 'the review is recorded');

      // A one-template item, so four clears master it before the closes.
      final mastered = replay([
        ...fourClears(29),
        close(40, item: particle),
        close(42, item: particle),
      ]);
      expect(mastered.status, MasteryStatus.mastered,
          reason: 'two closes in a row never make it Shaky');
      expect(mastered.hintStreak, 0);

      // An ordinary hinted answer still counts toward the reset around a close.
      final mixed = replay([
        att(0, Grade.clear, item: word),
        att(2, Grade.hinted, item: word, hint: 1),
        close(3),
        att(4, Grade.hinted, item: word, hint: 1),
      ], word);
      expect(mixed.clearCount, 0, reason: 'two hinted around a close reset it');
    });

    test('a first self answer moves New to Learning at 0 of 4', () {
      final s = replay([att(0, Grade.self)]);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 0);
      expect(s.hintStreak, 0);
    });

    test('hinted answers alone never master an item (PIN-3)', () {
      final s = replay([
        for (var d = 0; d < 200; d += 25) att(d, Grade.hinted, hint: 1),
      ]);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 0);
    });

    test('a first hinted answer moves New to Learning at 0 of 4', () {
      final s = replay([att(0, Grade.hinted)]);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 0);
    });
  });

  group('unscored, early practice and Say-it', () {
    test('unscored changes nothing', () {
      final before = replay([att(0, Grade.clear), att(2, Grade.hinted)]);
      final after = masteryAfter(before, att(3, Grade.unscored), particle);
      expect(after, before);
      expect(replay([att(0, Grade.unscored)]).status, MasteryStatus.neu);
    });

    test('an early-practice clear changes nothing (PIN-14)', () {
      final before = replay([att(0, Grade.clear), att(2, Grade.hinted)]);
      final after = masteryAfter(before,
          att(3, Grade.clear, due: false, source: Source.early), particle);
      expect(after, before);
      expect(replay([att(0, Grade.clear, source: Source.early)]).status,
          MasteryStatus.neu);
    });

    test('early clears never count, even when the item happens to be due', () {
      final s = replay([
        for (final d in [0, 2, 8, 29])
          att(d, Grade.clear, source: Source.early),
      ]);
      expect(s.status, MasteryStatus.neu);
      expect(s.clearCount, 0);
    });

    test('an early hinted or self answer changes nothing (PIN-14, ASK-2)', () {
      final states = {
        'New': MasteryState.initial(particle.id),
        'Learning': replay([att(0, Grade.clear), att(2, Grade.hinted)]),
        'Mastered': replay(fourClears(29)),
      };
      expect(states['Mastered']!.status, MasteryStatus.mastered);
      for (final MapEntry(key: name, value: before) in states.entries) {
        for (final grade in [Grade.hinted, Grade.self]) {
          final after = masteryAfter(
              before,
              att(40, grade,
                  due: false,
                  source: Source.early,
                  hint: grade == Grade.hinted ? 1 : 0),
              particle);
          expect(after, before, reason: 'an early $grade on a $name item');
        }
      }
    });

    test('an early-practice wrong counts as a real wrong (PIN-14)', () {
      final s = replay([
        att(0, Grade.clear),
        att(2, Grade.clear),
        att(3, Grade.wrong, due: false, source: Source.early),
      ]);
      expect(s.clearCount, 0);
      expect(s.lastScoredDay, 3);
      final mastered = replay([
        ...fourClears(29),
        att(31, Grade.wrong, due: false, source: Source.early),
      ]);
      expect(mastered.status, MasteryStatus.shaky);
    });

    test('Say-it never counts, clear or wrong', () {
      final s = replay([
        for (final d in [0, 2, 8, 29])
          att(d, Grade.clear, source: Source.sayIt),
        att(30, Grade.wrong, source: Source.sayIt),
      ]);
      expect(s, MasteryState.initial(particle.id));
    });
  });

  group('templates and production (D4 clause 4, PIN-15)', () {
    test('a one-template item needs only the spaced clears', () {
      expect(replay(fourClears(29)).status, MasteryStatus.mastered);
    });

    test('a multi-template item on one template is not Mastered', () {
      final s = replay([
        for (final d in [0, 2, 8, 29])
          att(d, Grade.clear, item: word, template: 'card', probe: 'card'),
      ], word);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 4);
    });

    test(
        'two templates without production is not Mastered where production exists',
        () {
      final s = replay([
        att(0, Grade.clear, item: word, template: 'card', probe: 'card'),
        att(2, Grade.clear, item: word, template: 'card', probe: 'card'),
        att(8, Grade.clear, item: word, template: 'meaning', probe: 'meaning'),
        att(29, Grade.clear, item: word, template: 'card', probe: 'card'),
      ], word);
      expect(s.status, MasteryStatus.learning);
    });

    test('two templates with one production clear is Mastered', () {
      final s = replay([
        att(0, Grade.clear, item: word, template: 'card', probe: 'card'),
        att(2, Grade.clear, item: word, template: 'card', probe: 'card'),
        att(8, Grade.clear,
            item: word, template: 'spoken', probe: 'spoken', production: true),
        att(29, Grade.clear, item: word, template: 'card', probe: 'card'),
      ], word);
      expect(s.status, MasteryStatus.mastered);
    });

    test('where no production probe exists, two templates suffice (a pair)',
        () {
      final s = replay([
        att(0, Grade.clear, item: pair, template: 'jp-en', probe: 'jp-en'),
        att(2, Grade.clear, item: pair, template: 'en-jp', probe: 'en-jp'),
        att(8, Grade.clear, item: pair, template: 'jp-en', probe: 'jp-en'),
        att(29, Grade.clear, item: pair, template: 'jp-en', probe: 'jp-en'),
      ], pair);
      expect(s.status, MasteryStatus.mastered);
    });

    test('a pair asked in one direction only is not Mastered', () {
      final s = replay([
        for (final d in [0, 2, 8, 29])
          att(d, Grade.clear, item: pair, template: 'jp-en', probe: 'jp-en'),
      ], pair);
      expect(s.status, MasteryStatus.learning);
    });

    test('exactly two templates on one template only is not Mastered', () {
      // Three sentences meet the transfer clause, so only the template clause
      // blocks: the gate is >= kTemplatesNeeded, not >.
      final s = replay([
        for (final (d, sentence) in [
          (0, 's1'),
          (2, 's2'),
          (8, 's3'),
          (29, 's2')
        ])
          att(d, Grade.clear,
              item: grammar,
              template: 'typed',
              probe: sentence,
              production: true),
      ], grammar);
      expect(s.status, MasteryStatus.learning);
      expect(s.clearCount, 4);
    });
  });

  group('transfer per kind (D4 clause 5)', () {
    Attempt g(int d, String sentence, {String template = 'typed'}) =>
        att(d, Grade.clear,
            item: grammar,
            probe: sentence,
            template: template,
            production: template == 'typed');

    test('a grammar point needs three different sentences', () {
      final two = replay([
        g(0, 's1', template: 'choose'),
        g(2, 's2'),
        g(8, 's1'),
        g(29, 's2'),
      ], grammar);
      expect(two.status, MasteryStatus.learning);
      final three = replay([
        g(0, 's1', template: 'choose'),
        g(2, 's2'),
        g(8, 's3'),
        g(29, 's2'),
      ], grammar);
      expect(three.status, MasteryStatus.mastered);
    });

    test('a conjugation idea needs three different verbs', () {
      Attempt c(int d, String verb) =>
          att(d, Grade.clear, item: conj, probe: verb, template: 'reveal');
      expect(
          replay([c(0, 'taberu'), c(2, 'miru'), c(8, 'taberu'), c(29, 'miru')],
                  conj)
              .status,
          MasteryStatus.learning);
      expect(
          replay([c(0, 'taberu'), c(2, 'miru'), c(8, 'neru'), c(29, 'miru')],
                  conj)
              .status,
          MasteryStatus.mastered);
    });

    test('a table row needs two different cells', () {
      Attempt r(int d, String cell, ItemDefLike item) =>
          att(d, Grade.clear, item: item, probe: cell, template: 'cell');
      expect(
          replay([
            r(0, 'c1', row),
            r(2, 'c1', row),
            r(8, 'c1', row),
            r(29, 'c1', row)
          ], row)
              .status,
          MasteryStatus.learning);
      expect(
          replay([
            r(0, 'c1', row),
            r(2, 'c3', row),
            r(8, 'c1', row),
            r(29, 'c1', row)
          ], row)
              .status,
          MasteryStatus.mastered);
    });

    test('a row with fewer than two cells needs every cell, that is the one',
        () {
      Attempt r(int d) =>
          att(d, Grade.clear, item: oneCellRow, probe: 'c1', template: 'cell');
      expect(replay([r(0), r(2), r(8), r(29)], oneCellRow).status,
          MasteryStatus.mastered);
    });

    test('a particle and a word carry no sentence transfer clause', () {
      expect(replay(fourClears(29)).status, MasteryStatus.mastered);
      final w = replay([
        att(0, Grade.clear, item: word, template: 'card', probe: 'w1'),
        att(2, Grade.clear, item: word, template: 'card', probe: 'w1'),
        att(8, Grade.clear,
            item: word, template: 'spoken', probe: 'w1', production: true),
        att(29, Grade.clear, item: word, template: 'card', probe: 'w1'),
      ], word);
      expect(w.status, MasteryStatus.mastered);
    });

    test('a one-template pair still needs both directions', () {
      const onePair = _Item('s02_pairs_one', ItemKind.pair, probeCount: 2);
      Attempt p(int d, String dir) =>
          att(d, Grade.clear, item: onePair, probe: dir, template: 'reveal');
      expect(
          replay([p(0, 'jp-en'), p(2, 'jp-en'), p(8, 'jp-en'), p(29, 'jp-en')],
                  onePair)
              .status,
          MasteryStatus.learning);
      expect(
          replay([p(0, 'jp-en'), p(2, 'en-jp'), p(8, 'jp-en'), p(29, 'jp-en')],
                  onePair)
              .status,
          MasteryStatus.mastered);
    });
  });

  group('Shaky and its regain (D16, PIN-4)', () {
    final mastered = fourClears(29);

    test('a wrong on a Mastered item makes it Shaky', () {
      final s = replay([...mastered, att(60, Grade.wrong)]);
      expect(s.status, MasteryStatus.shaky);
      expect(s.shakyOn, 60);
      expect(s.masteredOn, 29);
      expect(s.clearCount, 0);
      expect(s.keptReviews, 1);
      expect(s.keptClear, 0);
    });

    test('one hinted on a Mastered item keeps the badge, two make it Shaky',
        () {
      expect(replay([...mastered, att(60, Grade.hinted)]).status,
          MasteryStatus.mastered);
      final s =
          replay([...mastered, att(60, Grade.hinted), att(62, Grade.hinted)]);
      expect(s.status, MasteryStatus.shaky);
      expect(s.keptReviews, 2);
      expect(s.keptClear, 0);
    });

    test('two clears on two days, the second 7 days on, regain it', () {
      final s = replay([
        ...mastered,
        att(60, Grade.wrong),
        att(61, Grade.clear),
        att(68, Grade.clear)
      ]);
      expect(s.status, MasteryStatus.mastered);
      expect(s.masteredOn, 68);
      expect(s.shakyOn, isNull);
    });

    test('a 6-day gap does not regain it', () {
      final s = replay([
        ...mastered,
        att(60, Grade.wrong),
        att(61, Grade.clear),
        att(67, Grade.clear)
      ]);
      expect(s.status, MasteryStatus.shaky);
    });

    test('a wrong during the regain starts it over', () {
      final s = replay([
        ...mastered,
        att(60, Grade.wrong),
        att(61, Grade.clear),
        att(65, Grade.wrong),
        att(68, Grade.clear),
      ]);
      expect(s.status, MasteryStatus.shaky);
      expect(s.clearCount, 1);
    });

    test('an early clear does not help the regain', () {
      final s = replay([
        ...mastered,
        att(60, Grade.wrong),
        att(61, Grade.clear, source: Source.early, due: false),
        att(68, Grade.clear),
      ]);
      expect(s.status, MasteryStatus.shaky);
    });

    test('a Mastered item counts its kept reviews for the kept rate', () {
      final s = replay([
        ...mastered,
        att(60, Grade.clear, source: Source.keepSharp),
        att(90, Grade.hinted),
        att(120, Grade.clear),
      ]);
      expect(s.status, MasteryStatus.mastered);
      expect(s.keptReviews, 3);
      expect(s.keptClear, 2);
    });

    test('a clear between two hinted keeps a Mastered item and its streak', () {
      final s = replay([
        ...mastered,
        att(60, Grade.hinted),
        att(62, Grade.clear),
        att(64, Grade.hinted),
      ]);
      expect(s.status, MasteryStatus.mastered);
      expect(s.hintStreak, 1);
    });

    test('an early wrong on a Mastered item is not a kept review', () {
      final before = replay([
        ...mastered,
        att(60, Grade.clear, source: Source.keepSharp),
      ]);
      final after = masteryAfter(before,
          att(70, Grade.wrong, due: false, source: Source.early), particle);
      expect(after.status, MasteryStatus.shaky);
      expect(after.keptReviews, before.keptReviews);
      expect(after.keptClear, before.keptClear);
    });
  });

  group('purity (PIN-1)', () {
    test('the state is the fold of the item\'s own attempts', () {
      final history = [
        ...fourClears(29),
        att(60, Grade.wrong),
        att(61, Grade.clear),
        att(68, Grade.clear),
      ];
      // The stored state is enough to continue the fold (D14): replay a prefix,
      // round-trip it through JSON, then fold the rest onto it.
      final whole = replay(history);
      for (var k = 0; k <= history.length; k++) {
        final prefix = replay(history.sublist(0, k));
        var s = MasteryState.fromJson(prefix.toJson());
        for (final a in history.sublist(k)) {
          s = masteryAfter(s, a, particle);
        }
        expect(s, whole, reason: 'split at $k');
      }
    });

    // masteryAfter refuses a mismatch on either side: the attempt's item or the def's item.
    // Each arm has its own case so deleting one arm turns one case red.
    final refused = throwsA(isA<ArgumentError>()
        .having((e) => e.message, 'message', contains('applied to')));

    test('an attempt for another item is refused', () {
      expect(
          () => masteryAfter(MasteryState.initial(particle.id),
              att(0, Grade.clear, item: word), particle),
          refused);
    });

    test('a def for another item is refused', () {
      expect(
          () => masteryAfter(
              MasteryState.initial(particle.id), att(0, Grade.clear), word),
          refused);
    });

    test('a replay refuses an attempt for another item', () {
      expect(() => replay([att(0, Grade.clear, item: word)]), refused);
    });

    test('Attempt and MasteryState survive a JSON round trip', () {
      // production true with selfGraded false (the helper's fixed value), so a swap of those
      // two keys reads differently here even where `mirror` has both true.
      final a = att(3, Grade.hinted, hint: 2, revealed: true, production: true);
      expect(Attempt.fromJson(a.toJson()), a);
      final full = Attempt(
        id: 7,
        itemId: particle.id,
        probeId: 'p1',
        template: 't1',
        production: false,
        selfGraded: false,
        atUtc: DateTime.utc(2026, 1, 4, 12),
        localDay: 3,
        grade: Grade.clear,
        rating: kRatingGood,
        wasDue: true,
        source: Source.review,
        elapsedDays: 2.5,
        rBefore: 0.9,
        rAfter: 0.95,
        sBefore: 10.0,
        sAfter: 12.5,
        durationMs: 8000,
        sessionId: 's-full',
      );
      final decoded = Attempt.fromJson(full.toJson());
      expect(decoded, full);
      expect(decoded.id, 7);
      expect(decoded.elapsedDays, 2.5);
      expect(decoded.rBefore, 0.9);
      expect(decoded.rAfter, 0.95);
      expect(decoded.sBefore, 10.0);
      expect(decoded.sAfter, 12.5);
      expect(decoded.sBefore, isNot(decoded.sAfter));
      expect(decoded.rBefore, isNot(decoded.rAfter));
      // The mirror of `full`: every enum, nullable and small int takes its other value, and
      // across `a`, `full` and `mirror` every pair of bool fields differs on at least one, so
      // a swapped or hard-coded key reads differently somewhere. Encoded to text and back, so
      // the map is JSON-encodable as well (D14).
      final mirror = Attempt(
        id: null,
        itemId: word.id,
        probeId: 'p2',
        template: 't2',
        production: true,
        selfGraded: true,
        atUtc: DateTime.utc(2026, 2, 5, 6),
        localDay: 35,
        grade: Grade.self,
        rating: kRatingHard,
        hintLevel: 1,
        revealed: false,
        wasDue: false,
        source: Source.keepSharp,
        elapsedDays: null,
        rBefore: null,
        rAfter: null,
        sBefore: null,
        sAfter: null,
        durationMs: 0,
        sessionId: 's-mirror',
      );
      final mirrorDecoded = Attempt.fromJson(
          jsonDecode(jsonEncode(mirror.toJson())) as Map<String, dynamic>);
      expect(mirrorDecoded, mirror);
      expect(mirrorDecoded.id, isNull);
      expect(mirrorDecoded.production, isTrue);
      expect(mirrorDecoded.selfGraded, isTrue);
      expect(mirrorDecoded.grade, Grade.self);
      expect(mirrorDecoded.rating, kRatingHard);
      expect(mirrorDecoded.wasDue, isFalse);
      expect(mirrorDecoded.source, Source.keepSharp);
      expect(mirrorDecoded.elapsedDays, isNull);
      // An unscored row logs no FSRS rating (fsrsRatingFor returns null), and Task 8 replays
      // such rows from the log (D14). `a`, `full` and `mirror` all carry a rating, so a
      // defaulted or non-nullable rating reads differently here and nowhere else.
      final u = att(4, Grade.unscored);
      final uDecoded = Attempt.fromJson(
          jsonDecode(jsonEncode(u.toJson())) as Map<String, dynamic>);
      expect(uDecoded, u);
      expect(uDecoded.rating, isNull);
      expect(uDecoded.grade, Grade.unscored);
      // The spoken close mark (PIN-10) round-trips, and an attempt without it writes no key,
      // so a record from before the mark exports byte for byte as it was (End state 8).
      final c = att(5, Grade.hinted, spokenClose: true);
      final cDecoded = Attempt.fromJson(
          jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(cDecoded, c);
      expect(cDecoded.spokenClose, isTrue);
      expect(c.toJson()['spokenClose'], isTrue);
      expect(a.toJson().containsKey('spokenClose'), isFalse);
      expect(Attempt.fromJson(a.toJson()).spokenClose, isFalse,
          reason: 'an old row reads as no close');
      expect(
          Attempt.fromJson({...u.toJson(), 'spokenClose': true}).spokenClose,
          isFalse,
          reason: 'only a hinted row can carry the mark');
      final s = replay(
          [...fourClears(29), att(60, Grade.wrong), att(61, Grade.clear)]);
      expect(MasteryState.fromJson(s.toJson()), s);
      // A production clear next to a non-production one on another template, so the ClearRef
      // keys for production, template and probeId each read a different value per entry.
      final learning = MasteryState(
        itemId: word.id,
        status: MasteryStatus.learning,
        clears: const [
          ClearRef(day: 5, template: 't2', production: true, probeId: 'p2'),
          ClearRef(day: 9, template: 't1', production: false, probeId: 'p1'),
        ],
        hintStreak: 1,
        lastScoredDay: 9,
      );
      final learningDecoded = MasteryState.fromJson(
          jsonDecode(jsonEncode(learning.toJson())) as Map<String, dynamic>);
      expect(learningDecoded, learning);
      expect(learningDecoded.clears.first.production, isTrue);
      expect(learningDecoded.clears.last.production, isFalse);
      expect(learningDecoded.masteredOn, isNull);
      expect(learningDecoded.shakyOn, isNull);
      // The kept-rate state: keptClear is nonzero only after a Mastered item is reviewed, so
      // the shaky, learning and prefix states above all carry keptClear 0. This one carries
      // the numerator and denominator the kept rate reads (End state 17), both nonzero and
      // different, so a dropped or hard-coded keptClear key reads differently here.
      final k = replay([
        ...fourClears(29),
        att(60, Grade.clear, source: Source.keepSharp),
        att(90, Grade.hinted),
        att(120, Grade.clear),
      ]);
      final kDecoded = MasteryState.fromJson(
          jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
      expect(kDecoded, k);
      expect(kDecoded.status, MasteryStatus.mastered);
      expect(kDecoded.keptReviews, 3);
      expect(kDecoded.keptClear, 2);
      expect(kDecoded.masteredOn, 29);
    });
  });
}
