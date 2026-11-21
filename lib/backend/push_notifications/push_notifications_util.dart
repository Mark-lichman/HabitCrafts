import 'package:cloud_firestore/cloud_firestore.dart';

import 'serialization_util.dart';
import '../../auth/firebase_auth/auth_util.dart';
import '../cloud_functions/cloud_functions.dart';

import 'package:flutter/foundation.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

export 'push_notifications_handler.dart';
export 'serialization_util.dart';

const kUserPushNotificationsCollectionName = 'ff_user_push_notifications';

class UserTokenInfo {
  const UserTokenInfo(this.userPath, this.fcmToken);
  final String userPath;
  final String fcmToken;
}

/// The FCM web push key (the VAPID public key from the Firebase console).
/// It comes from build config, `--dart-define=FCM_WEB_VAPID_KEY=...`, and is
/// never committed. A build without it skips web push (plan 2026-11-19,
/// Task 11).
const kFcmWebVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

/// The `deviceType` that `addFcmToken` stores as `device_type`.
String fcmDeviceType({bool isWeb = kIsWeb, TargetPlatform? platform}) {
  if (isWeb) {
    return 'Web';
  }
  return (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
      ? 'iOS'
      : 'Android';
}

/// The browser and both phone platforms get a token. The browser needs the
/// web push key too. On the web the token request also registers
/// `web/firebase-messaging-sw.js`, which shows pushes that arrive while the
/// tab is in the background.
Stream<UserTokenInfo> getFcmTokenStream(
  String userPath, {
  FirebaseMessaging? messaging,
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
  String vapidKey = kFcmWebVapidKey,
}) {
  final target = platform ?? defaultTargetPlatform;
  final shouldGetToken = isWeb
      ? vapidKey.isNotEmpty
      : (target == TargetPlatform.iOS || target == TargetPlatform.android);
  FirebaseMessaging client() => messaging ?? FirebaseMessaging.instance;
  Future<String?> requestToken() => client().requestPermission().then(
        (settings) =>
            settings.authorizationStatus == AuthorizationStatus.authorized
                ? client().getToken(vapidKey: isWeb ? vapidKey : null)
                : null,
      );
  return Stream.value(shouldGetToken)
      .where((shouldGetToken) => shouldGetToken)
      .asyncMap<String?>(
        // A browser can reject the permission or service worker call, for
        // example when notifications are blocked. Web push then stays off
        // and the app keeps running. The log names the cause for the
        // in-browser check.
        (_) => isWeb
            ? requestToken().catchError((Object e) {
                debugPrint('Web push token skipped: $e');
                return null;
              })
            : requestToken(),
      )
      .switchMap(
          (fcmToken) => Stream.value(fcmToken).merge(client().onTokenRefresh))
      .where((fcmToken) => fcmToken != null && fcmToken.isNotEmpty)
      .map((token) => UserTokenInfo(userPath, token!));
}

/// The `addFcmToken` call data for one token.
Map<String, String> addFcmTokenData(
  UserTokenInfo userTokenInfo, {
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) =>
    {
      'userDocPath': userTokenInfo.userPath,
      'fcmToken': userTokenInfo.fcmToken,
      'deviceType': fcmDeviceType(isWeb: isWeb, platform: platform),
    };

final fcmTokenUserStream = authenticatedUserStream
    .where((user) => user != null)
    .map((user) => user!.reference.path)
    .distinct()
    .switchMap(getFcmTokenStream)
    .map(
      (userTokenInfo) => makeCloudCall(
        'addFcmToken',
        addFcmTokenData(userTokenInfo),
      ),
    );

void triggerPushNotification({
  required String? notificationTitle,
  required String? notificationText,
  String? notificationImageUrl,
  DateTime? scheduledTime,
  String? notificationSound,
  required List<DocumentReference> userRefs,
  required String initialPageName,
  required Map<String, dynamic> parameterData,
}) {
  if ((notificationTitle ?? '').isEmpty || (notificationText ?? '').isEmpty) {
    return;
  }
  final serializedParameterData = serializeParameterData(parameterData);
  final pushNotificationData = {
    'notification_title': notificationTitle,
    'notification_text': notificationText,
    if (notificationImageUrl != null)
      'notification_image_url': notificationImageUrl,
    if (scheduledTime != null) 'scheduled_time': scheduledTime,
    if (notificationSound != null) 'notification_sound': notificationSound,
    'user_refs': userRefs.map((u) => u.path).join(','),
    'initial_page_name': initialPageName,
    'parameter_data': serializedParameterData,
    'sender': currentUserReference,
    'timestamp': DateTime.now(),
  };
  FirebaseFirestore.instance
      .collection(kUserPushNotificationsCollectionName)
      .doc()
      .set(pushNotificationData);
}
