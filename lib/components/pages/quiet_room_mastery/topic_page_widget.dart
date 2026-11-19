// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The topic page (plan 2026-11-02, Task 23, End state 9). One `Topic` of the topic index (a
// use, a verb form, a verb group, a table, a lesson's words, or Due today, Shaky or Not yet
// known):
//   * its title, its counts by state ("0 of 3 mastered · 1 learning · 2 new", never a
//     percentage) and its roll-up pill (D16, topic_index.dart `rollUp`);
//   * one loud Practice this topic, which runs a [PracticeSessionWidget] over the topic's
//     items, due first ([practiceOrder]). Each answer goes through the drills' due rule
//     (D23, PIN-14): a due item is a review; any other is early practice, where a clear changes
//     nothing and a wrong counts. Practice never writes the day's session record;
//   * its items, each with its own state pill and next review (PIN-1: the item's own state,
//     never its lesson number). A row opens the item page;
//   * Related topics: the static topics that share the most items with this one.
//
// The page reads one snapshot of the record (`TopicIndex.load`) and reads it again when the
// learner comes back from practice, an item page or a related topic.
//
// [openTopicPage] and [openItemPage] are the one way the Topics screen and this page open a
// page: by route name under the app's router, or as a plain page where no router is present
// or the caller injected its own store (widget tests).
//
// A practice card's "Review the lesson" on a particle that no Mari lesson teaches opens this
// page at the particle (plan 2026-11-06, Task 1, PIN-5): [TopicPageWidget.particleId] puts a
// [ParticleBlock] (the particle and its meaning, never its example or its cloze sentence) at
// the top, on the particle's first topic when no topic is named, and
// [TopicPageWidget.fromCard] shows the "Back to practice" bar. The plain entry is unchanged.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'item_catalog.dart';
import 'item_detail_widget.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'mastery_debug_widget.dart' show dueLabel;
import 'mastery_rule.dart';
import 'probe_widgets.dart' show ProbeStatePill;
import 'review_page.dart' show QrLoudButton, qrLoadingOr;
import 'session_widget.dart' show SessionProbeBuilder;
import 'topic_index.dart';

/// The loud action of the page.
const String kPracticeThisTopic = 'Practice this topic';

/// The heading over the related topics.
const String kRelatedTopics = 'Related topics';

/// The page of a topic with no items (an empty Shaky or Due today).
const String kEmptyTopicLine = 'Nothing here right now.';

/// The next-review text of a row whose item has no schedule and no seed.
const String kNotQueuedShort = 'Not in the queue yet';

/// The most related topics the page lists.
const int kRelatedMax = 8;

/// The learner-facing name of a topic pill.
String topicPillLabel(MasteryStatus s) => switch (s) {
      MasteryStatus.neu => 'New',
      MasteryStatus.learning => 'Learning',
      MasteryStatus.mastered => 'Mastered',
      MasteryStatus.shaky => 'Shaky',
    };

/// The topic of [topicId] in [index]: a static topic, or one of the record's sets (`due`,
/// `shaky`, `notYet`); null when there is none.
Topic? topicOf(TopicIndex index, String topicId) {
  final set = switch (topicId) {
    'due' => BrowseSet.dueToday,
    'shaky' => BrowseSet.shaky,
    'notYet' => BrowseSet.notYetKnown,
    _ => null,
  };
  return set == null ? index.byId(topicId) : index.browse(set).first;
}

/// The order Practice this topic asks [topic]'s items in: the due ones first, soonest due
/// first, then the rest in the topic's own order. Pure.
List<String> practiceOrder(TopicIndex index, Topic topic) {
  final due = <(String, int, int)>[];
  final rest = <String>[];
  for (var i = 0; i < topic.itemIds.length; i++) {
    final id = topic.itemIds[i];
    final day = index.nextDue(id);
    if (day != null && day <= index.today) {
      due.add((id, day, i));
    } else {
      rest.add(id);
    }
  }
  due.sort((a, b) {
    final byDay = a.$2.compareTo(b.$2);
    return byDay != 0 ? byDay : a.$3.compareTo(b.$3);
  });
  return [for (final d in due) d.$1, ...rest];
}

/// The static topics that share items with [topic], most shared first, then in the order
/// first met while walking the topic's items; [topic] itself left out.
List<Topic> relatedTopics(TopicIndex index, Topic topic,
    {int max = kRelatedMax}) {
  final shared = <String, int>{};
  final first = <String, Topic>{};
  for (final id in topic.itemIds) {
    for (final t in index.topicsOf(id)) {
      if (t.id == topic.id) continue;
      shared[t.id] = (shared[t.id] ?? 0) + 1;
      first.putIfAbsent(t.id, () => t);
    }
  }
  final order = first.keys.toList();
  final ids = [...order]..sort((a, b) {
      final by = shared[b]!.compareTo(shared[a]!);
      return by != 0 ? by : order.indexOf(a).compareTo(order.indexOf(b));
    });
  return [for (final id in ids.take(max)) first[id]!];
}

