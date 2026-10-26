// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Grammar, lesson by lesson, from Mari's N4 checklist (Minna no Nihongo 26 to 50).
// Each grammar point is a five-minute lesson: what it means, how to build it, two
// examples, two practice items, and Mari's own self-check.
//
// THE PATTERN, GOAL AND FIRST EXAMPLE ARE MARI'S. The explanation, second example and
// practice are drafts (pipeline/jp/drafts, the OPM's Drafting stage) and the screen
// says so until they are reviewed. Recall first, as on the vocabulary screen: English
// and answers stay hidden until tapped.
//
// Hiragana is the default (PIN-4, PIN-7). The 漢字 toggle swaps every sentence, option
// and answer for its kanji twin's surface. A fill-in item takes a typed answer from the
// Japanese keyboard (PIN-3), judged by `checkTypedAnswer()` in jp_study_kit.dart. Each
// lesson opens its speaking drill from "Speak this lesson" (PIN-6).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_practice/speech_service.dart';
import 'jp_study_kit.dart';
import 'quiet_room_speak_widget.dart';

/// The hint every typed-answer box asks the keyboard for: Gboard opens in Japanese.
const List<Locale> jpKeyboard = [Locale('ja', 'JP')];

/// [ruby]'s kanji surface when [kanji] is on, else [kana]. A missing twin shows [kana].
String jpShown(bool kanji, String kana, Object? ruby) =>
    kanji && ruby is String ? rubySurface(ruby) : kana;

class QuietRoomGrammarWidget extends StatefulWidget {
  const QuietRoomGrammarWidget(
      {super.key, this.initialLesson, this.initialQuery});

  final int? initialLesson;

  /// Opens with this search already typed (a catalog link to an untaught particle).
  final String? initialQuery;

  static String routeName = 'quietRoomGrammar';
  static String routePath = '/quietRoomGrammar';

  @override
  State<QuietRoomGrammarWidget> createState() => _QuietRoomGrammarWidgetState();
}

class _QuietRoomGrammarWidgetState extends State<QuietRoomGrammarWidget> {
  int? _lesson;
  bool _byUse = false;
  String? _use;

  /// Off by default: hiragana is the default display (PIN-4).
  bool _kanji = false;
  late String _query = widget.initialQuery ?? '';
  late final _searchCtl = TextEditingController(text: widget.initialQuery);

  /// The start screen's hero continues from here. Same key as
  /// QuietRoomJapaneseWidget.lastLessonKey, spelled out to avoid an import cycle.
  static Future<void> _remember(int lesson) async =>
      (await SharedPreferences.getInstance())
          .setInt('jp.grammar.lastLesson', lesson);

  @override
  void initState() {
    super.initState();
    if (widget.initialLesson != null) _remember(widget.initialLesson!);
  }

