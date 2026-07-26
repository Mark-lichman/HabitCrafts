import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/chat_groupwbubbles/chat_thread_checkin/chat_thread_checkin_widget.dart';
import '/chat_groupwbubbles/emojipicker/emojipicker_widget.dart';
import '/components/profile_components/profile_preview_component/profile_preview_component_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_media_display.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_video_player.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/flutter_flow/request_manager.dart';

import '/index.dart';
import 'chat_thread_update_widget.dart' show ChatThreadUpdateWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChatThreadUpdateModel extends FlutterFlowModel<ChatThreadUpdateWidget> {
  ///  Local state fields for this component.

  List<ReactionsRecord> reactions = [];
  void addToReactions(ReactionsRecord item) => reactions.add(item);
  void removeFromReactions(ReactionsRecord item) => reactions.remove(item);
  void removeAtIndexFromReactions(int index) => reactions.removeAt(index);
  void insertAtIndexInReactions(int index, ReactionsRecord item) =>
      reactions.insert(index, item);
  void updateReactionsAtIndex(int index, Function(ReactionsRecord) updateFn) =>
      reactions[index] = updateFn(reactions[index]);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Firestore Query - Query a collection] action in chat_threadUpdate widget.
  List<ReactionsRecord>? initialReactions;
  // Model for userIcon component.
  late UserIconModel userIconModel;
  // Model for chat_threadCheckin component.
  late ChatThreadCheckinModel chatThreadCheckinModel1;
  // Model for chat_threadCheckin component.
  late ChatThreadCheckinModel chatThreadCheckinModel2;

  /// Query cache managers for this widget.

  final _chatUserManager = FutureRequestManager<UsersRecord>();
  Future<UsersRecord> chatUser({
    String? uniqueQueryKey,
    bool? overrideCache,
    required Future<UsersRecord> Function() requestFn,
  }) =>
      _chatUserManager.performRequest(
        uniqueQueryKey: uniqueQueryKey,
        overrideCache: overrideCache,
        requestFn: requestFn,
      );
  void clearChatUserCache() => _chatUserManager.clear();
  void clearChatUserCacheKey(String? uniqueKey) =>
      _chatUserManager.clearRequest(uniqueKey);

  @override
  void initState(BuildContext context) {
    userIconModel = createModel(context, () => UserIconModel());
    chatThreadCheckinModel1 =
        createModel(context, () => ChatThreadCheckinModel());
    chatThreadCheckinModel2 =
        createModel(context, () => ChatThreadCheckinModel());
  }

  @override
  void dispose() {
    userIconModel.dispose();
    chatThreadCheckinModel1.dispose();
    chatThreadCheckinModel2.dispose();

    /// Dispose query cache managers for this widget.

    clearChatUserCache();
  }

  /// Action blocks.
  Future addChatReaction(
    BuildContext context, {
    required String? emoji,
  }) async {
    ReactionsRecord? existingReaction;
    ReactionsRecord? userReaction;
    ChatsRecord? chatDoc;

    // This is checking to see if there are any exisitng reactions from other users that are with the same emoji
    logFirebaseEvent('addChatReaction_firestore_query');
    existingReaction = await queryReactionsRecordOnce(
      parent: FFAppState().selectedChatMessage,
      queryBuilder: (reactionsRecord) => reactionsRecord.where(
        'emoji',
        isEqualTo: emoji,
      ),
      singleRecord: true,
    ).then((s) => s.firstOrNull);
    // We're allowing the user to leave one reaction to a message. If the user has already reacted to a message, delete the existing reaction and replace it
    logFirebaseEvent('addChatReaction_firestore_query');
    userReaction = await queryReactionsRecordOnce(
      parent: widget!.chatMessagesRef?.reference,
      queryBuilder: (reactionsRecord) => reactionsRecord.where(
        'users',
        arrayContains: currentUserReference,
      ),
      singleRecord: true,
    ).then((s) => s.firstOrNull);
    logFirebaseEvent('addChatReaction_backend_call');
    chatDoc = await ChatsRecord.getDocumentOnce(widget!.chatMessagesRef!.chat!);
    logFirebaseEvent('addChatReaction_trigger_push_notificatio');
    triggerPushNotification(
      notificationTitle: '${currentUserDisplayName} responded with ${emoji}',
      notificationText: '',
      userRefs: [widget!.chatMessagesRef!.user!],
      initialPageName: 'chat_2_Details',
      parameterData: {
        'chatRef': chatDoc,
      },
    );
    if ((userReaction != null) == true) {
      logFirebaseEvent('addChatReaction_backend_call');
      await userReaction!.reference.delete();
    }
    if (existingReaction != null) {
      logFirebaseEvent('addChatReaction_backend_call');

      await existingReaction!.reference.update({
        ...mapToFirestore(
          {
            'count': FieldValue.increment(1),
            'users': FieldValue.arrayUnion([currentUserReference]),
          },
        ),
      });
    } else {
      logFirebaseEvent('addChatReaction_backend_call');

      await ReactionsRecord.createDoc(widget!.chatMessagesRef!.reference).set({
        ...createReactionsRecordData(
          emoji: emoji,
          createdAt: getCurrentTimestamp,
          count: 1,
        ),
        ...mapToFirestore(
          {
            'users': [currentUserReference],
          },
        ),
      });
    }

    logFirebaseEvent('addChatReaction_update_app_state');
    FFAppState().selectedChatMessage = null;
    FFAppState().update(() {});
  }
}
