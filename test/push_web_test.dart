// Web push and web reminders (plan 2026-11-19, Task 11, PIN-6, A2).
//
// The browser registers its FCM token through the same `addFcmToken` call
// as the phone, tagged `Web`, and asks for it with the web push key from
// build config. Firebase Messaging is faked, so the same file runs in Chrome
// (`--platform chrome`) and on the VM. The service worker check reads
// `web/firebase-messaging-sw.js`, so it runs on the VM only.
import 'dart:io' show File;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/backend/push_notifications/push_notifications_util.dart';

class _FakeSettings implements NotificationSettings {
  _FakeSettings(this.authorizationStatus);

  @override
  final AuthorizationStatus authorizationStatus;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the permission and token calls. Any other call throws.
class _FakeMessaging implements FirebaseMessaging {
  _FakeMessaging({
    this.status = AuthorizationStatus.authorized,
    this.permissionError,
  });

  static const token = 'web-token-1';
  final AuthorizationStatus status;
  final Object? permissionError;
  final calls = <String>[];
  String? tokenVapidKey;

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    calls.add('requestPermission');
    if (permissionError != null) throw permissionError!;
    return _FakeSettings(status);
  }

  @override
  Future<String?> getToken({String? vapidKey}) async {
    calls.add('getToken');
    tokenVapidKey = vapidKey;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const userPath = 'users/u1';

  group('fcmDeviceType', () {
    test('a browser registers as Web', () {
      expect(fcmDeviceType(isWeb: true), 'Web');
    });

    test('the phone keeps its iOS and Android tags', () {
      expect(
        fcmDeviceType(isWeb: false, platform: TargetPlatform.iOS),
        'iOS',
      );
      expect(
        fcmDeviceType(isWeb: false, platform: TargetPlatform.android),
        'Android',
      );
    });
  });

  group('getFcmTokenStream on the web', () {
    test('asks for the token with the configured web push key', () async {
      final messaging = _FakeMessaging();
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: true,
        vapidKey: 'config-key',
      ).toList();

      expect(messaging.calls, ['requestPermission', 'getToken']);
      expect(messaging.tokenVapidKey, 'config-key');
      expect(infos, hasLength(1));
      expect(infos.single.userPath, userPath);
      expect(infos.single.fcmToken, 'web-token-1');
    });

    test('registers nothing when no web push key is configured', () async {
      final messaging = _FakeMessaging();
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: true,
        vapidKey: '',
      ).toList();

      expect(infos, isEmpty);
      expect(messaging.calls, isEmpty);
    });

    test('registers nothing when the browser denies notifications', () async {
      final messaging = _FakeMessaging(status: AuthorizationStatus.denied);
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: true,
        vapidKey: 'config-key',
      ).toList();

      expect(infos, isEmpty);
      expect(messaging.calls, ['requestPermission']);
    });

    test('a browser that rejects the permission call raises no error',
        () async {
      final messaging = _FakeMessaging(
        permissionError: StateError('notifications blocked'),
      );
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: true,
        vapidKey: 'config-key',
      ).toList();

      expect(infos, isEmpty);
    });

    test('a rejected token call logs its cause', () async {
      final logs = <String?>[];
      final saved = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      addTearDown(() => debugPrint = saved);
      final messaging = _FakeMessaging(
        permissionError: StateError('notifications blocked'),
      );
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: true,
        vapidKey: 'config-key',
      ).toList();

      expect(infos, isEmpty);
      expect(logs, hasLength(1));
      expect(logs.single, startsWith('Web push token skipped: '));
      expect(logs.single, contains('notifications blocked'));
    });
  });

  group('getFcmTokenStream on the phone', () {
    test('an Android phone gets a token without a web push key', () async {
      final messaging = _FakeMessaging();
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: false,
        platform: TargetPlatform.android,
        vapidKey: 'config-key',
      ).toList();

      expect(messaging.calls, ['requestPermission', 'getToken']);
      expect(messaging.tokenVapidKey, isNull);
      expect(infos, hasLength(1));
      expect(infos.single.userPath, userPath);
    });

    test('an iOS phone gets a token without a web push key', () async {
      final messaging = _FakeMessaging();
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: false,
        platform: TargetPlatform.iOS,
        vapidKey: 'config-key',
      ).toList();

      expect(messaging.calls, ['requestPermission', 'getToken']);
      expect(messaging.tokenVapidKey, isNull);
      expect(infos, hasLength(1));
    });

    test('a desktop platform asks for no token', () async {
      final messaging = _FakeMessaging();
      final infos = await getFcmTokenStream(
        userPath,
        messaging: messaging,
        isWeb: false,
        platform: TargetPlatform.macOS,
        vapidKey: 'config-key',
      ).toList();

      expect(infos, isEmpty);
      expect(messaging.calls, isEmpty);
    });
  });

  group('addFcmTokenData', () {
    test('a web token reaches addFcmToken tagged Web', () {
      final data = addFcmTokenData(
        const UserTokenInfo(userPath, 'web-token-1'),
        isWeb: true,
      );
      expect(data, {
        'userDocPath': userPath,
        'fcmToken': 'web-token-1',
        'deviceType': 'Web',
      });
    });

    test('a phone token keeps its platform tag', () {
      final data = addFcmTokenData(
        const UserTokenInfo(userPath, 'ios-token'),
        isWeb: false,
        platform: TargetPlatform.iOS,
      );
      expect(data['deviceType'], 'iOS');
    });
  });

  test('the web push key is not committed in the app', () {
    // The key comes from `--dart-define=FCM_WEB_VAPID_KEY=...`, so a test
    // build without the define carries an empty key.
    expect(kFcmWebVapidKey, isEmpty);
  });

  test(
    'the messaging service worker shows background pushes',
    () {
      final sw = File('web/firebase-messaging-sw.js').readAsStringSync();
      expect(sw, contains('firebase-messaging-compat.js'));
      expect(sw, contains('firebase.messaging()'));
      expect(sw, contains('onBackgroundMessage'));
      // Same web app as lib/backend/firebase/firebase_config.dart.
      expect(sw, contains('messagingSenderId: "68894759253"'));
      expect(sw, contains('appId: "1:68894759253:web:8ac60bbb0abb52694bf7dc"'));
      expect(sw, isNot(contains('vapidKey')));
    },
    skip: kIsWeb ? 'reads web/ from disk, so it runs on the VM' : false,
  );
}
