// Romaji to hiragana, for the Topics search (#137).
//
// A query typed on an English keyboard ("mimasu") becomes the hiragana reading it spells
// ("みます"), so it finds the same words a hiragana query finds. Hepburn and the common
// Kunrei spellings both convert (shi and si, tsu and tu, fu and hu, ji and zi). A doubled
// consonant becomes a small っ, and an n before a consonant, at the end, or written "nn"
// or "n'" becomes ん. Long vowels convert as written: "ou" is おう.
//
// The result is null when any part of the query is not romaji. An English word that also
// reads as romaji converts too, and the search tries both spellings.

const Map<String, String> _syllables = {
  'a': 'あ',
  'i': 'い',
  'u': 'う',
  'e': 'え',
  'o': 'お',
  'ka': 'か',
  'ki': 'き',
  'ku': 'く',
  'ke': 'け',
  'ko': 'こ',
  'ga': 'が',
  'gi': 'ぎ',
  'gu': 'ぐ',
  'ge': 'げ',
  'go': 'ご',
  'sa': 'さ',
  'shi': 'し',
  'si': 'し',
  'su': 'す',
  'se': 'せ',
  'so': 'そ',
  'za': 'ざ',
  'ji': 'じ',
  'zi': 'じ',
  'zu': 'ず',
  'ze': 'ぜ',
  'zo': 'ぞ',
  'ta': 'た',
  'chi': 'ち',
  'ti': 'ち',
  'tsu': 'つ',
  'tu': 'つ',
  'te': 'て',
  'to': 'と',
  'da': 'だ',
  'di': 'ぢ',
  'du': 'づ',
  'de': 'で',
  'do': 'ど',
  'na': 'な',
  'ni': 'に',
  'nu': 'ぬ',
  'ne': 'ね',
  'no': 'の',
  'ha': 'は',
  'hi': 'ひ',
  'fu': 'ふ',
  'hu': 'ふ',
  'he': 'へ',
  'ho': 'ほ',
  'ba': 'ば',
  'bi': 'び',
  'bu': 'ぶ',
  'be': 'べ',
  'bo': 'ぼ',
  'pa': 'ぱ',
  'pi': 'ぴ',
  'pu': 'ぷ',
  'pe': 'ぺ',
  'po': 'ぽ',
  'ma': 'ま',
  'mi': 'み',
  'mu': 'む',
  'me': 'め',
  'mo': 'も',
  'ya': 'や',
  'yu': 'ゆ',
  'yo': 'よ',
  'ra': 'ら',
  'ri': 'り',
  'ru': 'る',
  're': 'れ',
  'ro': 'ろ',
  'wa': 'わ',
  'wo': 'を',
  'kya': 'きゃ',
  'kyu': 'きゅ',
  'kyo': 'きょ',
  'gya': 'ぎゃ',
  'gyu': 'ぎゅ',
  'gyo': 'ぎょ',
  'sha': 'しゃ',
  'shu': 'しゅ',
  'sho': 'しょ',
  'sya': 'しゃ',
  'syu': 'しゅ',
  'syo': 'しょ',
  'ja': 'じゃ',
  'ju': 'じゅ',
  'jo': 'じょ',
  'zya': 'じゃ',
  'zyu': 'じゅ',
  'zyo': 'じょ',
  'cha': 'ちゃ',
  'chu': 'ちゅ',
  'cho': 'ちょ',
  'tya': 'ちゃ',
  'tyu': 'ちゅ',
  'tyo': 'ちょ',
  'nya': 'にゃ',
  'nyu': 'にゅ',
  'nyo': 'にょ',
  'hya': 'ひゃ',
  'hyu': 'ひゅ',
  'hyo': 'ひょ',
  'bya': 'びゃ',
  'byu': 'びゅ',
  'byo': 'びょ',
  'pya': 'ぴゃ',
  'pyu': 'ぴゅ',
  'pyo': 'ぴょ',
  'mya': 'みゃ',
  'myu': 'みゅ',
  'myo': 'みょ',
  'rya': 'りゃ',
  'ryu': 'りゅ',
  'ryo': 'りょ',
};

const String _vowels = 'aiueo';

/// The hiragana [romaji] spells, or null when it is not romaji throughout.
String? romajiToHiragana(String romaji) {
  final s = romaji.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '');
  if (s.isEmpty || !RegExp(r"^[a-z']+$").hasMatch(s)) return null;
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == "'") {
      i++;
      continue;
    }
    // ん: "nn", "n'", or an n not followed by a vowel or y.
    if (c == 'n') {
      final next = i + 1 < s.length ? s[i + 1] : '';
      if (next == 'n') {
        // "nn" before a vowel is ん plus a な-row syllable (konnichiwa), else just ん.
        final after = i + 2 < s.length ? s[i + 2] : '';
        out.write('ん');
        i += (_vowels.contains(after) && after.isNotEmpty) || after == 'y'
            ? 1
            : 2;
        continue;
      }
      if (next.isEmpty ||
          next == "'" ||
          (!_vowels.contains(next) && next != 'y')) {
        out.write('ん');
        i++;
        continue;
      }
    }
    // Small っ: a doubled consonant other than n ("kk", "tt", "ss"), and "tch".
    if (i + 1 < s.length &&
        !_vowels.contains(c) &&
        (s[i + 1] == c || (c == 't' && s[i + 1] == 'c'))) {
      out.write('っ');
      i++;
      continue;
    }
    String? hit;
    for (final len in const [3, 2, 1]) {
      if (i + len > s.length) continue;
      final k = _syllables[s.substring(i, i + len)];
      if (k != null) {
        hit = k;
        i += len;
        break;
      }
    }
    if (hit == null) return null;
    out.write(hit);
  }
  return out.toString();
}
