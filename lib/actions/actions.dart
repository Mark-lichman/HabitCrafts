import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/random_data_util.dart' as random_data;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

Future clearTempValues(BuildContext context) async {
  logFirebaseEvent('clearTempValues_update_app_state');
  FFAppState().tempHabitRef = null;
  FFAppState().tempReminderRef = null;
  FFAppState().tempActivityRef = null;
}

Future<ChatsRecord> createChat(
  BuildContext context, {
  required DocumentReference? group,
}) async {
  List<GroupMemberStateRecord>? memberList;
  ChatsRecord? newChat;
  ChatsRecord? newChatDoc;

  logFirebaseEvent('createChat_firestore_query');
  memberList = await queryGroupMemberStateRecordOnce(
    queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
        .whereIn(
            'status',
            FFAppState()
                .ownerLeaderMemberTypes
                .map((e) => e.serialize())
                .toList())
        .where(
          'group',
          isEqualTo: group,
        ),
  );
  logFirebaseEvent('createChat_backend_call');

  var chatsRecordReference1 = ChatsRecord.collection.doc();
  await chatsRecordReference1.set({
    ...createChatsRecordData(
      groupChatId: random_data.randomInteger(100, 1000000),
      lastMessage: '',
      lastMessageTime: getCurrentTimestamp,
      userA: currentUserReference,
      userB: currentUserReference,
      lastMessageSentBy: currentUserReference,
      group: group,
    ),
    ...mapToFirestore(
      {
        'users': memberList?.map((e) => e.member).withoutNulls.toList(),
      },
    ),
  });
  newChat = ChatsRecord.getDocumentFromData({
    ...createChatsRecordData(
      groupChatId: random_data.randomInteger(100, 1000000),
      lastMessage: '',
      lastMessageTime: getCurrentTimestamp,
      userA: currentUserReference,
      userB: currentUserReference,
      lastMessageSentBy: currentUserReference,
      group: group,
    ),
    ...mapToFirestore(
      {
        'users': memberList?.map((e) => e.member).withoutNulls.toList(),
      },
    ),
  }, chatsRecordReference1);
  logFirebaseEvent('createChat_backend_call');

  await group!.update(createGroupsRecordData(
    chat: newChat?.reference,
  ));
  logFirebaseEvent('createChat_backend_call');
  newChatDoc = await ChatsRecord.getDocumentOnce(newChat!.reference);
  return newChatDoc!;
}

Future<bool> inviteFriendToGroup(
  BuildContext context, {
  required UsersRecord? userToInvite,
  required DocumentReference? groupRef,
}) async {
  logFirebaseEvent('inviteFriendToGroup_alert_dialog');
  var confirmDialogResponse = await showDialog<bool>(
        context: context,
        builder: (alertDialogContext) {
          return AlertDialog(
            title: Text('Invite ${userToInvite?.displayName} to this group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext, true),
                child: Text('Confirm'),
              ),
            ],
          );
        },
      ) ??
      false;
  if (confirmDialogResponse) {
    logFirebaseEvent('inviteFriendToGroup_trigger_push_notific');
    triggerPushNotification(
      notificationTitle: '${currentUserDisplayName} has invited you to a group',
      notificationText: 'Open the groups page to join',
      userRefs: [userToInvite!.reference],
      initialPageName: 'groupsPage',
      parameterData: {
        'groupFromPush': groupRef,
      },
    );
    logFirebaseEvent('inviteFriendToGroup_backend_call');

    await GroupMemberStateRecord.collection
        .doc()
        .set(createGroupMemberStateRecordData(
          member: userToInvite?.reference,
          status: GroupMembershipStatus.Invited,
          group: groupRef,
        ));
    return true;
  } else {
    return false;
  }
}

