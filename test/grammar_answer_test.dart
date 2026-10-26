// Tests for the typed-answer matcher on the grammar screen (PIN-3, End state 3).
//
// A typed answer is right in hiragana, in any accepted form, or in its kanji version.
// A wrong answer in kana is rejected. Anything the matcher cannot compare letter for
// letter (an unknown kanji spelling, romaji) goes to self-check, never to wrong (PIN-2).

import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';

import 'jp_screen_harness.dart';

/// Every fill-in practice item in the shipped lesson file.
List<Map<String, dynamic>> fillItems() {
  final doc = readLessonFile();
  return [
    for (final l in (doc['grammar'] as List).cast<Map<String, dynamic>>())
      for (final p in (l['points'] as List).cast<Map<String, dynamic>>())
        for (final q in (p['practice'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          if ((q['options'] as List? ?? const []).isEmpty) q,
  ];
}

const _item = <String, dynamic>{
  'kind': 'fill',
  'prompt': 'えきへ いきたいんですが、どう ＿＿ いいですか。',
  'prompt_ruby': '駅{えき}へ 行{い}きたいんですが、どう ＿＿ いいですか。',
  'answer': 'いったら',
  'answer_ruby': '行{い}ったら',
  'accepted': ['いけば'],
  'accepted_ruby': ['行{い}けば'],
};

void main() {
  group('checkTypedAnswer', () {
    test('accepts the hiragana answer', () {
      expect(checkTypedAnswer('いったら', _item), TypedVerdict.right);
    });

    test('accepts an accepted form, in hiragana or kanji', () {
      expect(checkTypedAnswer('いけば', _item), TypedVerdict.right);
      expect(checkTypedAnswer('行けば', _item), TypedVerdict.right);
    });

    test('accepts the kanji version of the answer', () {
      expect(checkTypedAnswer('行ったら', _item), TypedVerdict.right);
    });

    test('ignores spaces, punctuation and katakana for hiragana', () {
      expect(checkTypedAnswer(' いったら。', _item), TypedVerdict.right);
      expect(checkTypedAnswer('い　った ら', _item), TypedVerdict.right);
      expect(checkTypedAnswer('イッタラ', _item), TypedVerdict.right);
    });

    test('rejects a wrong answer typed in kana', () {
      expect(checkTypedAnswer('いって', _item), TypedVerdict.wrong);
      expect(checkTypedAnswer('いきます', _item), TypedVerdict.wrong);
    });

    test('sends an answer it cannot compare to self-check, never to wrong', () {
      // Another kanji spelling: it may be right, and there is no dictionary to tell.
      expect(checkTypedAnswer('往ったら', _item), TypedVerdict.selfCheck);
      // Romaji: a keyboard left in English.
      expect(checkTypedAnswer('ittara', _item), TypedVerdict.selfCheck);
    });

    test('an empty box is neither right nor wrong', () {
      expect(checkTypedAnswer('', _item), TypedVerdict.empty);
      expect(checkTypedAnswer(' 。 ', _item), TypedVerdict.empty);
    });

    test('accepts the reading of an answer printed in kanji', () {
      const sign = <String, dynamic>{
        'answer': '立入禁止',
        'answer_ruby': '立入禁止{たちいりきんし}',
        'accepted': <String>[],
        'accepted_ruby': <String>[],
      };
      expect(checkTypedAnswer('立入禁止', sign), TypedVerdict.right);
      expect(checkTypedAnswer('たちいりきんし', sign), TypedVerdict.right);
    });
  });

  group('the shipped fill-in items', () {
    test('there are fill-in items to check', () {
      expect(fillItems(), isNotEmpty);
    });

    test('every answer, accepted form and kanji version is accepted', () {
      for (final q in fillItems()) {
        final forms = <String>[
          q['answer'] as String,
          ...(q['accepted'] as List? ?? const []).cast<String>(),
          rubySurface(q['answer_ruby'] as String? ?? q['answer'] as String),
          for (final r
              in (q['accepted_ruby'] as List? ?? const []).cast<String>())
            rubySurface(r),
        ];
        for (final f in forms) {
          expect(checkTypedAnswer(f, q), TypedVerdict.right,
              reason: '"$f" for ${q['prompt']}');
        }
      }
    });

    test('a different item\'s kana answer is rejected', () {
      final items = fillItems();
      var checked = 0;
      for (var i = 0; i < items.length; i++) {
        final q = items[i];
        final other = items[(i + 1) % items.length]['answer'] as String;
        if (answerForms(q).contains(other)) continue;
        if (!isPlainKana(other)) continue;
        expect(checkTypedAnswer(other, q), TypedVerdict.wrong,
            reason: '"$other" for ${q['prompt']}');
        checked++;
      }
      expect(checked, greaterThan(0));
    });
  });
}
