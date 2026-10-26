// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The per-lesson speaking drill (PIN-6). It walks one grammar lesson's sentences: every
// example, then every practice item with its answer in the blank. For each one the
// learner plays the sentence, speaks it once, and the drill judges what was heard.
//
// Judging reuses `SpeechService.judge()`. The expected kana is the kanji twin's reading
// (every `漢字{かな}` bracket replaced by its reading), so an example the lesson prints in
// kanji still has a hiragana target. The sentence's kanji surface goes in `kanjiForms`,
// because Android recognisers often return a sentence in kanji. An example that joins
// several forms with ／ becomes one sentence per form.
//
// 🚨 NO CORRECT ANSWER IS EVER MARKED WRONG (PIN-2, PIN-7, PIN-10).
//   * `correct` is marked right.
//   * `close` shows a Close result in amber, the heard text with its matching part
//     highlighted, then asks the learner: "Got it" or "Missed it".
//   * `unverified` shows what was heard and asks the same question.
//   * `wrong` is only a wrong mark when the transcript is plain kana, which judge() can
//     compare letter for letter. A transcript with kanji, digits or Latin letters cannot
//     be compared, so it goes to the same self-check instead.
//
// Like the vocabulary drill, this checks WHICH sentence was produced, never how well it was
// pronounced. See speech_service.dart.

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';

import '/components/pages/quiet_room_practice/listening_bars.dart';
import '/components/pages/quiet_room_practice/speech_service.dart';
import '/flutter_flow/quiet_room.dart';
import 'jp_study_kit.dart';

/// Listens once and judges against the expected hiragana and its kanji forms.
typedef SpeakListen = Future<SpeechResult> Function(
    String expectedKana, List<String> kanjiForms);

/// Speaks Japanese text. Returns null on success, or a message saying why not.
typedef SpeakPlay = Future<String?> Function(String text);

/// One sentence of the drill: the hiragana shown and judged, its kanji surface, and English.
class SpeakSentence {
  const SpeakSentence(
      {required this.kana, required this.surface, required this.en});

  final String kana;
  final String surface;
  final String en;
}

final RegExp _reading = RegExp(r'\{[^}]*\}');

/// One bracket of a kanji twin: the kanji run right before `{`, then its reading. The
/// same shape as `RUBY` in pipeline/jp/ruby.py.
final RegExp _bracket = RegExp(r'[一-鿿々]+\{([^{}]+)\}');

/// A kanji twin with its readings dropped: `買{か}い物{もの}` becomes `買い物`.
String rubySurface(String ruby) => ruby.replaceAll(_reading, '');

/// A kanji twin read out: `買{か}い物{もの}` becomes `かいもの`. This is the drill's expected
/// kana, so an example printed in kanji (「立入禁止{たちいりきんし}」) is judged against
/// hiragana.
String rubyKana(String ruby) =>
    ruby.replaceAllMapped(_bracket, (m) => m.group(1)!);

/// Several forms joined in one example: いこう／たべよう／しよう／こよう.
const String _joiner = '／';

/// Splits a hiragana text and its twin on ／ into one [SpeakSentence] per form. When the
/// two sides do not split alike, the whole pair is one sentence.
Iterable<SpeakSentence> _sentencesOf(String jp, String ruby, String en) {
  final kanaParts = jp.split(_joiner);
  final rubyParts = ruby.split(_joiner);
  final pairs =
      kanaParts.length == rubyParts.length ? rubyParts : <String>[ruby];
  return pairs.map((r) => SpeakSentence(
        kana: rubyKana(r),
        surface: rubySurface(r),
        en: en,
      ));
}