Future userJoinGroup(
  BuildContext context, {
  required DocumentReference? groupRef,
  required DocumentReference? user,
}) async {
  GroupsRecord? group;
  List<GroupMemberStateRecord>? currentMemberList;
  int? uniqueCount;
  GroupMemberStateRecord? groupMemberState;
  RemindersRecord? reminder;

  logFirebaseEvent('userJoinGroup_backend_call');
  group = await GroupsRecord.getDocumentOnce(groupRef!);
  logFirebaseEvent('userJoinGroup_firestore_query');
  currentMemberList = await queryGroupMemberStateRecordOnce(
    queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
        .where(
          'group',
          isEqualTo: groupRef,
        )
        .whereIn(
            'status',
            FFAppState()
                .ownerLeaderMemberTypes
                .map((e) => e.serialize())
                .toList())
        .where(
          'status',
          isNotEqualTo: null?.serialize(),
        )
        .where(
          'recent_checkin',
          isEqualTo: '1/1/1970',
        ),
  );
  logFirebaseEvent('userJoinGroup_custom_action');
  uniqueCount = await actions.numberOfGroupMemberStateToUniqueUsers(
    currentMemberList!.toList(),
  );
  if (group?.memberLimit == uniqueCount) {
    logFirebaseEvent('userJoinGroup_alert_dialog');
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: Text('No more room!'),
          content:
              Text('Sorry, the max number of users are already in this group.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext),
              child: Text('Ok'),
            ),
          ],
        );
      },
    );
  } else {
    logFirebaseEvent('userJoinGroup_firestore_query');
    groupMemberState = await queryGroupMemberStateRecordOnce(
      queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
          .where(
            'group',
            isEqualTo: groupRef,
          )
          .where(
            'member',
            isEqualTo: user,
          ),
      singleRecord: true,
    ).then((s) => s.firstOrNull);
    if (groupMemberState != null) {
      logFirebaseEvent('userJoinGroup_backend_call');

      await groupMemberState!.reference.update(createGroupMemberStateRecordData(
        status: GroupMembershipStatus.Member,
        checkinDay: dateTimeFormat("EEEE", group?.checkinTime),
        recentCheckin: 'Jan 1, 1970',
      ));
    } else {
      logFirebaseEvent('userJoinGroup_backend_call');

      await GroupMemberStateRecord.collection
          .doc()
          .set(createGroupMemberStateRecordData(
            member: currentUserReference,
            status: GroupMembershipStatus.Member,
            group: groupRef,
            checkinDay: dateTimeFormat("EEEE", group?.checkinTime),
            recentCheckin: 'Jan 1, 1970',
          ));
    }

    if (group?.reminderOwner != null) {
      logFirebaseEvent('userJoinGroup_backend_call');
      reminder = await RemindersRecord.getDocumentOnce(group!.reminderOwner!);
      // add the reminder for the push notification
      //
      logFirebaseEvent('userJoinGroup_backend_call');

      await RemindersRecord.collection.doc().set({
        ...createRemindersRecordData(
          time: reminder?.time,
          user: currentUserReference,
          hour: reminder?.hour,
          minute: reminder?.minute,
          timezoneOffset: valueOrDefault(currentUserDocument?.localOffset, 0),
          group: groupRef,
        ),
        ...mapToFirestore(
          {
            'days': reminder?.days,
          },
        ),
      });
    }
    // add user to the chat list
    logFirebaseEvent('userJoinGroup_backend_call');

    await group!.chat!.update({
      ...mapToFirestore(
        {
          'users': FieldValue.arrayUnion([currentUserReference]),
        },
      ),
    });
    logFirebaseEvent('userJoinGroup_trigger_push_notification');
    triggerPushNotification(
      notificationTitle: 'New user joined ${group?.name}',
      notificationText: '${currentUserDisplayName} joined your group.',
      notificationSound: 'default',
      userRefs: [group!.creator!],
      initialPageName: 'groupsPage',
      parameterData: {
        'groupFromPush': groupRef,
      },
    );
  }
}

Future updateGroupMemberLastActive(
  BuildContext context, {
  required DocumentReference? groupMemberStateRef,
}) async {
  logFirebaseEvent('updateGroupMemberLastActive_backend_call');

  await groupMemberStateRef!.update(createGroupMemberStateRecordData(
    lastActive: getCurrentTimestamp,
  ));
}

