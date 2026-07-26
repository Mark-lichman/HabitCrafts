import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/group_list_contents/group_list_contents_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'group_list_item_widget.dart' show GroupListItemWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupListItemModel extends FlutterFlowModel<GroupListItemWidget> {
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

  GroupsRecord? selectedGroup;

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
