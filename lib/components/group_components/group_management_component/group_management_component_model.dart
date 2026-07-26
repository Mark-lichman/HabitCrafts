import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/group_accept_decline_list_item/group_accept_decline_list_item_widget.dart';
import '/components/group_components/group_create_modal/group_create_modal_widget.dart';
import '/components/group_components/group_manage_list_item/group_manage_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'group_management_component_widget.dart'
    show GroupManagementComponentWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupManagementComponentModel
    extends FlutterFlowModel<GroupManagementComponentWidget> {
  ///  Local state fields for this component.

  List<GroupMembershipStatus> creatorOrLeader = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Creator
  ];
  void addToCreatorOrLeader(GroupMembershipStatus item) =>
      creatorOrLeader.add(item);
  void removeFromCreatorOrLeader(GroupMembershipStatus item) =>
      creatorOrLeader.remove(item);
  void removeAtIndexFromCreatorOrLeader(int index) =>
      creatorOrLeader.removeAt(index);
  void insertAtIndexInCreatorOrLeader(int index, GroupMembershipStatus item) =>
      creatorOrLeader.insert(index, item);
  void updateCreatorOrLeaderAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      creatorOrLeader[index] = updateFn(creatorOrLeader[index]);

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
