import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/create_group_component/create_group_component_widget.dart';
import '/components/group_components/group_invite_component/group_invite_component_widget.dart';
import '/components/group_components/group_management_component/group_management_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'create_manage_invite_group_component_widget.dart'
    show CreateManageInviteGroupComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateManageInviteGroupComponentModel
    extends FlutterFlowModel<CreateManageInviteGroupComponentWidget> {
  ///  Local state fields for this component.

  int groupManagementIndex = 0;

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Firestore Query - Query a collection] action in createManageInviteGroupComponent widget.
  int? creatorCount;
  // State field(s) for PageView widget.
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;
  // Model for createGroupComponent component.
  late CreateGroupComponentModel createGroupComponentModel;
  // Model for groupManagementComponent component.
  late GroupManagementComponentModel groupManagementComponentModel;
  // Model for groupInviteComponent component.
  late GroupInviteComponentModel groupInviteComponentModel;

  @override
  void initState(BuildContext context) {
    createGroupComponentModel =
        createModel(context, () => CreateGroupComponentModel());
    groupManagementComponentModel =
        createModel(context, () => GroupManagementComponentModel());
    groupInviteComponentModel =
        createModel(context, () => GroupInviteComponentModel());
  }

  @override
  void dispose() {
    createGroupComponentModel.dispose();
    groupManagementComponentModel.dispose();
    groupInviteComponentModel.dispose();
  }
}
