// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Topics tab (plan 2026-11-02, Task 23, End state 9): every way to look an idea up and
// practise it now (PIN-1).
//   * One search box over the topic index (topic_index.dart `search`): a use, a pattern, a
//     word, an English meaning, a conjugation form or a counter. While a query is typed, the
//     results replace the browse sets: an item row shows its own state pill and its next
//     review; a topic row shows its counts by state and its roll-up pill. A query with more
//     than kSearchMax hits lists the first kSearchMax and ends with a line that says so.
//   * The browse sets (By use, Verb forms, Verb groups, Counters and tables, Words by lesson,
//     Due today, Shaky, Not yet known) as one row of choices; the chosen set lists its topics.
//   * A topic row opens the topic page (topic_page_widget.dart), where Practice this topic
//     runs the session over its items. An item row opens the item page.
//
// The screen reads one snapshot of the record (`TopicIndex.load`) and reads it again when the
// learner comes back from a topic or an item page, so a practised item shows its new state.

import 'package:flutter/material.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'probe_widgets.dart' show ProbeStatePill;
import 'review_page.dart' show qrLoadingOr;
import 'session_widget.dart' show SessionProbeBuilder;
import 'topic_index.dart';
import 'topic_page_widget.dart';

/// The search box's hint.
const String kTopicsSearchHint =
    'Search a word, a meaning, a pattern, a form or a counter';

/// The results line when a query finds nothing.
const String kNoResultsLine = 'Nothing matches that yet.';

/// The most results the screen lists for one query. Past it, the list ends with
/// [searchCutLine], so a broad query never looks complete.
const int kSearchMax = 60;

/// The last row of a cut list: [total] hits, the first [kSearchMax] shown.
String searchCutLine(int total) =>
    'Showing the first $kSearchMax of $total. Type more to narrow the search.';

class QuietRoomTopicsWidget extends StatefulWidget {
  const QuietRoomTopicsWidget({
    super.key,
    this.store,
    this.catalog,
    this.grammar,
    this.clock = const SystemClock(),
    this.probeBuilder,
    this.showBack = true,
  });

  static String routeName = 'quietRoomTopics';
  static String routePath = '/quietRoomTopics';

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;

  /// Null loads the shipped grammar file.
  final Map<String, dynamic>? grammar;
  final Clock clock;

  /// Null loads the session's standard probe builder for practice.
  final SessionProbeBuilder? probeBuilder;

  /// False when the screen is a tab with no page under it.
  final bool showBack;

  @override
  State<QuietRoomTopicsWidget> createState() => _QuietRoomTopicsWidgetState();
}

class _QuietRoomTopicsWidgetState extends State<QuietRoomTopicsWidget> {
  final TextEditingController _query = TextEditingController();
  TopicIndex? _index;
  Object? _error;
  BrowseSet _set = BrowseSet.byUse;
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final store = widget.store ?? await sharedJpStore();
      final catalog = widget.catalog ?? await ItemCatalog.load();
      final grammar = widget.grammar ?? await JpGrammarData.load();
      final index = await TopicIndex.load(
          store: store,
          catalog: catalog,
          grammar: grammar,
          today: widget.clock.today());
      if (mounted && load == _loads) {
        setState(() {
          _index = index;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && load == _loads) setState(() => _error = e);
    }
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

  Future<void> _openItem(String itemId) async {
    await openItemPage(context, itemId,
        store: widget.store,
        catalog: widget.catalog,
        clock: widget.clock,
        probeBuilder: widget.probeBuilder);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    if (index == null) {
      return QrStudyScaffold(
          showBack: widget.showBack,
          child: qrLoadingOr(context, _error, 'Could not open Topics:'));
    }
    final t = QuietRoomTokens.of(context);
    final query = _query.text;
    final rows = <Widget Function()>[
      () => Text('Topics', style: qrTitle(t, size: 28)),
      () => Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              style: qrText(t, size: 15, color: t.inkStrong),
              decoration: InputDecoration(
                hintText: kTopicsSearchHint,
                hintStyle: qrText(t, size: 14, color: t.inkSubtle),
                prefixIcon: Icon(Icons.search, color: t.inkMuted, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: Icon(Icons.close, color: t.inkMuted, size: 18),
                        onPressed: _query.clear,
                      ),
                filled: true,
                fillColor: t.surface,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(QuietRoomMetrics.radiusSm),
                  borderSide: BorderSide(color: t.borderControl),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(QuietRoomMetrics.radiusSm),
                  borderSide: BorderSide(color: t.borderControl),
                ),
              ),
            ),
          ),
      if (query.trim().isNotEmpty)
        ..._results(t, index, query)
      else
        ..._browse(t, index),
    ];
    return QrStudyScaffold(
      showBack: widget.showBack,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        itemCount: rows.length,
        itemBuilder: (_, i) => rows[i](),
      ),
    );
  }

  List<Widget Function()> _results(
      QuietRoomTokens t, TopicIndex index, String query) {
    final all = index.search(query);
    if (all.isEmpty) {
      return [
        () =>
            Text(kNoResultsLine, style: qrText(t, size: 14, color: t.inkMuted)),
      ];
    }
    return [
      for (final h in all.take(kSearchMax))
        if (h.topic != null)
          () => _topicRow(h.topic!)
        else
          () => TopicListRow(
                key: ValueKey('item-${h.itemId}'),
                title: h.title,
                line: nextReviewLine(index.nextDue(h.itemId!), index.today),
                pill: ProbeStatePill(state: index.stateOf(h.itemId!)),
                onTap: () => _openItem(h.itemId!),
              ),
      if (all.length > kSearchMax)
        () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(searchCutLine(all.length),
                  style: qrText(t, size: 13, color: t.inkMuted)),
            ),
    ];
  }

  List<Widget Function()> _browse(QuietRoomTokens t, TopicIndex index) {
    final topics = index.browse(_set);
    return [
      () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in BrowseSet.values) _setChoice(t, s),
            ],
          ),
      () => const SizedBox(height: 10),
      for (final topic in topics) () => _topicRow(topic),
    ];
  }

  Widget _setChoice(QuietRoomTokens t, BrowseSet s) {
    final on = s == _set;
    return OutlinedButton(
      key: ValueKey('set-${s.name}'),
      onPressed: () => setState(() => _set = s),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        backgroundColor: on ? t.brand600 : t.surface,
        side: BorderSide(color: on ? t.brand600 : t.borderControl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(browseSetLabel(s),
          style: qrText(t,
              size: 13.5,
              weight: FontWeight.w600,
              color: on ? t.onBrand : t.ink)),
    );
  }

  Widget _topicRow(Topic topic) => TopicListRow(
        key: ValueKey('topic-${topic.id}'),
        title: topic.title,
        line: topic.counts.label,
        pill: TopicPill(status: topic.pill),
        onTap: () => _openTopic(topic.id),
      );
}
