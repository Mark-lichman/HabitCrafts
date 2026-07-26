import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/group_list_contents/group_list_contents_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import 'search_list_item_widget.dart' show SearchListItemWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SearchListItemModel extends FlutterFlowModel<SearchListItemWidget> {
  ///  Local state fields for this component.

  List<GroupMembershipStatus> memberOwnerLeaders = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Member,
    GroupMembershipStatus.Creator
  ];
  void addToMemberOwnerLeaders(GroupMembershipStatus item) =>
      memberOwnerLeaders.add(item);
  void removeFromMemberOwnerLeaders(GroupMembershipStatus item) =>
      memberOwnerLeaders.remove(item);
  void removeAtIndexFromMemberOwnerLeaders(int index) =>
      memberOwnerLeaders.removeAt(index);
  void insertAtIndexInMemberOwnerLeaders(
          int index, GroupMembershipStatus item) =>
      memberOwnerLeaders.insert(index, item);
  void updateMemberOwnerLeadersAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      memberOwnerLeaders[index] = updateFn(memberOwnerLeaders[index]);

  List<DocumentReference> combinedUsers = [];
  void addToCombinedUsers(DocumentReference item) => combinedUsers.add(item);
  void removeFromCombinedUsers(DocumentReference item) =>
      combinedUsers.remove(item);
  void removeAtIndexFromCombinedUsers(int index) =>
      combinedUsers.removeAt(index);
  void insertAtIndexInCombinedUsers(int index, DocumentReference item) =>
      combinedUsers.insert(index, item);
  void updateCombinedUsersAtIndex(
          int index, Function(DocumentReference) updateFn) =>
      combinedUsers[index] = updateFn(combinedUsers[index]);

  ///  State fields for stateful widgets in this component.

  // Model for groupListContents component.
  late GroupListContentsModel groupListContentsModel;

  @override
  void initState(BuildContext context) {
    groupListContentsModel =
        createModel(context, () => GroupListContentsModel());
  }

  @override
  void dispose() {
    groupListContentsModel.dispose();
  }
}
