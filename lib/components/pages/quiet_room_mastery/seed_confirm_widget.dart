// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The seed confirmation (plan 2026-11-02, Task 20, D7, D21, PIN-7, PIN-12). On a first launch
// the app asks which lessons Mark has already studied before it seeds them: one tick per
// lesson, word lessons and grammar lessons apart, and one Confirm.
//
// The default ticks (`defaultSeedLessons`): word lessons 2 to 30 and grammar lessons 26 to 31
// (seed.dart's constants). `jp.grammar.lastLesson`, the grammar lesson last opened, extends
// the grammar ticks to it when it is past 31, so lessons studied beyond the plan's range come
// in too. It never unticks one: a lesson reopened for review is no sign the later ones were
// not studied.
//
// Any lesson can be unticked to skip it for now: its items stay New and arrive through the
// daily intake (seed.dart). Beside each section heading a toggle reads Select all, or Clear
// all once every lesson of that section is ticked; the ticked count and Confirm follow it.
// Confirm with no lesson ticked is allowed: it seeds no lesson item, only the level-0 items
// every seed holds. Confirm calls `seedFromLessons` with the ticked set, the device's
// `SharedPreferences` and the decoded `jp_grammar.json`, passed together so the v2 keys import
// through the store's migration. The seed writes no attempt and no clear (PIN-7).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'attempt.dart' show ItemKind;
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'review_page.dart' show QrLoudButton, qrLoadingOr;
import 'seed.dart';

/// The `SharedPreferences` key of the grammar lesson last opened. The grammar screen writes
/// it, and so does the lesson path when a 第26課 to 第50課 page opens (ASK-11).
const String kLastGrammarLessonKey = 'jp.grammar.lastLesson';

/// The toggle beside each section heading: Select all, or Clear all when every lesson of the
/// section is ticked.
const String kSeedSelectAll = 'Select all';
const String kSeedClearAll = 'Clear all';

/// The lesson numbers the catalog holds for [kind], ascending.
List<int> catalogLessons(ItemCatalog catalog, ItemKind kind) => ({
      for (final i in catalog.items)
        if (i.kind == kind && i.lesson != null && i.prereqLevel != 0) i.lesson!
    }.toList()
      ..sort());

/// The lessons ticked before Mark changes anything (see the file comment). Pure.
SeedLessons defaultSeedLessons(ItemCatalog catalog, {int? lastGrammarLesson}) {
  final standard = SeedLessons.standard();
  final lastGrammar =
      lastGrammarLesson != null && lastGrammarLesson > kSeedLastGrammarLesson
          ? lastGrammarLesson
          : kSeedLastGrammarLesson;
  return SeedLessons(
    wordLessons: {
      for (final l in catalogLessons(catalog, ItemKind.word))
        if (standard.wordLessons.contains(l)) l
    },
    grammarLessons: {
      for (final l in catalogLessons(catalog, ItemKind.grammar))
        if (l >= kSeedFirstGrammarLesson && l <= lastGrammar) l
    },
  );
}

class SeedConfirmWidget extends StatefulWidget {
  const SeedConfirmWidget({
    super.key,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
    this.onSeeded,
  });

  static String routeName = 'quietRoomSeedConfirm';
  static String routePath = '/quietRoomSeedConfirm';

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;

  /// Called once the seed is written. Null goes to the home (`/`), or pops where no router is.
  final VoidCallback? onSeeded;

  @override
  State<SeedConfirmWidget> createState() => _SeedConfirmWidgetState();
}

class _SeedConfirmWidgetState extends State<SeedConfirmWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  List<int> _wordLessons = const [];
  List<int> _grammarLessons = const [];
  Set<int> _words = {};
  Set<int> _grammar = {};
  Object? _loadError;
  String? _seedError;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final prefs = await SharedPreferences.getInstance();
      final ticks = defaultSeedLessons(catalog,
          lastGrammarLesson: prefs.getInt(kLastGrammarLessonKey));
      if (!mounted) return;
      setState(() {
        _store = store;
        _wordLessons = catalogLessons(catalog, ItemKind.word);
        _grammarLessons = catalogLessons(catalog, ItemKind.grammar);
        _words = {...ticks.wordLessons};
        _grammar = {...ticks.grammarLessons};
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _seedError = null;
    });
    try {
      final now = widget.clock.now();
      await seedFromLessons(
        localDay(now),
        _store!,
        _catalog!,
        lessons: SeedLessons(wordLessons: _words, grammarLessons: _grammar),
        prefs: await SharedPreferences.getInstance(),
        grammar: await JpGrammarData.load(),
        nowUtc: now.toUtc(),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _seedError = 'Could not save the lessons: $e';
        });
      }
      return;
    }
    if (!mounted) return;
    final onSeeded = widget.onSeeded;
    if (onSeeded != null) {
      onSeeded();
    } else if (GoRouter.maybeOf(context) != null) {
      context.go('/');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    if (!_loaded) {
      return QrStudyScaffold(
          showBack: false,
          child:
              qrLoadingOr(context, _loadError, 'Could not load the lessons:'));
    }
    final ticked = _words.length + _grammar.length;
    return QrStudyScaffold(
      showBack: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text('Which lessons have you studied?', style: qrTitle(t, size: 26)),
          const SizedBox(height: 8),
          Text(
              'The ticked lessons go into your review queue. Nothing counts as '
              'mastered until you answer it over time.',
              style: qrText(t, color: t.inkMuted)),
          const SizedBox(height: 6),
          Text(
              'Untick a lesson to skip it for now. Its items arrive later, a few '
              'new ones a day.',
              style: qrText(t, color: t.inkMuted)),
          const SizedBox(height: 20),
          _group(t, 'Vocabulary lessons', 'word', _wordLessons, _words),
          const SizedBox(height: 18),
          _group(t, 'Grammar lessons', 'grammar', _grammarLessons, _grammar),
          const SizedBox(height: 22),
          Text('$ticked lessons ticked',
              style: qrText(t, size: 12.5, color: t.inkMuted)),
          const SizedBox(height: 10),
          if (_seedError != null) ...[
            Text(_seedError!, style: qrText(t, color: t.clay600)),
            const SizedBox(height: 10),
          ],
          QrLoudButton(label: 'Confirm', onPressed: _busy ? null : _confirm),
        ],
      ),
    );
  }

  Widget _group(QuietRoomTokens t, String title, String key, List<int> lessons,
      Set<int> on) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: qrText(t,
                    size: 13, weight: FontWeight.w600, color: t.sage700)),
          ),
          _allToggle(t, key, lessons, on),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final l in lessons)
              QrPill(
                key: ValueKey('seed-$key-$l'),
                label: '$l',
                on: on.contains(l),
                onTap: _busy
                    ? () {}
                    : () => setState(
                        () => on.contains(l) ? on.remove(l) : on.add(l)),
              ),
          ],
        ),
      ],
    );
  }

  /// Select all, or Clear all once every lesson of the section is ticked. A section with no
  /// lessons reads Select all and ticks nothing.
  Widget _allToggle(
      QuietRoomTokens t, String key, List<int> lessons, Set<int> on) {
    final all = lessons.isNotEmpty && lessons.every(on.contains);
    return TextButton(
      key: ValueKey('seed-$key-all'),
      onPressed: _busy
          ? null
          : () => setState(() => all ? on.clear() : on.addAll(lessons)),
      child: Text(all ? kSeedClearAll : kSeedSelectAll,
          style:
              qrText(t, size: 13, weight: FontWeight.w600, color: t.brand600)),
    );
  }
}
