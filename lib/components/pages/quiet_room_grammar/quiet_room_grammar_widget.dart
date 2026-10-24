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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_practice/speech_service.dart';
import 'jp_study_kit.dart';

class QuietRoomGrammarWidget extends StatefulWidget {
  const QuietRoomGrammarWidget({super.key, this.initialLesson});

  final int? initialLesson;

  static String routeName = 'quietRoomGrammar';
  static String routePath = '/quietRoomGrammar';

  @override
  State<QuietRoomGrammarWidget> createState() => _QuietRoomGrammarWidgetState();
}

class _QuietRoomGrammarWidgetState extends State<QuietRoomGrammarWidget> {
  int? _lesson;

  /// The start screen's hero continues from here. Same key as
  /// QuietRoomJapaneseWidget.lastLessonKey, spelled out to avoid an import cycle.
  static Future<void> _remember(int lesson) async =>
      (await SharedPreferences.getInstance()).setInt('jp.grammar.lastLesson', lesson);

  @override
  void initState() {
    super.initState();
    if (widget.initialLesson != null) _remember(widget.initialLesson!);
  }

  @override
  Widget build(BuildContext context) {
    return QrStudyScaffold(
      child: QrLoad(builder: (context, doc) {
        final t = QuietRoomTokens.of(context);
        final lessons = (doc['grammar'] as List).cast<Map<String, dynamic>>();
        _lesson ??= widget.initialLesson ?? lessons.first['lesson'] as int;
        final lesson = lessons.firstWhere((l) => l['lesson'] == _lesson,
            orElse: () => lessons.first);
        final points = (lesson['points'] as List).cast<Map<String, dynamic>>();
        final draft = lesson['status'] == 'draft';
        final title = lesson['title'] as String? ?? '';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('第${lesson['lesson']}課', style: qrTitle(t)),
            const SizedBox(height: 5),
            Text(
              [if (title.isNotEmpty) title, '${points.length} points'].join(' · '),
              style: qrText(t, color: t.inkMuted),
            ),
            const SizedBox(height: 16),
            QrNumberStrip(
              values: lessons.map((l) => l['lesson'] as int).toList(),
              selected: lesson['lesson'] as int,
              onSelect: (n) {
                setState(() => _lesson = n);
                _remember(n);
              },
            ),
            const SizedBox(height: 14),
            ...points.map((p) => Padding(
                  // Keyed by id so a card's revealed state never carries over to the
                  // same position in another lesson.
                  key: ValueKey(p['id']),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PointCard(point: p),
                )),
            const SizedBox(height: 4),
            Text(
              draft
                  ? 'Pattern, goal and first example are Mari\'s. The explanation, second '
                      'example and practice are drafts, not yet checked by Mari.'
                  : 'Mari\'s pattern, goal and example. The short lesson for this one is '
                      'not written yet.',
              style: qrText(t, size: 11.5, color: t.inkSubtle, height: 1.45),
            ),
          ],
        );
      }),
    );
  }
}

class _PointCard extends StatefulWidget {
  const _PointCard({required this.point});

  final Map<String, dynamic> point;

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
    final examples = ((p['examples'] as List?) ?? [
      {'jp': p['example'], 'en': ''}
    ])
        .cast<Map<String, dynamic>>();
    final practice = ((p['practice'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final note = p['note'] as String? ?? '';

    return QrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p['pattern'] as String,
              style: qrText(t, size: 16, weight: FontWeight.w600, color: t.inkStrong, height: 1.35)),
          const SizedBox(height: 4),
          Text(p['goal'] as String, style: qrText(t, size: 13, color: t.inkMuted)),
          if (p['explain'] != null) ...[
            const SizedBox(height: 12),
            Text(p['explain'] as String, style: qrText(t, size: 14.5, height: 1.45)),
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
                  style: qrText(t, size: 14, weight: FontWeight.w600, color: t.brand700)),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(note, style: qrText(t, size: 12.5, color: t.amber700, height: 1.4)),
          ],
          const SizedBox(height: 14),
          _label(t, 'Examples'),
          ...examples.asMap().entries.map((e) => _example(t, e.key, e.value)),
          if (practice.isNotEmpty) ...[
            const SizedBox(height: 12),
            _label(t, 'Practice'),
            ...practice.map((q) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Practice(item: q),
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
    final en = e['en'] as String? ?? '';
    final shown = _shownEn.contains(i);
    return InkWell(
      onTap: en.isEmpty ? null : () => setState(() => shown ? _shownEn.remove(i) : _shownEn.add(i)),
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
                  Text(jp, style: qrText(t, size: 16.5, color: t.inkStrong, height: 1.5)),
                  if (en.isNotEmpty)
                    AnimatedSwitcher(
                      duration: QuietRoomMotion.quick,
                      child: Text(shown ? en : 'Tap for English',
                          key: ValueKey(shown),
                          style: qrText(t,
                              size: shown ? 13 : 12, color: shown ? t.ink : t.inkSubtle)),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.volume_up_outlined, size: 19, color: t.inkMuted),
              tooltip: 'Hear it',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final err = await SpeechService.instance.speak(jp.replaceAll('／', '、'));
                if (err != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err), duration: const Duration(seconds: 5)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One practice item. "choose" checks the tap; "fill" asks for recall, then reveals.
class _Practice extends StatefulWidget {
  const _Practice({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_Practice> createState() => _PracticeState();
}

class _PracticeState extends State<_Practice> {
  bool _revealed = false;
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final q = widget.item;
    final answer = q['answer'] as String;
    final accepted = ((q['accepted'] as List?) ?? const []).cast<String>();
    final options = ((q['options'] as List?) ?? const []).cast<String>();
    final done = _revealed || _picked != null;
    final prompt = (q['prompt'] as String).replaceAll('＿＿', done ? '［$answer］' : '＿＿＿');

    return Container(
      decoration: BoxDecoration(
        color: t.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt, style: qrText(t, size: 16, color: t.inkStrong, height: 1.5)),
          if (q['en'] != null)
            Text(q['en'] as String, style: qrText(t, size: 12.5, color: t.inkMuted)),
          const SizedBox(height: 8),
          if (options.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((o) {
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
                    onTap: _picked == null ? () => setState(() => _picked = o) : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fill,
                        border: Border.all(color: edge, width: 1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(o, style: qrText(t, size: 15, color: t.inkStrong)),
                    ),
                  ),
                );
              }).toList(),
            )
          else if (!_revealed)
            Row(children: [
              if (q['hint'] != null)
                Expanded(
                    child: Text('Hint: ${q['hint']}',
                        style: qrText(t, size: 12.5, color: t.inkMuted))),
              TextButton(
                onPressed: () => setState(() => _revealed = true),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, QuietRoomMetrics.targetMin)),
                child: Text('Show answer',
                    style: qrText(t, size: 13, weight: FontWeight.w600, color: t.brand600)),
              ),
            ]),
          if (done && accepted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Also correct: ${accepted.join('、')}',
                  style: qrText(t, size: 12.5, color: t.inkMuted)),
            ),
          if (_picked != null && _picked != answer && q['hint'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${q['hint']}', style: qrText(t, size: 12.5, color: t.clay600)),
            ),
        ],
      ),
    );
  }
}
