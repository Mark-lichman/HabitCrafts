import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/index.dart';
import 'group_list_contents_widget.dart' show GroupListContentsWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupListContentsModel extends FlutterFlowModel<GroupListContentsWidget> {
  ///  Local state fields for this component.

  List<GroupMembershipStatus> memberCreatorLeader = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Member,
    GroupMembershipStatus.Creator
  ];
  void addToMemberCreatorLeader(GroupMembershipStatus item) =>
      memberCreatorLeader.add(item);
  void removeFromMemberCreatorLeader(GroupMembershipStatus item) =>
      memberCreatorLeader.remove(item);
  void removeAtIndexFromMemberCreatorLeader(int index) =>
      memberCreatorLeader.removeAt(index);
  void insertAtIndexInMemberCreatorLeader(
          int index, GroupMembershipStatus item) =>
      memberCreatorLeader.insert(index, item);
  void updateMemberCreatorLeaderAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      memberCreatorLeader[index] = updateFn(memberCreatorLeader[index]);

  Color textColor = Color(4294967295);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - Read Document] action in MainContainer widget.
  ChatsRecord? chatRef;
  // Stores action output result for [Firestore Query - Query a collection] action in MainContainer widget.
  GroupMemberStateRecord? groupMemberState;
  // Stores action output result for [Firestore Query - Query a collection] action in MainContainer widget.
  ChatsRecord? chat;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
