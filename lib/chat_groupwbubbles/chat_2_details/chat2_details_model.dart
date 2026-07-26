import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/chat_groupwbubbles/chat_members_view_component/chat_members_view_component_widget.dart';
import '/chat_groupwbubbles/chat_thread_component/chat_thread_component_widget.dart';
import '/chat_groupwbubbles/long_press_chat_options/long_press_chat_options_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'chat2_details_widget.dart' show Chat2DetailsWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class Chat2DetailsModel extends FlutterFlowModel<Chat2DetailsWidget> {
  ///  Local state fields for this page.

  List<String> uploadedImages = [];
  void addToUploadedImages(String item) => uploadedImages.add(item);
  void removeFromUploadedImages(String item) => uploadedImages.remove(item);
  void removeAtIndexFromUploadedImages(int index) =>
      uploadedImages.removeAt(index);
  void insertAtIndexInUploadedImages(int index, String item) =>
      uploadedImages.insert(index, item);
  void updateUploadedImagesAtIndex(int index, Function(String) updateFn) =>
      uploadedImages[index] = updateFn(uploadedImages[index]);

  List<DocumentReference> lastMessageSeenBy = [];
  void addToLastMessageSeenBy(DocumentReference item) =>
      lastMessageSeenBy.add(item);
  void removeFromLastMessageSeenBy(DocumentReference item) =>
      lastMessageSeenBy.remove(item);
  void removeAtIndexFromLastMessageSeenBy(int index) =>
      lastMessageSeenBy.removeAt(index);
  void insertAtIndexInLastMessageSeenBy(int index, DocumentReference item) =>
      lastMessageSeenBy.insert(index, item);
  void updateLastMessageSeenByAtIndex(
          int index, Function(DocumentReference) updateFn) =>
      lastMessageSeenBy[index] = updateFn(lastMessageSeenBy[index]);

  List<GroupMembershipStatus> memberLeaderCreator = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Member,
    GroupMembershipStatus.Creator
  ];
  void addToMemberLeaderCreator(GroupMembershipStatus item) =>
      memberLeaderCreator.add(item);
  void removeFromMemberLeaderCreator(GroupMembershipStatus item) =>
      memberLeaderCreator.remove(item);
  void removeAtIndexFromMemberLeaderCreator(int index) =>
      memberLeaderCreator.removeAt(index);
  void insertAtIndexInMemberLeaderCreator(
          int index, GroupMembershipStatus item) =>
      memberLeaderCreator.insert(index, item);
  void updateMemberLeaderCreatorAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      memberLeaderCreator[index] = updateFn(memberLeaderCreator[index]);

  bool showMessageOptions = false;

  ChatMessagesRecord? longPressedChatMessage;

  ///  State fields for stateful widgets in this page.

  // Model for chat_ThreadComponent component.
  late ChatThreadComponentModel chatThreadComponentModel;
  // Model for userIcon component.
  late UserIconModel userIconModel;

  @override
  void initState(BuildContext context) {
    chatThreadComponentModel =
        createModel(context, () => ChatThreadComponentModel());
    userIconModel = createModel(context, () => UserIconModel());
  }

  @override
  void dispose() {
    chatThreadComponentModel.dispose();
    userIconModel.dispose();
  }
}