/// The next-review line of a row.
String nextReviewLine(int? due, int today) =>
    due == null ? kNotQueuedShort : 'Next review: ${dueLabel(due, today)}';

/// Whether [context] should open a page by route name: under the app's router, when the
/// caller injected no store of its own.
bool _byRoute(BuildContext context, JpStore? store) =>
    store == null && GoRouter.maybeOf(context) != null;

/// Opens the topic page over [topicId], and completes when it closes.
Future<void> openTopicPage(BuildContext context, String topicId,
    {JpStore? store,
    ItemCatalog? catalog,
    Map<String, dynamic>? grammar,
    Clock clock = const SystemClock(),
    SessionProbeBuilder? probeBuilder}) async {
  if (_byRoute(context, store)) {
    await context.pushNamed(TopicPageWidget.routeName,
        queryParameters: {'topic': topicId});
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => TopicPageWidget(
      topicId: topicId,
      store: store,
      catalog: catalog,
      grammar: grammar,
      clock: clock,
      probeBuilder: probeBuilder,
    ),
  ));
}

/// Opens the item page over [itemId], and completes when it closes.
Future<void> openItemPage(BuildContext context, String itemId,
    {JpStore? store,
    ItemCatalog? catalog,
    Clock clock = const SystemClock(),
    SessionProbeBuilder? probeBuilder}) async {
  if (_byRoute(context, store)) {
    await context.pushNamed(ItemDetailWidget.routeName,
        queryParameters: {'item': itemId});
    return;
  }
  await openItemDetail(context, itemId,
      store: store, catalog: catalog, clock: clock, probeBuilder: probeBuilder);
}

/// The particle [id] of the grammar file [grammar] (`grammar['particles']`), or null.
Map<String, dynamic>? particleOf(Map<String, dynamic> grammar, String id) {
  for (final p in (grammar['particles'] as List? ?? const [])) {
    final m = p as Map<String, dynamic>;
    if (m['id'] == id) return m;
  }
  return null;
}

/// A particle's lesson view: the particle as its form and its meaning (PIN-5). It never shows
/// the particle's example sentence, its English or its cloze sentence, so the view gives away
/// no answer to the particle's card.
class ParticleBlock extends StatelessWidget {
  const ParticleBlock({super.key, required this.particle});

  /// The particle's entry in `grammar['particles']`.
  final Map<String, dynamic> particle;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final meaning = particle['meaning'] as String? ?? '';
    return Container(
      key: const ValueKey('particle-block'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PARTICLE',
              style: qrText(t,
                      size: 11, weight: FontWeight.w600, color: t.inkSubtle)
                  .copyWith(letterSpacing: 11 * 0.06)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: t.surfaceTinted,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(particle['expression'] as String? ?? '',
                style: qrText(t,
                    size: 16, weight: FontWeight.w600, color: t.brand700)),
          ),
          if (meaning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meaning, style: qrText(t, size: 14.5, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

/// A topic's roll-up pill: New, Learning, Mastered or Shaky.
class TopicPill extends StatelessWidget {
  const TopicPill({super.key, required this.status});

  final MasteryStatus status;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final (fill, ink) = switch (status) {
      MasteryStatus.neu => (t.surface, t.inkMuted),
      MasteryStatus.learning => (t.surfaceTinted, t.brand600),
      MasteryStatus.mastered => (t.sage100, t.sage700),
      MasteryStatus.shaky => (t.amberSurface, t.amber700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(topicPillLabel(status),
          style: qrText(t, size: 12.5, weight: FontWeight.w600, color: ink)),
    );
  }
}

/// One row of a list: a title, a line under it and a pill, the whole row a tap target.
class TopicListRow extends StatelessWidget {
  const TopicListRow({
    super.key,
    required this.title,
    required this.line,
    required this.pill,
    required this.onTap,
  });

  final String title;
  final String line;
  final Widget pill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints:
            const BoxConstraints(minHeight: QuietRoomMetrics.targetMin),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: qrText(t,
                        size: 16, weight: FontWeight.w600, color: t.inkStrong)),
                const SizedBox(height: 2),
                Text(line, style: qrText(t, size: 13, color: t.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          pill,
        ]),
      ),
    );
  }
}

class TopicPageWidget extends StatefulWidget {
  const TopicPageWidget({
    super.key,
    required this.topicId,
    this.particleId,
    this.fromCard = false,
    this.store,
    this.catalog,
    this.grammar,
    this.clock = const SystemClock(),
    this.probeBuilder,
  });

  static String routeName = 'quietRoomTopic';
  static String routePath = '/quietRoomTopic';

  /// A topic id of the index (`use.reason`, `form.te`, `due`). Empty with [particleId] opens
  /// the particle's first topic.
  final String topicId;

  /// Opens at this particle (`mari.particle.1`): its [ParticleBlock] heads the page.
  final String? particleId;

  /// A practice card opened the page: the "Back to practice" bar shows.
  final bool fromCard;

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;

  /// Null loads the shipped grammar file.
  final Map<String, dynamic>? grammar;
  final Clock clock;