  /// Everything a learner might type: the pattern, what it is for, the explanation,
  /// the examples in both languages, and the use labels.
  bool _matches(Map<String, dynamic> p, Map<String, String> useNames) {
    final q = _query.toLowerCase();
    final hay = <String>[
      p['pattern'] as String? ?? '',
      p['goal'] as String? ?? '',
      p['explain'] as String? ?? '',
      p['form'] as String? ?? '',
      p['note'] as String? ?? '',
      for (final e in (p['examples'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) ...[
        e['jp'] as String? ?? '',
        rubySurface(e['jp_ruby'] as String? ?? ''),
        e['en'] as String? ?? '',
      ],
      for (final u in (p['uses'] as List? ?? const []).cast<String>())
        useNames[u] ?? '',
    ];
    return hay.any((h) => h.toLowerCase().contains(q));
  }

  int _count(List<Map<String, dynamic>> all, Object? use) =>
      all.where((p) => (p['uses'] as List? ?? const []).contains(use)).length;

  @override
  Widget build(BuildContext context) {
    return QrStudyScaffold(
      child: QrLoad(builder: (context, doc) {
        final t = QuietRoomTokens.of(context);
        final lessons = (doc['grammar'] as List).cast<Map<String, dynamic>>();
        final uses =
            ((doc['uses'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final useNames = {
          for (final u in uses) u['id'] as String: u['label'] as String
        };
        final all = [
          for (final l in lessons)
            for (final p in (l['points'] as List).cast<Map<String, dynamic>>())
              {...p, 'lesson': l['lesson']},
        ];
        _lesson ??= widget.initialLesson ?? lessons.first['lesson'] as int;
        final lesson = lessons.firstWhere((l) => l['lesson'] == _lesson,
            orElse: () => lessons.first);
        final title = lesson['title'] as String? ?? '';

        // Three ways in. Typing wins over everything, then "by use", then by lesson.
        final searching = _query.isNotEmpty;
        final List<Map<String, dynamic>> points;
        final String heading;
        final String sub;
        if (searching) {
          points = all.where((p) => _matches(p, useNames)).toList();
          heading = 'Search';
          sub =
              '${points.length} ${points.length == 1 ? 'point matches' : 'points match'}';
        } else if (_byUse) {
          points = _use == null
              ? const []
              : all
                  .where((p) => (p['uses'] as List? ?? const []).contains(_use))
                  .toList();
          heading = _use == null ? 'By use' : useNames[_use]!;
          sub = _use == null
              ? 'Pick what you want to say.'
              : '${points.length} patterns, from lessons '
                  '${points.map((p) => p['lesson']).toSet().join(', ')}';
        } else {
          points = (lesson['points'] as List).cast<Map<String, dynamic>>();
          heading = '第${lesson['lesson']}課';
          sub = [if (title.isNotEmpty) title, '${points.length} points']
              .join(' · ');
        }
        final crossLesson = searching || _byUse;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(heading, style: qrTitle(t))),
                const SizedBox(width: 8),
                Semantics(
                  toggled: _kanji,
                  label: 'Show kanji',
                  child: QrPill(
                      key: const ValueKey('kanji-toggle'),
                      label: '漢字',
                      on: _kanji,
                      solid: false,
                      onTap: () => setState(() => _kanji = !_kanji)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(sub, style: qrText(t, color: t.inkMuted)),
            const SizedBox(height: 14),
            _search(t),
            const SizedBox(height: 12),
            if (!searching) ...[
              Row(children: [
                QrPill(
                    label: 'By lesson',
                    on: !_byUse,
                    solid: false,
                    onTap: () => setState(() => _byUse = false)),
                const SizedBox(width: 8),
                QrPill(
                    label: 'By use',
                    on: _byUse,
                    solid: false,
                    onTap: () => setState(() => _byUse = true)),
              ]),
              const SizedBox(height: 12),
              if (_byUse)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final u in uses)
                    QrPill(
                      label: '${u['label']}  ${_count(all, u['id'])}',
                      on: _use == u['id'],
                      onTap: () => setState(() =>
                          _use = _use == u['id'] ? null : u['id'] as String),
                    ),
                ])
              else
                QrNumberStrip(
                  values: lessons.map((l) => l['lesson'] as int).toList(),
                  selected: lesson['lesson'] as int,
                  onSelect: (n) {
                    setState(() => _lesson = n);
                    _remember(n);
                  },
                ),
              if (!_byUse) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.pushNamed(QuietRoomSpeakWidget.routeName,
                            queryParameters: {
                              'lesson': serializeParam(
                                  lesson['lesson'] as int, ParamType.int),
                            }.withoutNulls),
                    icon: Icon(Icons.mic_none, size: 18, color: t.brand600),
                    label: Text('Speak this lesson',
                        style: qrText(t,
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: t.brand600)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, QuietRoomMetrics.targetMin),
                      side: BorderSide(color: t.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            ...points.map((p) => Padding(
                  // Keyed by id so a card's revealed state never carries over to the
                  // same position in another lesson.
                  key: ValueKey(p['id']),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PointCard(
                    point: p,
                    lesson: crossLesson ? p['lesson'] as int? : null,
                    useNames: useNames,
                    kanji: _kanji,
                  ),
                )),
            const SizedBox(height: 4),
            Text(
              'Pattern, goal and first example are Mari\'s. The explanation, second '
              'example and practice are drafts, not yet checked by Mari.',
              style: qrText(t, size: 11.5, color: t.inkSubtle, height: 1.45),
            ),
          ],
        );
      }),
    );
  }

  Widget _search(QuietRoomTokens t) => TextField(
        controller: _searchCtl,
        onChanged: (v) => setState(() => _query = v.trim()),
        style: qrText(t, size: 15),
        cursorColor: t.brand600,
        decoration: InputDecoration(
          hintText: 'Search: advice, plan, ので, regret',
          hintStyle: qrText(t, size: 15, color: t.inkSubtle),
          prefixIcon: Icon(Icons.search, size: 20, color: t.inkMuted),
          filled: true,
          fillColor: t.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: t.border, width: 1),
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: t.borderFocus, width: QuietRoomMetrics.strokeFocus),
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
          ),
        ),
      );
}

