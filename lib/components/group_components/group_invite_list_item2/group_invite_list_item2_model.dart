import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/common_ui/loading_indicator/loading_indicator_widget.dart';
import '/components/group_components/new_group_created_modal/new_group_created_modal_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'group_invite_list_item2_widget.dart' show GroupInviteListItem2Widget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupInviteListItem2Model
    extends FlutterFlowModel<GroupInviteListItem2Widget> {
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

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Firestore Query - Query a collection] action in Container widget.
  List<GroupMemberStateRecord>? groupMembers;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
