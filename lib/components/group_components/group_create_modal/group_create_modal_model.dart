import '/components/group_components/create_group_component/create_group_component_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'group_create_modal_widget.dart' show GroupCreateModalWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupCreateModalModel extends FlutterFlowModel<GroupCreateModalWidget> {
  ///  Local state fields for this component.

  int loopIndex = 0;

  List<DocumentReference> teamLeaders = [];
  void addToTeamLeaders(DocumentReference item) => teamLeaders.add(item);
  void removeFromTeamLeaders(DocumentReference item) =>
      teamLeaders.remove(item);
  void removeAtIndexFromTeamLeaders(int index) => teamLeaders.removeAt(index);
  void insertAtIndexInTeamLeaders(int index, DocumentReference item) =>
      teamLeaders.insert(index, item);
  void updateTeamLeadersAtIndex(
          int index, Function(DocumentReference) updateFn) =>
      teamLeaders[index] = updateFn(teamLeaders[index]);

  ///  State fields for stateful widgets in this component.

  // Model for createGroupComponent component.
  late CreateGroupComponentModel createGroupComponentModel;

  @override
  void initState(BuildContext context) {
    createGroupComponentModel =
        createModel(context, () => CreateGroupComponentModel());
  }

  @override
  void dispose() {
    createGroupComponentModel.dispose();
  }
}
