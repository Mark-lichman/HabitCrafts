// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_open_app_settings/flutter_open_app_settings.dart';

/// Opens the phone's notification settings for the app. A browser has no such settings
/// page, so on the web this asks the browser for notification permission instead
/// (plan 2026-11-19, Task 14). The browser shows its prompt once; after that it answers
/// with the choice already made. A browser with no Notification API, such as iOS Safari
/// outside an installed web app, has nothing to ask, so the row does nothing there.
Future openNotificationSettings() async {
  if (kIsWeb) {
    if (!await FirebaseMessaging.instance.isSupported()) return;
    await FirebaseMessaging.instance.requestPermission();
    return;
  }
  FlutterOpenAppSettings.openAppsSettings(
    settingsCode: SettingsCode.NOTIFICATION,
  );
}
