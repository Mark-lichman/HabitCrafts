// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The start screen of this build: Japanese study, no login. Mark asked for a
// single-user build (2026-10-24), so there is no account and nothing here reads
// Firestore. Everything comes from the bundled lesson files.
//
// Quiet Room: one loud object. The hero is the grammar lesson to continue, because
// grammar is where the practice is needed most. Everything else is a quiet card.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart';
import 'jp_study_kit.dart';
import 'quiet_room_drills_widget.dart';
import 'quiet_room_grammar_widget.dart';

class QuietRoomJapaneseWidget extends StatefulWidget {
  const QuietRoomJapaneseWidget({super.key});

  static String routeName = 'quietRoomJapanese';
  static String routePath = '/quietRoomJapanese';

  /// The lesson the hero card continues. Written by the grammar screen.
  static const lastLessonKey = 'jp.grammar.lastLesson';

  @override
  State<QuietRoomJapaneseWidget> createState() => _QuietRoomJapaneseWidgetState();
}

class _QuietRoomJapaneseWidgetState extends State<QuietRoomJapaneseWidget> {
  int? _last;

  @override
  void initState() {
    super.initState();
    _readLast();
  }

  Future<void> _readLast() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _last = p.getInt(QuietRoomJapaneseWidget.lastLessonKey));
  }

  Future<void> _open(String route, [Map<String, dynamic> params = const {}]) async {
    await context.pushNamed(route, queryParameters: params);
    _readLast(); // the grammar screen may have moved on
  }

  @override
  Widget build(BuildContext context) {
    return QrStudyScaffold(
      showBack: false,
      child: QrLoad(builder: (context, doc) {
        final t = QuietRoomTokens.of(context);
        final grammar = (doc['grammar'] as List).cast<Map<String, dynamic>>();
        final lesson = grammar.firstWhere((g) => g['lesson'] == _last,
            orElse: () => grammar.first);
        final points = (lesson['points'] as List).length;
        final verbs = (doc['conjugation']['verbs'] as List).length;
        final pairs = (doc['pairs'] as List).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            Text('日本語', style: qrTitle(t, size: 30)),
            const SizedBox(height: 5),
            Text('Five minutes of grammar, then one drill.',
                style: qrText(t, color: t.inkMuted)),
            const SizedBox(height: 20),
            _hero(t, lesson, points),
            const SizedBox(height: 22),
            _row(t, 'Grammar lessons', 'Mari\'s checklist · 第26課 to 第50課',
                () => _open(QuietRoomGrammarWidget.routeName)),
            _row(t, 'Conjugation', '$verbs verbs · 12 forms',
                () => _open(QuietRoomDrillsWidget.routeName, {'mode': 'conjugation'})),
            _row(t, 'Verb pairs', '$pairs pairs · が and を',
                () => _open(QuietRoomDrillsWidget.routeName, {'mode': 'pairs'})),
            _row(t, 'Numbers and counters', 'Counters, dates, months, lengths of time',
                () => _open(QuietRoomDrillsWidget.routeName, {'mode': 'reference'})),
            _row(t, 'Vocabulary', 'Minna no Nihongo · 620 words',
                () => _open(QuietRoomLessonWidget.routeName)),
          ],
        );
      }),
    );
  }

  Widget _hero(QuietRoomTokens t, Map<String, dynamic> lesson, int points) {
    final title = lesson['title'] as String? ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
        onTap: () => _open(QuietRoomGrammarWidget.routeName,
            {'lesson': serializeParam(lesson['lesson'], ParamType.int)}),
        child: Container(
          decoration: BoxDecoration(
            color: t.heroFill,
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_last == null ? 'START HERE' : 'CONTINUE',
                  style: qrText(t, size: 11, weight: FontWeight.w600, color: t.heroInkMuted)
                      .copyWith(letterSpacing: 11 * 0.08)),
              const SizedBox(height: 8),
              Text('第${lesson['lesson']}課',
                  style: qrTitle(t, size: 28).copyWith(color: t.heroInk)),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(title, style: qrText(t, size: 15, color: t.heroInk)),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Text('$points grammar points',
                    style: qrText(t, size: 13, color: t.heroInkMuted)),
                const Spacer(),
                Icon(Icons.arrow_forward, size: 20, color: t.heroInk),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(QuietRoomTokens t, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: QrCard(
          onTap: onTap,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: qrText(t, size: 15.5, weight: FontWeight.w600, color: t.inkStrong)),
                const SizedBox(height: 3),
                Text(sub, style: qrText(t, size: 12.5, color: t.inkMuted)),
              ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: t.brand600),
          ]),
        ),
      );
}
