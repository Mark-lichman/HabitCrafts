// Widget tests for the devices page (plan 2026-11-19, Task 7, End state 9, D8).
//
// The page lists each device that synced (`users/{uid}/devices`, read through `JpRemote`) with
// its plain name and its last sync time, newest sync first. It says so plainly when no device
// synced yet, when the remote cannot be reached, and when nobody is signed in. The app router
// registers it by name, so the profile page can open it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/auth/base_auth_user_provider.dart';
import 'package:habit_craft/components/pages/devices_page/devices_page_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_remote.dart';
import 'package:habit_craft/flutter_flow/nav/nav.dart';

import 'jp_screen_harness.dart';

/// A remote that returns its devices in the order given, so the page's own order shows.
class _ListedRemote extends JpRemoteMemory {
  _ListedRemote(this.listed);

  final List<JpDevice> listed;

  @override
  Future<List<JpDevice>> devices() async => listed;
}

/// An auth user with a fixed uid and sign-in state. An anonymous user has a uid but is not
/// logged in, so the page must not open its remote.
class _AuthUser extends BaseAuthUser {
  _AuthUser({required this.uid, required this.loggedIn});

  @override
  final String uid;
  @override
  final bool loggedIn;
  @override
  bool get emailVerified => false;
  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: uid);
  @override
  Future? delete() => null;
  @override
  Future? updateEmail(String email) => null;
  @override
  Future? updatePassword(String newPassword) => null;
  @override
  Future? sendEmailVerification() => null;
}

/// [hour]:00 local time on 2026-11-20, as UTC, so a label reads the same in every time zone.
DateTime localAt(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 20, hour, minute).toUtc();

void main() {
  setUpAll(holdHttpRequests);

  group('deviceLastSyncLabel', () {
    test('reads the local time of the last sync', () {
      expect(deviceLastSyncLabel(localAt(14, 5)),
          'Last synced 20 Nov 2026, 14:05');
    });
  });

  group('devicesNewestFirst', () {
    test('orders by last sync time, the newest first, a tie by device id', () {
      final a =
          JpDevice(deviceId: 'a', name: 'Pixel 8', lastSyncUtc: localAt(9));
      final b =
          JpDevice(deviceId: 'b', name: 'Chrome', lastSyncUtc: localAt(12));
      final c = JpDevice(deviceId: 'c', name: 'Edge', lastSyncUtc: localAt(9));
      expect(devicesNewestFirst([a, c, b]).map((d) => d.deviceId),
          ['b', 'a', 'c']);
    });
  });

  group('DevicesPageWidget', () {
    testWidgets(
        'lists each synced device with its name and last sync time, '
        'newest first', (tester) async {
      final remote = _ListedRemote([
        JpDevice(deviceId: 'phone', name: 'Pixel 8', lastSyncUtc: localAt(8)),
        JpDevice(deviceId: 'web', name: 'Chrome', lastSyncUtc: localAt(17, 30)),
      ]);
      await pumpStudyScreen(tester, DevicesPageWidget(remote: remote));

      expect(find.text(kDevicesTitle), findsOneWidget);
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('Chrome'), findsOneWidget);
      expect(find.text('Last synced 20 Nov 2026, 08:00'), findsOneWidget);
      expect(find.text('Last synced 20 Nov 2026, 17:30'), findsOneWidget);
      final chrome =
          tester.getTopLeft(find.byKey(const ValueKey('device-web')));
      final pixel =
          tester.getTopLeft(find.byKey(const ValueKey('device-phone')));
      expect(chrome.dy, lessThan(pixel.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists the devices a sync wrote to the remote', (tester) async {
      final remote = JpRemoteMemory();
      await remote.putDevice('phone', name: 'Pixel 8', lastSyncUtc: localAt(7));
      await remote.putDevice('web', name: 'Chrome', lastSyncUtc: localAt(10));
      await remote.putDevice('phone',
          name: 'Pixel 8', lastSyncUtc: localAt(11));
      await pumpStudyScreen(tester, DevicesPageWidget(remote: remote));

      expect(find.byKey(const ValueKey('device-phone')), findsOneWidget);
      expect(find.byKey(const ValueKey('device-web')), findsOneWidget);
      expect(find.text('Last synced 20 Nov 2026, 11:00'), findsOneWidget);
      expect(find.text('Last synced 20 Nov 2026, 07:00'), findsNothing);
      final pixel =
          tester.getTopLeft(find.byKey(const ValueKey('device-phone')));
      final chrome =
          tester.getTopLeft(find.byKey(const ValueKey('device-web')));
      expect(pixel.dy, lessThan(chrome.dy));
    });

    testWidgets('says so when no device synced yet', (tester) async {
      await pumpStudyScreen(
          tester, DevicesPageWidget(remote: JpRemoteMemory()));
      expect(find.text(kDevicesEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when the remote cannot be reached', (tester) async {
      final remote = JpRemoteMemory()..online = false;
      await pumpStudyScreen(tester, DevicesPageWidget(remote: remote));
      expect(find.text(kDevicesOffline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('asks to sign in when nobody is signed in', (tester) async {
      await pumpStudyScreen(tester, const DevicesPageWidget());
      expect(find.text(kDevicesSignedOut), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('asks to sign in when the user is anonymous', (tester) async {
      currentUser = _AuthUser(uid: 'anon-uid', loggedIn: false);
      addTearDown(() => currentUser = null);
      await pumpStudyScreen(tester, const DevicesPageWidget());
      expect(find.text(kDevicesSignedOut), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('asks to sign in when the signed-in user has an empty uid',
        (tester) async {
      currentUser = _AuthUser(uid: '', loggedIn: true);
      addTearDown(() => currentUser = null);
      await pumpStudyScreen(tester, const DevicesPageWidget());
      expect(find.text(kDevicesSignedOut), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('the app router registers the page by name', () {
    expect(DevicesPageWidget.routeName, 'DevicesPage');
    final router = createRouter(AppStateNotifier.instance);
    addTearDown(router.dispose);
    expect(router.namedLocation(DevicesPageWidget.routeName),
        DevicesPageWidget.routePath);
  });
}
