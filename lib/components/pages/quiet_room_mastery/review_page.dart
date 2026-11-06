// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Review session as a route (plan 2026-11-02, Task 20). [QuietRoomReviewPage] resolves
// today's launch through `onLaunch` (relaunch.dart) and opens [SessionWidget] on the stored
// plan at the stored position, so a Start, a Resume and a deep link all land on the same
// session. `onLaunch` is idempotent within a day: once today's plan is stored it returns that
// plan, so opening this page from Today never builds a second plan or takes a second intake.
//
// A first launch here (the seed has never run) shows the seed confirmation first, as the home
// does. A done day never reopens the session: it shows a quiet done card, so the stored
// position and completion stay as the session left them.
//
// [openReviewSession] is the one way the entry points open it: by route name under the app's
// router, or as a plain page where no router is present (widget tests).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'relaunch.dart';
import 'seed_confirm_widget.dart';
import 'session_widget.dart';

/// The end state of a finished day, on Today and here.
const String kDoneForToday = 'Done for today';
const String kDoneComeBack =
    "Today's session is complete. The next one is ready tomorrow.";

/// Opens the Review session and completes when it closes.
Future<void> openReviewSession(BuildContext context,
    {JpStore? store,
    ItemCatalog? catalog,
    Clock clock = const SystemClock()}) async {
  if (GoRouter.maybeOf(context) != null) {
    await context.pushNamed(QuietRoomReviewPage.routeName);
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) =>
        QuietRoomReviewPage(store: store, catalog: catalog, clock: clock),
  ));
}

/// The loud action of an entry screen: full width, brand fill.
class QrLoudButton extends StatelessWidget {
  const QrLoudButton({super.key, required this.label, required this.onPressed});

  final String label;

  /// Null shows the button disabled.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return SizedBox(
      height: QuietRoomMetrics.targetMin,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: t.brand600,
          disabledBackgroundColor: t.border,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm)),
        ),
        child: Text(label,
            style: qrText(t,
                size: 15.5, weight: FontWeight.w600, color: t.onBrand)),
      ),
    );
  }
}

/// A centered spinner, or the reason a load failed (S4: no silent empty screen).
Widget qrLoadingOr(BuildContext context, Object? error, String failure) {
  final t = QuietRoomTokens.of(context);
  if (error != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(QuietRoomMetrics.space24),
        child: Text('$failure $error',
            textAlign: TextAlign.center, style: qrText(t, color: t.clay600)),
      ),
    );
  }
  return Center(
    child: SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(t.inkSubtle)),
    ),
  );
}

class QuietRoomReviewPage extends StatefulWidget {
  const QuietRoomReviewPage({
    super.key,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
  });

  static String routeName = 'quietRoomReview';
  static String routePath = '/quietRoomReview';

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;

  @override
  State<QuietRoomReviewPage> createState() => _QuietRoomReviewPageState();
}

class _QuietRoomReviewPageState extends State<QuietRoomReviewPage> {
  JpStore? _store;
  ItemCatalog? _catalog;
  Launch? _launch;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final launch = await onLaunch(widget.clock.now(), store, catalog);
      if (mounted) setState(() => _launch = launch);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final launch = _launch;
    if (launch == null) {
      return QrStudyScaffold(
          child: qrLoadingOr(context, _error, 'Could not open the review:'));
    }
    if (launch.decision == LaunchDecision.firstLaunch) {
      return SeedConfirmWidget(
        store: _store,
        catalog: _catalog,
        clock: widget.clock,
        onSeeded: () {
          setState(() => _launch = null);
          _resolve();
        },
      );
    }
    if (launch.decision == LaunchDecision.done) {
      final t = QuietRoomTokens.of(context);
      return QrStudyScaffold(
        child: Padding(
          padding: const EdgeInsets.all(QuietRoomMetrics.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kDoneForToday, style: qrTitle(t, size: 26)),
              const SizedBox(height: QuietRoomMetrics.space8),
              Text(kDoneComeBack, style: qrText(t, color: t.inkMuted)),
            ],
          ),
        ),
      );
    }
    return QrStudyScaffold(
      child: SessionWidget(
        plan: launch.plan!,
        store: _store!,
        clock: widget.clock,
        catalog: _catalog!,
        position: launch.record?.position ?? 0,
      ),
    );
  }
}