  /// Null loads the session's standard probe builder for practice.
  final SessionProbeBuilder? probeBuilder;

  @override
  State<TopicPageWidget> createState() => _TopicPageWidgetState();
}

class _TopicPageWidgetState extends State<TopicPageWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  TopicIndex? _index;
  Topic? _topic;
  Map<String, dynamic>? _particle;
  List<Topic> _related = const [];
  Object? _error;

  /// Bumped per load, so a load for a topic no longer shown is dropped.
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TopicPageWidget old) {
    super.didUpdateWidget(old);
    if (old.topicId != widget.topicId ||
        old.particleId != widget.particleId ||
        old.store != widget.store ||
        old.catalog != widget.catalog) {
      _store = null;
      _catalog = null;
      _index = null;
      _topic = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final grammar = widget.grammar ?? await JpGrammarData.load();
      final index = await TopicIndex.load(
          store: store,
          catalog: catalog,
          grammar: grammar,
          today: widget.clock.today());
      final particleId = widget.particleId;
      final particle =
          particleId == null ? null : particleOf(grammar, particleId);
      if (particleId != null && particle == null) {
        throw StateError('no particle $particleId');
      }
      final topic = widget.topicId.isEmpty && particleId != null
          ? index.topicsOf(particleId).firstOrNull
          : topicOf(index, widget.topicId);
      if (topic == null) {
        throw StateError('no topic ${widget.topicId}');
      }
      final related = relatedTopics(index, topic);
      if (mounted && load == _loads) {
        setState(() {
          _index = index;
          _topic = topic;
          _particle = particle;
          _related = related;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && load == _loads) setState(() => _error = e);
    }
  }

  Future<void> _practice() async {
    final index = _index, topic = _topic;
    if (index == null || topic == null) return;
    final catalog = _catalog!;
    final items = [
      for (final id in practiceOrder(index, topic)) catalog.byId(id)!
    ];
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => QrStudyScaffold(
        child: PracticeSessionWidget(
          items: items,
          store: _store!,
          catalog: catalog,
          clock: widget.clock,
          probeBuilder: widget.probeBuilder,
        ),
      ),
    ));
    if (mounted) await _load();
  }

  Future<void> _openItem(String itemId) async {
    await openItemPage(context, itemId,
        store: widget.store,
        catalog: widget.catalog,
        clock: widget.clock,
        probeBuilder: widget.probeBuilder);
    if (mounted) await _load();
  }

  Future<void> _openTopic(String topicId) async {
    await openTopicPage(context, topicId,
        store: widget.store,
        catalog: widget.catalog,
        grammar: widget.grammar,
        clock: widget.clock,
        probeBuilder: widget.probeBuilder);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final index = _index, topic = _topic;
    if (index == null || topic == null) {
      return QrStudyScaffold(
          fromCard: widget.fromCard,
          child: qrLoadingOr(context, _error, 'Could not open the topic:'));
    }
    final particle = _particle;
    final t = QuietRoomTokens.of(context);
    final catalog = _catalog!;
    final canPractice = topic.itemIds
        .any((id) => catalog.byId(id)?.scoredProbes.isNotEmpty ?? false);
    final rows = <Widget Function()>[
      if (particle != null) () => ParticleBlock(particle: particle),
      () => Text(topic.title, style: qrTitle(t, size: 28)),
      if (topic.subtitle != null)
        () => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(topic.subtitle!,
                  style: qrText(t, size: 13.5, color: t.inkMuted)),
            ),
      () => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              TopicPill(status: topic.pill),
              const SizedBox(width: 10),
              Expanded(
                child: Text(topic.counts.label,
                    style: qrText(t, size: 14, color: t.ink)),
              ),
            ]),
          ),
      () => Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: QrLoudButton(
                label: kPracticeThisTopic,
                onPressed: canPractice ? _practice : null),
          ),
      if (topic.itemIds.isEmpty)
        () => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(kEmptyTopicLine,
                  style: qrText(t, size: 14, color: t.inkMuted)),
            ),
      for (final id in topic.itemIds)
        () => TopicListRow(
              key: ValueKey('item-$id'),
              title: catalog.byId(id)!.title,
              line: nextReviewLine(index.nextDue(id), index.today),
              pill: ProbeStatePill(state: index.stateOf(id)),
              onTap: () => _openItem(id),
            ),
      if (_related.isNotEmpty)
        () => Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Text(kRelatedTopics,
                  style: qrText(t,
                      size: 13, weight: FontWeight.w600, color: t.inkStrong)),
            ),
      for (final r in _related)
        () => TopicListRow(
              key: ValueKey('related-${r.id}'),
              title: r.title,
              line: r.counts.label,
              pill: TopicPill(status: r.pill),
              onTap: () => _openTopic(r.id),
            ),
    ];
    return QrStudyScaffold(
      fromCard: widget.fromCard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        itemCount: rows.length,
        itemBuilder: (_, i) => rows[i](),
      ),
    );
  }
}