class _PointCard extends StatefulWidget {
  const _PointCard(
      {required this.point,
      this.lesson,
      this.useNames = const {},
      this.kanji = false});

  final Map<String, dynamic> point;

  /// Set when the card shows outside its lesson (search, by use), so it says where it
  /// comes from.
  final int? lesson;
  final Map<String, String> useNames;

  /// Show each sentence's kanji twin instead of its hiragana.
  final bool kanji;

  @override
  State<_PointCard> createState() => _PointCardState();
}

class _PointCardState extends State<_PointCard> {
  final Set<int> _shownEn = {};
  String? _check;

  String get _id => widget.point['id'] as String;

  @override
  void initState() {
    super.initState();
    SelfCheck.get(_id).then((v) {
      if (mounted) setState(() => _check = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final p = widget.point;
    final examples = ((p['examples'] as List?) ??
            [
              {'jp': p['example'], 'en': ''}
            ])
        .cast<Map<String, dynamic>>();
    final practice =
        ((p['practice'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final note = p['note'] as String? ?? '';

    return QrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p['pattern'] as String,
              style: qrText(t,
                  size: 16,
                  weight: FontWeight.w600,
                  color: t.inkStrong,
                  height: 1.35)),
          const SizedBox(height: 4),
          Text(p['goal'] as String,
              style: qrText(t, size: 13, color: t.inkMuted)),
          const SizedBox(height: 4),
          Text(
            [
              if (widget.lesson != null) '第${widget.lesson}課',
              for (final u in (p['uses'] as List? ?? const []).cast<String>())
                widget.useNames[u] ?? u,
            ].join(' · '),
            style: qrText(t,
                size: 11.5, weight: FontWeight.w600, color: t.sage700),
          ),
          if (p['explain'] != null) ...[
            const SizedBox(height: 12),
            Text(p['explain'] as String,
                style: qrText(t, size: 14.5, height: 1.45)),
          ],
          if (p['form'] != null) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: t.surfaceTinted,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(p['form'] as String,
                  style: qrText(t,
                      size: 14, weight: FontWeight.w600, color: t.brand700)),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(note,
                style: qrText(t, size: 12.5, color: t.amber700, height: 1.4)),
          ],
          const SizedBox(height: 14),
          _label(t, 'Examples'),
          ...examples.asMap().entries.map((e) => _example(t, e.key, e.value)),
          if (practice.isNotEmpty) ...[
            const SizedBox(height: 12),
            _label(t, 'Practice'),
            ...practice.map((q) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Practice(item: q, kanji: widget.kanji),
                )),
          ],
          const SizedBox(height: 14),
          Row(children: [
            QrPill(
                label: 'Can use it',
                on: _check == 'can_use_it',
                solid: false,
                onTap: () => _setCheck('can_use_it')),
            const SizedBox(width: 8),
            QrPill(
                label: 'Review',
                on: _check == 'review_needed',
                solid: false,
                onTap: () => _setCheck('review_needed')),
          ]),
        ],
      ),
    );
  }

  void _setCheck(String v) {
    final next = _check == v ? null : v;
    setState(() => _check = next);
    SelfCheck.set(_id, next);
  }

  Widget _label(QuietRoomTokens t, String s) => Text(s.toUpperCase(),
      style: qrText(t, size: 11, weight: FontWeight.w600, color: t.inkSubtle)
          .copyWith(letterSpacing: 11 * 0.06));

