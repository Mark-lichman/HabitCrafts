import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/checkin_component/checkin_component_widget.dart';
import '/components/group_components/group_check_in_list_item/group_check_in_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'group_checkin_list_component_widget.dart'
    show GroupCheckinListComponentWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupCheckinListComponentModel
    extends FlutterFlowModel<GroupCheckinListComponentWidget> {
  ///  Local state fields for this component.

  GroupMembershipStatus? enumField = GroupMembershipStatus.Leader;

  List<GroupMemberStateRecord> filteredGroupMemberStates = [];
  void addToFilteredGroupMemberStates(GroupMemberStateRecord item) =>
      filteredGroupMemberStates.add(item);
  void removeFromFilteredGroupMemberStates(GroupMemberStateRecord item) =>
      filteredGroupMemberStates.remove(item);
  void removeAtIndexFromFilteredGroupMemberStates(int index) =>
      filteredGroupMemberStates.removeAt(index);
  void insertAtIndexInFilteredGroupMemberStates(
          int index, GroupMemberStateRecord item) =>
      filteredGroupMemberStates.insert(index, item);
  void updateFilteredGroupMemberStatesAtIndex(
          int index, Function(GroupMemberStateRecord) updateFn) =>
      filteredGroupMemberStates[index] =
          updateFn(filteredGroupMemberStates[index]);

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
