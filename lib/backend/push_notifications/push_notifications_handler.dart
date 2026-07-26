import 'dart:async';
import 'dart:convert';

import 'serialization_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../index.dart';
import '../../main.dart';

final _handledMessageIds = <String?>{};

class PushNotificationsHandler extends StatefulWidget {
  const PushNotificationsHandler({Key? key, required this.child})
      : super(key: key);

  final Widget child;

  @override
  _PushNotificationsHandlerState createState() =>
      _PushNotificationsHandlerState();
}

class _PushNotificationsHandlerState extends State<PushNotificationsHandler> {
  bool _loading = false;

  Future handleOpenedPushNotification() async {
    if (isWeb) {
      return;
    }

    final notification = await FirebaseMessaging.instance.getInitialMessage();
    if (notification != null) {
      await _handlePushNotification(notification);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushNotification);
  }

  Future _handlePushNotification(RemoteMessage message) async {
    if (_handledMessageIds.contains(message.messageId)) {
      return;
    }
    _handledMessageIds.add(message.messageId);

    safeSetState(() => _loading = true);
    try {
      final initialPageName = message.data['initialPageName'] as String;
      final initialParameterData = getInitialParameterData(message.data);
      final parametersBuilder = parametersBuilderMap[initialPageName];
      if (parametersBuilder != null) {
        final parameterData = await parametersBuilder(initialParameterData);
        if (mounted) {
          context.pushNamed(
            initialPageName,
            pathParameters: parameterData.pathParameters,
            extra: parameterData.extra,
          );
        } else {
          appNavigatorKey.currentContext?.pushNamed(
            initialPageName,
            pathParameters: parameterData.pathParameters,
            extra: parameterData.extra,
          );
        }
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      handleOpenedPushNotification();
    });
  }

  @override
  Widget build(BuildContext context) => _loading
      ? Container(
          color: FlutterFlowTheme.of(context).tertiary,
          child: Image.asset(
            'assets/images/Habit_Craft_Logo_File-06.png',
            fit: BoxFit.fitWidth,
          ),
        )
      : widget.child;
}

class ParameterData {
  const ParameterData(
      {this.requiredParams = const {}, this.allParams = const {}});
  final Map<String, String?> requiredParams;
  final Map<String, dynamic> allParams;

  Map<String, String> get pathParameters => Map.fromEntries(
        requiredParams.entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
  Map<String, dynamic> get extra => Map.fromEntries(
        allParams.entries.where((e) => e.value != null),
      );

  static Future<ParameterData> Function(Map<String, dynamic>) none() =>
      (data) async => ParameterData();
}

final parametersBuilderMap =
    <String, Future<ParameterData> Function(Map<String, dynamic>)>{
  'initialPage': ParameterData.none(),
  'forgotPassword': ParameterData.none(),
  'onboarding': ParameterData.none(),
  'homePage': ParameterData.none(),
  'loginPage': ParameterData.none(),
  'signupPage': ParameterData.none(),
  'groupsPage': (data) async => ParameterData(
        allParams: {
          'groupFromPush':
              getParameter<DocumentReference>(data, 'groupFromPush'),
        },
      ),
  'libraryPage': ParameterData.none(),
  'libraryDetailPage': (data) async => ParameterData(
        allParams: {
          'articleRef': getParameter<DocumentReference>(data, 'articleRef'),
        },
      ),
  'profilePage': ParameterData.none(),
  'progressPage': ParameterData.none(),
  'chat_2_Details': (data) async => ParameterData(
        allParams: {
          'chatRef': await getDocumentParameter<ChatsRecord>(
              data, 'chatRef', ChatsRecord.fromSnapshot),
          'group': await getDocumentParameter<GroupsRecord>(
              data, 'group', GroupsRecord.fromSnapshot),
        },
      ),
  'chat_2_main': ParameterData.none(),
  'chat_2_InviteUsers': (data) async => ParameterData(
        allParams: {
          'chatRef': await getDocumentParameter<ChatsRecord>(
              data, 'chatRef', ChatsRecord.fromSnapshot),
        },
      ),
  'image_Details': (data) async => ParameterData(
        allParams: {
          'chatMessage': await getDocumentParameter<ChatMessagesRecord>(
              data, 'chatMessage', ChatMessagesRecord.fromSnapshot),
        },
      ),
  'freeTrialScreen': ParameterData.none(),
  'exploreHabitsPage': (data) async => ParameterData(
        allParams: {
          'articleRef': getParameter<DocumentReference>(data, 'articleRef'),
          'categoryRef': getParameter<DocumentReference>(data, 'categoryRef'),
        },
      ),
  'createHabitPage': (data) async => ParameterData(
        allParams: {
          'existingHabit': await getDocumentParameter<HabitsRecord>(
              data, 'existingHabit', HabitsRecord.fromSnapshot),
          'prefillGoal': getParameter<String>(data, 'prefillGoal'),
          'prefillWhy': getParameter<String>(data, 'prefillWhy'),
          'prefillPrompt': getParameter<String>(data, 'prefillPrompt'),
          'prefillBehavior': getParameter<String>(data, 'prefillBehavior'),
          'prefillCelebration':
              getParameter<String>(data, 'prefillCelebration'),
          'prefillGoalIcon':
              getParameter<DocumentReference>(data, 'prefillGoalIcon'),
        },
      ),
};

Map<String, dynamic> getInitialParameterData(Map<String, dynamic> data) {
  try {
    final parameterDataStr = data['parameterData'];
    if (parameterDataStr == null ||
        parameterDataStr is! String ||
        parameterDataStr.isEmpty) {
      return {};
    }
    return jsonDecode(parameterDataStr) as Map<String, dynamic>;
  } catch (e) {
    print('Error parsing parameter data: $e');
    return {};
  }
}