Future fetchContacts(BuildContext context) async {
  List<DocumentReference>? contacts;

  logFirebaseEvent('fetchContacts_custom_action');
  contacts = await actions.fetchContactsAction(
    functions
        .usersToList(currentUserReference!, currentUserReference!)
        .toList(),
  );
  logFirebaseEvent('fetchContacts_update_app_state');
  FFAppState().localContactUsers = contacts!.toList().cast<DocumentReference>();
}

Future userRequestToJoinGroup(
  BuildContext context, {
  required DocumentReference? user,
  required DocumentReference? group,
}) async {
  GroupMemberStateRecord? groupMemberState;

  logFirebaseEvent('userRequestToJoinGroup_backend_call');

  var groupMemberStateRecordReference = GroupMemberStateRecord.collection.doc();
  await groupMemberStateRecordReference.set(createGroupMemberStateRecordData(
    member: user,
    status: GroupMembershipStatus.Pending,
    group: group,
    recentCheckin: '1/1/1970',
  ));
  groupMemberState = GroupMemberStateRecord.getDocumentFromData(
      createGroupMemberStateRecordData(
        member: user,
        status: GroupMembershipStatus.Pending,
        group: group,
        recentCheckin: '1/1/1970',
      ),
      groupMemberStateRecordReference);
}

Future openChatWithUser(
  BuildContext context, {
  required DocumentReference? userRef,
}) async {
  List<ChatsRecord>? searchChatRef;
  ChatsRecord? chatWithBoth;
  ChatsRecord? newChatUser;

  // search for an existing chat by the users
  // confirm in the next action that this action is not tied to a group
  logFirebaseEvent('openChatWithUser_firestore_query');
  searchChatRef = await queryChatsRecordOnce(
    queryBuilder: (chatsRecord) => chatsRecord
        .where(
          'users',
          arrayContains: userRef,
        )
        .where(
          'group',
          isEqualTo: null,
        ),
  );
  logFirebaseEvent('openChatWithUser_custom_action');
  chatWithBoth = await actions.chatContainingUser(
    currentUserReference!,
    searchChatRef!.toList(),
  );
  if (chatWithBoth != null) {
    logFirebaseEvent('openChatWithUser_navigate_to');

    context.pushNamed(
      Chat2DetailsWidget.routeName,
      queryParameters: {
        'chatRef': serializeParam(
          chatWithBoth,
          ParamType.Document,
        ),
      }.withoutNulls,
      extra: <String, dynamic>{
        'chatRef': chatWithBoth,
      },
    );
  } else {
    // newChat
    logFirebaseEvent('openChatWithUser_newChat');

    var chatsRecordReference = ChatsRecord.collection.doc();
    await chatsRecordReference.set({
      ...createChatsRecordData(
        userA: currentUserReference,
        userB: userRef,
        lastMessage: '',
        lastMessageTime: getCurrentTimestamp,
        lastMessageSentBy: currentUserReference,
        groupChatId: random_data.randomInteger(1000000, 9999999),
      ),
      ...mapToFirestore(
        {
          'users': functions.usersToList(userRef!, currentUserReference!),
        },
      ),
    });
    newChatUser = ChatsRecord.getDocumentFromData({
      ...createChatsRecordData(
        userA: currentUserReference,
        userB: userRef,
        lastMessage: '',
        lastMessageTime: getCurrentTimestamp,
        lastMessageSentBy: currentUserReference,
        groupChatId: random_data.randomInteger(1000000, 9999999),
      ),
      ...mapToFirestore(
        {
          'users': functions.usersToList(userRef!, currentUserReference!),
        },
      ),
    }, chatsRecordReference);
    logFirebaseEvent('openChatWithUser_navigate_to');

    context.pushNamed(
      Chat2DetailsWidget.routeName,
      queryParameters: {
        'chatRef': serializeParam(
          newChatUser,
          ParamType.Document,
        ),
      }.withoutNulls,
      extra: <String, dynamic>{
        'chatRef': newChatUser,
      },
    );
  }
}

Future afterGroupCreatedCalls(BuildContext context) async {}
