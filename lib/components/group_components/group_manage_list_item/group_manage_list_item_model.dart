import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/new_group_created_modal/new_group_created_modal_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import 'group_manage_list_item_widget.dart' show GroupManageListItemWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupManageListItemModel
    extends FlutterFlowModel<GroupManageListItemWidget> {
  ///  Local state fields for this component.

  bool isEditing = false;

  List<GroupMembershipStatus> memberLeaderOwner = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Creator,
    GroupMembershipStatus.Member
  ];
  void addToMemberLeaderOwner(GroupMembershipStatus item) =>
      memberLeaderOwner.add(item);
  void removeFromMemberLeaderOwner(GroupMembershipStatus item) =>
      memberLeaderOwner.remove(item);
  void removeAtIndexFromMemberLeaderOwner(int index) =>
      memberLeaderOwner.removeAt(index);
  void insertAtIndexInMemberLeaderOwner(
          int index, GroupMembershipStatus item) =>
      memberLeaderOwner.insert(index, item);
  void updateMemberLeaderOwnerAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      memberLeaderOwner[index] = updateFn(memberLeaderOwner[index]);

  ///  State fields for stateful widgets in this component.

  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  DateTime? datePicked;
  // State field(s) for Switch widget.
  bool? switchValue;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  ChatsRecord? chatDoc;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  GroupMemberStateRecord? gms;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  List<GroupMemberStateRecord>? groupMemberStates1;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  List<UserGroupSearchRecord>? userGroupSearch1;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    expandableExpandableController.dispose();
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    textController2?.dispose();
  }
}