/// Every example in [lesson], then every practice item with its answer in the blank.
/// Point by point, in the order the lesson teaches them. An example that joins forms
/// with ／ gives one sentence per form, and no sentence contains ／.
List<SpeakSentence> lessonSentences(Map<String, dynamic> lesson) {
  final out = <SpeakSentence>[];
  for (final p in (lesson['points'] as List).cast<Map<String, dynamic>>()) {
    for (final e
        in (p['examples'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final jp = e['jp'] as String;
      out.addAll(_sentencesOf(
          jp, e['jp_ruby'] as String? ?? jp, e['en'] as String? ?? ''));
    }
    for (final q
        in (p['practice'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final answer = q['answer'] as String;
      final prompt = q['prompt'] as String;
      final kana = prompt.replaceAll('＿＿', answer);
      final ruby = (q['prompt_ruby'] as String? ?? prompt)
          .replaceAll('＿＿', q['answer_ruby'] as String? ?? answer);
      out.addAll(_sentencesOf(kana, ruby, q['en'] as String? ?? ''));
    }
  }
  return out;
}

/// What the drill does with a verdict.
enum SpeakVerdict { right, close, selfCheck, wrong, nothing }

final RegExp _notKana = RegExp(r'[^ぁ-ゟ]');

/// True when [heard] is plain hiragana or katakana once spacing and punctuation are gone,
/// the only kind of transcript judge() can compare letter for letter.
bool isComparableKana(String heard) {
  final n = SpeechService.normalise(heard);
  return n.isNotEmpty && !_notKana.hasMatch(n);
}

/// Maps judge()'s verdict to the drill's. 🚨 `wrong` survives only for a comparable
/// transcript; anything else goes to self-check (PIN-2).
SpeakVerdict speakVerdict(Judgement j, String heard) {
  if (heard.trim().isEmpty) return SpeakVerdict.nothing;
  return switch (j) {
    Judgement.correct => SpeakVerdict.right,
    Judgement.close => SpeakVerdict.close,
    Judgement.unverified => SpeakVerdict.selfCheck,
    Judgement.wrong =>
      isComparableKana(heard) ? SpeakVerdict.wrong : SpeakVerdict.selfCheck,
  };
}

/// The longest run of [heard] that also appears in one of [targets], as [start, end) in
/// [heard]. Katakana and hiragana count as the same letter. Null when nothing matches.
(int, int)? matchingPart(String heard, List<String> targets) {
  // Katakana to hiragana only, so indexes in the folded text stay indexes in [heard].
  String fold(String s) => String.fromCharCodes(
      s.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r));
  final h = fold(heard);
  var best = (0, 0);
  for (final target in targets) {
    // The sentence's spaces and punctuation go, because a transcript carries none.
    final g = fold(target).replaceAll(RegExp(r'[\s、。・「」！？,.!?]'), '');
    // Longest common substring, one row at a time.
    var prev = List<int>.filled(g.length + 1, 0);
    for (var i = 1; i <= h.length; i++) {
      final cur = List<int>.filled(g.length + 1, 0);
      for (var j = 1; j <= g.length; j++) {
        if (h.codeUnitAt(i - 1) == g.codeUnitAt(j - 1) &&
            h[i - 1].trim().isNotEmpty) {
          cur[j] = prev[j - 1] + 1;
          if (cur[j] > best.$2 - best.$1) best = (i - cur[j], i);
        }
      }
      prev = cur;
    }
  }
  return best.$2 > best.$1 ? best : null;
}

class QuietRoomSpeakWidget extends StatefulWidget {
  const QuietRoomSpeakWidget(
      {super.key, required this.lesson, this.listen, this.play});

  /// The grammar lesson number, as in `grammar[].lesson`.
  final int? lesson;

  /// Test seams. Null uses [SpeechService.instance].
  final SpeakListen? listen;
  final SpeakPlay? play;

  static String routeName = 'quietRoomSpeak';
  static String routePath = '/quietRoomSpeak';

  @override
  State<QuietRoomSpeakWidget> createState() => _QuietRoomSpeakWidgetState();
}

class _QuietRoomSpeakWidgetState extends State<QuietRoomSpeakWidget> {
  /// True when the real recogniser is in use, so cancel and errors go to it.
  bool get _live => widget.listen == null;

  int _index = 0;
  bool _listening = false;
  bool _heardVoice = false;
  String? _micError;

  /// True while Play's voice is speaking. Play and Speak are disabled meanwhile, so the
  /// microphone never hears the app's own voice and credits it to the learner (PIN-2).
  bool _playing = false;

  /// The last attempt on this sentence, or null before one.
  SpeechResult? _result;
  SpeakVerdict? _verdict;

  /// The learner's own mark after a self-check: true for "Got it".
  bool? _selfMark;

  int _seen = 0;
  int _right = 0;

  /// Bumped by every Speak and Stop. A listen whose attempt is no longer current (the
  /// learner pressed Stop, or Speak again) drops its result instead of showing it.
  int _attempt = 0;

  final ValueNotifier<double> _still = ValueNotifier<double>(0);

  ValueListenable<double> get _level =>
      _live ? SpeechService.instance.level : _still;

  @override
  void dispose() {
    if (_live) {
      SpeechService.instance.cancel();
      SpeechService.instance.stopSpeaking();
    }
    _still.dispose();
    super.dispose();
  }

  Future<SpeechResult> _listenOnce(String kana, List<String> kanjiForms) =>
      widget.listen?.call(kana, kanjiForms) ??
      SpeechService.instance
          .listenOnce(expectedKana: kana, kanjiForms: kanjiForms);

  Future<String?> _say(String text) =>
      widget.play?.call(text) ?? SpeechService.instance.speak(text);

  Future<void> _play(SpeakSentence s) async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      // Spoken as a pause, the way quiet_room_grammar_widget.dart reads a joined example.
      // Off the web, speak() returns only when the voice has finished (see _initTts), so
      // the buttons stay disabled for the whole playback. On the web it returns at once.
      final err = await _say(s.kana.replaceAll(_joiner, '、'));
      if (err != null && mounted) {
        final t = QuietRoomTokens.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err, style: qrText(t, size: 13, color: t.onBrand)),
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      // In a finally so a throw from the voice never leaves Speak disabled for good.
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _speak(SpeakSentence s) async {
    if (_listening || _playing) return;
    final attempt = ++_attempt;
    setState(() {
      _listening = true;
      _heardVoice = false;
      _result = null;
      _verdict = null;
      _selfMark = null;
      _micError = null;
    });
    try {
      final r = await _listenOnce(
          s.kana, s.surface == s.kana ? const [] : [s.surface]);
      // Stop (or a later Speak) retired this attempt while it waited: its result is stale.
      if (!mounted || attempt != _attempt) return;
      final v = speakVerdict(r.judgement, r.heard);
      setState(() {
        _result = r;
        _verdict = v;
        if (v == SpeakVerdict.right) {
          _seen++;
          _right++;
        } else if (v == SpeakVerdict.wrong) {
          _seen++;
        }
      });
    } finally {
      // Leaving the panel open on a throw would strand the drill mid-listen. A retired
      // attempt leaves the panel alone: Stop already closed it, or a newer Speak owns it.
      if (mounted && attempt == _attempt) {
        setState(() {
          _listening = false;
          _micError = _live ? SpeechService.instance.lastError : null;
        });
      }
    }
  }

  void _mark(bool gotIt) {
    if (_selfMark != null) return;
    setState(() {
      _selfMark = gotIt;
      _seen++;
      if (gotIt) _right++;
    });
  }

  /// Ignored during a listen, so a pending result is never credited to the next sentence.
  void _next(int count) {
    if (_listening) return;
    setState(() {
      _index = (_index + 1) % count;
      _result = null;
      _verdict = null;
      _selfMark = null;
      _micError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return QrStudyScaffold(
      child: QrLoad(builder: (context, doc) {
        final lesson = (doc['grammar'] as List)
            .cast<Map<String, dynamic>>()
            .where((l) => l['lesson'] == widget.lesson)
            .firstOrNull;
        if (lesson == null) {
          return Center(
              child: Text('No grammar lesson ${widget.lesson ?? ''}.',
                  style: qrText(t, color: t.clay600)));
        }
        final sentences = lessonSentences(lesson);
        if (sentences.isEmpty) {
          return Center(
              child: Text('This lesson has no sentences to speak.',
                  style: qrText(t, color: t.clay600)));
        }
        final s = sentences[_index % sentences.length];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Speak lesson ${lesson['lesson']}',
                        style: qrTitle(t, size: 22))),
                Text(_seen == 0 ? 'Say it' : '$_right of $_seen',
                    style: qrText(t,
                        size: 14, weight: FontWeight.w600, color: t.inkMuted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Sentence ${_index % sentences.length + 1} of ${sentences.length}. '
                'Play it, then say it once.',
                style: qrText(t, size: 13.5, color: t.inkMuted)),
            const SizedBox(height: 16),
            QrCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.kana, style: qrText(t, size: 20, height: 1.5)),
                  if (s.en.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(s.en, style: qrText(t, size: 13.5, color: t.inkMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_listening) _listeningPanel(t) else _controls(t, s),
            if (_micError != null) ...[
              const SizedBox(height: 10),
              Text(_micError!, style: qrText(t, size: 12.5, color: t.clay600)),
            ],
            if (_verdict != null) ...[
              const SizedBox(height: 14),
              _verdictCard(t, s),
            ],
            const SizedBox(height: 22),
            Center(
              child: TextButton(
                onPressed: _listening ? null : () => _next(sentences.length),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
                child: Text('Next sentence',
                    style: qrText(t,
                        size: 14, weight: FontWeight.w600, color: t.brand600)),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _controls(QuietRoomTokens t, SpeakSentence s) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: QuietRoomMetrics.targetMin,
            child: OutlinedButton.icon(
              onPressed: _playing ? null : () => _play(s),
              icon: Icon(Icons.volume_up_outlined, size: 20, color: t.ink),
              label: Text('Play',
                  style: qrText(t, size: 15, weight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: t.borderControl,
                    width: QuietRoomMetrics.strokeControl),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: QuietRoomMetrics.targetMin,
            child: ElevatedButton.icon(
              onPressed: _playing ? null : () => _speak(s),
              icon: Icon(Icons.mic_none, size: 20, color: t.onBrand),
              label: Text('Speak',
                  style: qrText(t,
                      size: 15, weight: FontWeight.w600, color: t.onBrand)),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.brand600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
            level: _level,
            onRealDetected: () {
              if (mounted && !_heardVoice) setState(() => _heardVoice = true);
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_heardVoice ? 'Hearing you' : 'Listening',
                  style: qrText(t,
                      size: 13, weight: FontWeight.w600, color: t.inkMuted)),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  // Retire the pending listen first, so its late result is dropped.
                  _attempt++;
                  if (_live) await SpeechService.instance.cancel();
                  if (mounted) setState(() => _listening = false);
                },
                child: Text('Stop',
                    style: qrText(t,
                        size: 13, weight: FontWeight.w600, color: t.brand600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The heard text, with the part that matches the sentence highlighted.
  Widget _heard(QuietRoomTokens t, String heard, SpeakSentence s) {
    final span = matchingPart(heard, [s.surface, s.kana]);
    final base = qrText(t, size: 15, height: 1.45);
    final lit = base.copyWith(
        backgroundColor: t.amberSurface,
        color: t.amber750,
        fontWeight: FontWeight.w600);
    return Text.rich(
      key: const ValueKey('speak-heard'),
      TextSpan(children: [
        if (span == null)
          TextSpan(text: heard, style: base)
        else ...[
          if (span.$1 > 0)
            TextSpan(text: heard.substring(0, span.$1), style: base),
          TextSpan(text: heard.substring(span.$1, span.$2), style: lit),
          if (span.$2 < heard.length)
            TextSpan(text: heard.substring(span.$2), style: base),
        ],
      ]),
    );
  }

  Widget _verdictCard(QuietRoomTokens t, SpeakSentence s) {
    final r = _result!;
    final v = _verdict!;
    final mark = _selfMark;
    late final Color c;
    late final String head;
    final body = <Widget>[];
    switch (v) {
      case SpeakVerdict.right:
        c = t.sage600;
        head = 'That’s it';
        // The kana is already on the sentence card above. Only a kanji surface adds anything,
        // so a sentence with no kanji is never shown twice.
        if (s.surface != s.kana) {
          body.add(Text(s.surface, style: qrText(t, size: 13.5)));
        }
      case SpeakVerdict.wrong:
        c = t.clay600;
        head = 'Not quite';
        body.add(Text('Heard “${r.heard}” · the sentence is ${s.kana}',
            style: qrText(t, size: 13.5)));
      case SpeakVerdict.close:
        c = t.amber700;
        head = 'Close';
        body
          ..add(_heard(t, r.heard, s))
          ..add(const SizedBox(height: 4))
          ..add(Text('Part of it matched. Did you say the whole sentence?',
              style: qrText(t, size: 13.5)));
      case SpeakVerdict.selfCheck:
        // Being unable to check is not the same as being wrong.
        c = t.amber700;
        head = 'Can’t check this one';
        body
          ..add(_heard(t, r.heard, s))
          ..add(const SizedBox(height: 4))
          ..add(Text('This can’t be checked here. Did you say it?',
              style: qrText(t, size: 13.5)));
      case SpeakVerdict.nothing:
        c = t.amber700;
        head = 'Didn’t catch that';
        body.add(Text(
            'Nothing was heard. Try again, or check the microphone permission.',
            style: qrText(t, size: 13.5)));
    }
    final asks = v == SpeakVerdict.close || v == SpeakVerdict.selfCheck;
    return Container(
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
              style: qrText(t, size: 14, weight: FontWeight.w600, color: c)),
          const SizedBox(height: 3),
          ...body,
          if (asks && mark == null) ...[
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton(
                onPressed: () => _mark(true),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.sage600, width: 1)),
                child: Text('Got it',
                    style: qrText(t,
                        size: 13, weight: FontWeight.w600, color: t.sage700)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _mark(false),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.border, width: 1)),
                child: Text('Missed it',
                    style: qrText(t,
                        size: 13, weight: FontWeight.w600, color: t.inkMuted)),
              ),
            ]),
          ],
          if (asks && mark != null) ...[
            const SizedBox(height: 8),
            Text(mark ? 'Marked as said.' : 'Marked to try again.',
                style: qrText(t,
                    size: 13,
                    weight: FontWeight.w600,
                    color: mark ? t.sage700 : t.inkMuted)),
          ],
        ],
      ),
    );
  }
}
