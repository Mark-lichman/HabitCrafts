// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// Discuss with Mari (plan 2026-11-06, Task 4, D6, PIN-6). Mark's own reminder list of the items
// he wants to raise with Mari. Mari never needs the app: the list is Mark's, read on his phone.
//
//   * [DiscussToggle]: the quiet "Discuss with Mari" toggle on each session card
//     (session_widget.dart, item_detail_widget.dart's practice cards) and on the item page. A
//     tap sets the item's mark (`JpStore.setDiscuss`); a tap on a marked item clears it.
//   * [DiscussListWidget]: the list, reached from Today's quiet links. Each row names its item
//     and opens the item page; "Discussed" clears the mark once the item was raised.
//
// A mark is never an attempt (jp_store.dart): setting or clearing one writes no grade, moves no
// schedule and no mastery state, and a card answered after a mark is graded as if it had none.

import 'package:flutter/material.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'item_catalog.dart';
import 'item_detail_widget.dart' show openItemDetail;
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'review_page.dart' show qrLoadingOr;

/// The toggle's label, the list's title and Today's quiet link.
const String kDiscussWithMari = 'Discuss with Mari';

/// The toggle's label on a marked item.
const String kDiscussMarked = 'Marked to discuss with Mari';

/// The action that clears a row once the item was raised.
const String kDiscussed = 'Discussed';

/// The list with no mark in it.
const String kDiscussEmpty =
    'Nothing to discuss yet. Mark a card with "Discuss with Mari" to add it here.';

/// Today's quiet link: the plain label, with the count when the list holds any.
String discussLinkLabel(int count) =>
    count > 0 ? '$kDiscussWithMari · $count' : kDiscussWithMari;

/// The quiet "Discuss with Mari" toggle for [itemId]. Reads the item's mark from [store] and
/// sets or clears it on a tap. Writes nothing else (PIN-6).
class DiscussToggle extends StatefulWidget {
  const DiscussToggle({
    super.key,
    required this.itemId,
    this.store,
    this.clock = const SystemClock(),
  });

  final String itemId;

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;
  final Clock clock;

  @override
  State<DiscussToggle> createState() => _DiscussToggleState();
}

class _DiscussToggleState extends State<DiscussToggle> {
  bool? _marked;
  bool _busy = false;

  /// Bumped per load, so a read for an item no longer shown is dropped.
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiscussToggle old) {
    super.didUpdateWidget(old);
    if (old.itemId != widget.itemId || old.store != widget.store) {
      _marked = null;
      _load();
    }
  }

  Future<JpStore> get _store async => widget.store ?? await sharedJpStore();

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final mark = await (await _store).discuss(widget.itemId);
      if (mounted && load == _loads) setState(() => _marked = mark != null);
    } catch (e, s) {
      _report(e, s, 'while reading the Discuss mark of ${widget.itemId}');
    }
  }

  Future<void> _toggle() async {
    final marked = _marked;
    if (marked == null || _busy) return;
    setState(() {
      _busy = true;
      _marked = !marked;
    });
    try {
      final store = await _store;
      if (marked) {
        await store.clearDiscuss(widget.itemId);
      } else {
        await store.setDiscuss(widget.itemId, atUtc: widget.clock.now());
      }
    } catch (e, s) {
      // The write failed, so the toggle shows the mark the store still holds.
      if (mounted) setState(() => _marked = marked);
      _report(e, s, 'while saving the Discuss mark of ${widget.itemId}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(Object e, StackTrace s, String what) =>
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room discuss',
          context: ErrorDescription(what)));

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final marked = _marked ?? false;
    final color = marked ? t.sage700 : t.inkMuted;
    // Its own Material, so the ink has a sheet under a host that holds none.
    return Semantics(
      button: true,
      toggled: marked,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('discuss-toggle-${widget.itemId}'),
          onTap: _marked == null ? null : _toggle,
          borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: QuietRoomMetrics.targetMin),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(marked ? Icons.bookmark : Icons.bookmark_border,
                    size: 18, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(marked ? kDiscussMarked : kDiscussWithMari,
                      style: qrText(t,
                          size: 13.5, weight: FontWeight.w600, color: color)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The marks in list order: the oldest mark first, so the list reads in the order Mark met the
/// items; a tie by item id. Pure.
List<DiscussMark> discussOrder(Iterable<DiscussMark> marks) => marks.toList()
  ..sort((a, b) {
    final at = a.atUtc.compareTo(b.atUtc);
    return at != 0 ? at : a.itemId.compareTo(b.itemId);
  });

/// The "Discuss with Mari" list, reached from Today's quiet links.
class DiscussListWidget extends StatefulWidget {
  const DiscussListWidget({
    super.key,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
  });

  static String routeName = 'quietRoomDiscuss';
  static String routePath = '/quietRoomDiscuss';

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;

  @override
  State<DiscussListWidget> createState() => _DiscussListWidgetState();
}

class _DiscussListWidgetState extends State<DiscussListWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  List<DiscussMark>? _marks;
  Object? _error;
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final marks = discussOrder((await store.discussMarks()).values);
      if (mounted && load == _loads) setState(() => _marks = marks);
    } catch (e) {
      if (mounted && load == _loads) setState(() => _error = e);
    }
  }

  /// Opens the item page; its toggle may clear the mark, so the list reads again on return.
  Future<void> _open(String itemId) async {
    await openItemDetail(context, itemId,
        store: _store, catalog: _catalog, clock: widget.clock);
    if (mounted) await _load();
  }

  /// Clears the mark; a refused write goes to [FlutterError.reportError], as the toggle's
  /// does, and the row stays, since the store still holds the mark.
  Future<void> _discussed(String itemId) async {
    try {
      await _store!.clearDiscuss(itemId);
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'quiet room discuss',
          context:
              ErrorDescription('while clearing the Discuss mark of $itemId')));
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final marks = _marks;
    if (marks == null) {
      return QrStudyScaffold(
          child: qrLoadingOr(context, _error, 'Could not open the list:'));
    }
    final t = QuietRoomTokens.of(context);
    return QrStudyScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Text(kDiscussWithMari, style: qrTitle(t, size: 28)),
          const SizedBox(height: 12),
          if (marks.isEmpty)
            Text(kDiscussEmpty, style: qrText(t, size: 14, color: t.inkMuted)),
          for (final m in marks) _row(t, m),
        ],
      ),
    );
  }

  Widget _row(QuietRoomTokens t, DiscussMark m) {
    final item = _catalog?.byId(m.itemId);
    return Padding(
      key: ValueKey('discuss-row-${m.itemId}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: QrCard(
        onTap: item == null ? null : () => _open(m.itemId),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item?.title ?? m.itemId,
                  style: qrText(t,
                      size: 15.5, weight: FontWeight.w600, color: t.inkStrong)),
              if (item?.lesson != null)
                Text('第${item!.lesson}課',
                    style: qrText(t, size: 12.5, color: t.inkMuted)),
              if (m.note != null) ...[
                const SizedBox(height: 4),
                Text(m.note!, style: qrText(t, size: 13.5, color: t.ink)),
              ],
            ]),
          ),
          TextButton(
            key: ValueKey('discussed-${m.itemId}'),
            onPressed: () => _discussed(m.itemId),
            child: Text(kDiscussed,
                style: qrText(t,
                    size: 13, weight: FontWeight.w600, color: t.brand600)),
          ),
        ]),
      ),
    );
  }
}
