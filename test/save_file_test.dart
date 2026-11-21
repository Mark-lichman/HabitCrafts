// Export on the web downloads the study record through the browser (End state 11, PIN-6).
// Run it in Chrome: `flutter test --platform chrome test/save_file_test.dart`.
//
// The real web picker is registered the way the app registers it (`FilePickerWeb.registerWith`).
// Its saveFile makes a Blob, an object URL and an anchor with `download`, then clicks it. The
// test wraps `URL.createObjectURL` and `HTMLAnchorElement.prototype.click` so it can read the
// blob and the anchor, and so no real download or tab opens. The picker code itself runs as is.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// ignore: implementation_imports
import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_debug_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart';

/// One anchor click the picker made.
class _Click {
  _Click(this.href, this.download, this.target);
  final String href;
  final String download;
  final String target;
}

/// Wraps the browser calls the web picker makes, and undoes the wrap in tear down.
class _BrowserDownloads {
  final clicks = <_Click>[];
  final blobs = <String, JSObject>{};
  final revoked = <String>[];

  void install() {
    final url = globalContext['URL'] as JSObject;
    final proto = (globalContext['HTMLAnchorElement'] as JSObject)['prototype']
        as JSObject;
    final create = url['createObjectURL'] as JSFunction;
    final revoke = url['revokeObjectURL'] as JSFunction;
    final click = proto['click'];

    url['createObjectURL'] = ((JSObject blob) {
      final href = create.callAsFunction(url, blob) as JSString;
      blobs[href.toDart] = blob;
      return href;
    }).toJS;
    url['revokeObjectURL'] = ((JSString href) {
      revoked.add(href.toDart);
      revoke.callAsFunction(url, href);
    }).toJS;
    // No real click: the anchor's href and download are what the browser would act on.
    proto['click'] = ((JSObject anchor) {
      clicks.add(_Click(
        (anchor['href'] as JSString).toDart,
        (anchor['download'] as JSString).toDart,
        (anchor['target'] as JSString).toDart,
      ));
      // The pinned Flutter SDK is past 3.6; the lint reads only the pubspec's lower bound.
      // ignore: sdk_version_since
    }).toJSCaptureThis;

    addTearDown(() {
      url['createObjectURL'] = create;
      url['revokeObjectURL'] = revoke;
      proto['click'] = click;
    });
  }

  /// The text of the blob behind [href]. The picker revokes the URL at once, so this reads the
  /// Blob object kept at create time, never the URL.
  Future<String> textOf(String href) async {
    final blob = blobs[href]!;
    final text =
        await (blob.callMethod<JSPromise<JSString>>('text'.toJS)).toDart;
    return text.toDart;
  }
}

void main() {
  setUp(() => FilePickerWeb.registerWith(webPluginRegistrar));

  group('PickerStudyRecordFiles.save in the browser', () {
    test('downloads the text under the file name and reads as saved', () async {
      final browser = _BrowserDownloads()..install();
      const text = '{"type":"header"}\n{"type":"seed","item":"日本"}\n';

      final saved =
          await const PickerStudyRecordFiles().save('record.jsonl', text);

      expect(saved, isTrue,
          reason:
              'the web picker cannot report a cancel, so a started download is saved');
      final click = browser.clicks.single;
      expect(click.download, 'record.jsonl');
      expect(click.href, startsWith('blob:'));
      expect(await browser.textOf(click.href), text,
          reason: 'the download holds the exact UTF-8 text');
      expect(browser.revoked, [click.href],
          reason: 'the object URL is released after the download starts');
    });
  });

  group('the study record page in the browser', () {
    // An empty catalog: asset loads (rootBundle) never finish under `flutter test --platform
    // chrome`, and Export writes the log whatever the catalog holds.
    final catalog = ItemCatalog.fromDocs({
      'conjugation': {'forms': <String>[], 'verbs': <Map<String, dynamic>>[]}
    }, {});

    testWidgets('Export downloads the whole record as a readable export file',
        (tester) async {
      final browser = _BrowserDownloads()..install();
      final store = JpStoreMemory();
      const itemId = 'word-日本';
      const today = 100;
      final noon = dateOfDay(today).add(const Duration(hours: 12));
      await tester.runAsync(
          () => store.appendSeed(itemId, today + 2, atUtc: noon.toUtc()));

      tester.view.physicalSize = const Size(1200, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // The page's files default to the real picker, the one the app uses.
      await tester.pumpWidget(MaterialApp(
        home: MasteryDebugWidget(
          store: store,
          catalog: catalog,
          clock: FixedClock(noon),
        ),
      ));
      await _settle(tester);

      await tester.tap(find.text('Export'));
      await _settle(tester);

      expect(find.text('Exported 0 attempts and 1 seed.'), findsOneWidget);
      final click = browser.clicks.single;
      final day = dateOfDay(today);
      expect(
          click.download,
          'jp-study-record-${day.year}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}.jsonl');
      final text = (await tester.runAsync(() => browser.textOf(click.href)))!;
      final log = decodeStudyExport(text);
      expect(log.seeds.single.itemId, itemId);
      expect(log.seeds.single.dueDay, today + 2);
    });
  });
}

/// Lets the page's store reads finish: they are real futures, so they need real turns.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}
