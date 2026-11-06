// Romaji to hiragana for the Topics search (#137).

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/romaji.dart';

void main() {
  test('Hepburn spellings convert', () {
    expect(romajiToHiragana('mimasu'), 'みます');
    expect(romajiToHiragana('sagashimasu'), 'さがします');
    expect(romajiToHiragana('tsukue'), 'つくえ');
    expect(romajiToHiragana('chotto'), 'ちょっと');
    expect(romajiToHiragana('kyou'), 'きょう');
    expect(romajiToHiragana('jisho'), 'じしょ');
    expect(romajiToHiragana('fuyu'), 'ふゆ');
  });

  test('Kunrei spellings convert', () {
    expect(romajiToHiragana('tukue'), 'つくえ');
    expect(romajiToHiragana('sinbun'), 'しんぶん');
    expect(romajiToHiragana('zisyo'), 'じしょ');
  });

  test('n becomes ん before a consonant, at the end, and as nn or n\'', () {
    expect(romajiToHiragana('shinbun'), 'しんぶん');
    expect(romajiToHiragana('hon'), 'ほん');
    expect(romajiToHiragana('konnichiwa'), 'こんにちわ');
    expect(romajiToHiragana("kin'en"), 'きんえん');
    expect(romajiToHiragana('kinen'), 'きねん');
  });

  test('a doubled consonant becomes a small っ', () {
    expect(romajiToHiragana('kitte'), 'きって');
    expect(romajiToHiragana('matcha'), 'まっちゃ');
    expect(romajiToHiragana('gakkou'), 'がっこう');
  });

  test('case, spaces and dashes do not matter', () {
    expect(romajiToHiragana('Mi Masu'), 'みます');
    expect(romajiToHiragana('mi-masu'), 'みます');
  });

  test('anything that is not romaji throughout is null', () {
    expect(romajiToHiragana(''), isNull);
    expect(romajiToHiragana('みます'), isNull);
    expect(romajiToHiragana('xyz'), isNull);
    expect(romajiToHiragana('clock'), isNull);
    expect(romajiToHiragana('L26'), isNull);
  });
}