  Widget _example(QuietRoomTokens t, int i, Map<String, dynamic> e) {
    final jp = e['jp'] as String? ?? '';
    final shownJp = jpShown(widget.kanji, jp, e['jp_ruby']);
    final en = e['en'] as String? ?? '';
    final shown = _shownEn.contains(i);
    return InkWell(
      onTap: en.isEmpty
          ? null
          : () => setState(() => shown ? _shownEn.remove(i) : _shownEn.add(i)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shownJp,
                      style: qrText(t,
                          size: 16.5, color: t.inkStrong, height: 1.5)),
                  if (en.isNotEmpty)
                    AnimatedSwitcher(
                      duration: QuietRoomMotion.quick,
                      child: Text(shown ? en : 'Tap for English',
                          key: ValueKey(shown),
                          style: qrText(t,
                              size: shown ? 13 : 12,
                              color: shown ? t.ink : t.inkSubtle)),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.volume_up_outlined, size: 19, color: t.inkMuted),
              tooltip: 'Hear it',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final err =
                    await SpeechService.instance.speak(jp.replaceAll('／', '、'));
                if (err != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(err),
                      duration: const Duration(seconds: 5)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One practice item. "choose" checks the tap. "fill" takes a typed answer from the
/// Japanese keyboard (PIN-3), or reveals the answer on request.
///
/// 🚨 A typed answer is marked wrong only when it is plain kana that matches no answer
/// form. An answer the matcher cannot compare goes to self-check (PIN-2, PIN-7).
class _Practice extends StatefulWidget {
  const _Practice({required this.item, this.kanji = false});

  final Map<String, dynamic> item;
  final bool kanji;

  @override
  State<_Practice> createState() => _PracticeState();
}

class _PracticeState extends State<_Practice> {
  bool _revealed = false;
  String? _picked;

  final _typed = TextEditingController();
  TypedVerdict? _verdict;

  /// The learner's own mark after a self-check: true for "Got it".
  bool? _selfMark;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _check() {
    final v = checkTypedAnswer(_typed.text, widget.item);
    setState(() {
      _verdict = v == TypedVerdict.empty ? null : v;
      _selfMark = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final q = widget.item;
    final kanji = widget.kanji;
    final answer = q['answer'] as String;
    final shownAnswer = jpShown(kanji, answer, q['answer_ruby']);
    final accepted = ((q['accepted'] as List?) ?? const []).cast<String>();
    final acceptedRuby =
        ((q['accepted_ruby'] as List?) ?? const []).cast<String>();
    final shownAccepted = kanji && acceptedRuby.length == accepted.length
        ? acceptedRuby.map(rubySurface).toList()
        : accepted;
    final options = ((q['options'] as List?) ?? const []).cast<String>();
    final optionsRuby =
        ((q['options_ruby'] as List?) ?? const []).cast<String>();
    // An option as the toggle shows it. The check and the why_wrong key stay on the
    // hiragana option.
    String shownOption(String o) =>
        kanji && optionsRuby.length == options.length
            ? rubySurface(optionsRuby[options.indexOf(o)])
            : o;
    final typedRight = _verdict == TypedVerdict.right;
    final done = _revealed || _picked != null || typedRight;
    // A wrong verdict has nothing to say once the answer is shown. Self-check stays:
    // it carries the Got it and Missed it pills.
    final feedbackApplies =
        _verdict != null && !(done && _verdict == TypedVerdict.wrong);
    final prompt = jpShown(kanji, q['prompt'] as String, q['prompt_ruby'])
        .replaceAll('＿＿', done ? '［$shownAnswer］' : '＿＿＿');

    return Container(
      decoration: BoxDecoration(
        color: t.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt,
              style: qrText(t, size: 16, color: t.inkStrong, height: 1.5)),
          if (q['en'] != null)
            Text(q['en'] as String,
                style: qrText(t, size: 12.5, color: t.inkMuted)),
          const SizedBox(height: 8),
          if (options.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((o) {
                final label = shownOption(o);
                final picked = _picked == o;
                final right = o == answer;
                final Color fill = _picked == null
                    ? t.surface
                    : right
                        ? t.sage100
                        : picked
                            ? t.claySurface
                            : t.surface;
                final Color edge = _picked == null
                    ? t.borderControl
                    : right
                        ? t.sage600
                        : picked
                            ? t.clay600
                            : t.border;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _picked == null
                        ? () => setState(() => _picked = o)
                        : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fill,
                        border: Border.all(color: edge, width: 1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(label,
                          style: qrText(t, size: 15, color: t.inkStrong)),
                    ),
                  ),
                );
              }).toList(),
            )
          else ...[
            if (!done) _answerBox(t),
            if (feedbackApplies) _feedback(t, shownAnswer, q),
            if (!done)
              Row(children: [
                if (q['hint'] != null)
                  Expanded(
                      child: Text('Hint: ${q['hint']}',
                          style: qrText(t, size: 12.5, color: t.inkMuted)))
                else
                  const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _revealed = true),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
                  child: Text('Show answer',
                      style: qrText(t,
                          size: 13,
                          weight: FontWeight.w600,
                          color: t.brand600)),
                ),
              ]),
          ],
          if (done && accepted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Also correct: ${shownAccepted.join('、')}',
                  style: qrText(t, size: 12.5, color: t.inkMuted)),
            ),
          // A wrong tap says why that option is wrong, then names the rule. The line
          // quotes the option as the toggle showed it.
          if (_picked != null && _picked != answer)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [
                  if ((q['why_wrong'] as Map?)?[_picked] != null)
                    '${shownOption(_picked!)}: ${(q['why_wrong'] as Map)[_picked]}',
                  if (q['hint'] != null) '${q['hint']}',
                ].join('\n'),
                style: qrText(t, size: 12.5, color: t.clay600),
              ),
            ),
        ],
      ),
    );
  }

  /// The typed-answer box. `hintLocales` asks the keyboard for Japanese (PIN-3).
  Widget _answerBox(QuietRoomTokens t) => Row(children: [
        Expanded(
          child: TextField(
            controller: _typed,
            hintLocales: jpKeyboard,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onSubmitted: (_) => _check(),
            onChanged: (_) {
              if (_verdict != null) setState(() => _verdict = null);
            },
            style: qrText(t, size: 16, color: t.inkStrong),
            cursorColor: t.brand600,
            decoration: InputDecoration(
              hintText: 'Type the answer',
              hintStyle: qrText(t, size: 14, color: t.inkSubtle),
              filled: true,
              fillColor: t.surface,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.borderControl, width: 1),
                borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: t.borderFocus, width: QuietRoomMetrics.strokeFocus),
                borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _check,
          style: TextButton.styleFrom(
              minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
          child: Text('Check',
              style: qrText(t,
                  size: 13, weight: FontWeight.w600, color: t.brand600)),
        ),
      ]);

  Widget _feedback(
      QuietRoomTokens t, String shownAnswer, Map<String, dynamic> q) {
    final Widget body = switch (_verdict!) {
      TypedVerdict.right => Text('Correct.',
          style:
              qrText(t, size: 13, weight: FontWeight.w600, color: t.sage700)),
      TypedVerdict.wrong => Text(
          [
            'Not quite. Try again, or show the answer.',
            if (q['hint'] != null) '${q['hint']}',
          ].join('\n'),
          style: qrText(t, size: 12.5, color: t.clay600)),
      // Cannot be compared letter for letter, so the learner judges it (PIN-2).
      TypedVerdict.selfCheck => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Can't check that spelling here. Compare with the answer: "
                '$shownAnswer',
                style: qrText(t, size: 12.5, color: t.amber700)),
            const SizedBox(height: 6),
            Row(children: [
              QrPill(
                  label: 'Got it',
                  on: _selfMark == true,
                  solid: false,
                  onTap: () => setState(() => _selfMark = true)),
              const SizedBox(width: 8),
              QrPill(
                  label: 'Missed it',
                  on: _selfMark == false,
                  solid: false,
                  onTap: () => setState(() => _selfMark = false)),
            ]),
          ],
        ),
      TypedVerdict.empty => const SizedBox.shrink(),
    };
    return Padding(padding: const EdgeInsets.only(top: 6), child: body);
  }
}
