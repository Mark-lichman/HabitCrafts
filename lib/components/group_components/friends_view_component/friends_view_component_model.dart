import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/actions/actions.dart' as action_blocks;
import 'friends_view_component_widget.dart' show FriendsViewComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FriendsViewComponentModel
    extends FlutterFlowModel<FriendsViewComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Action Block - inviteFriendToGroup] action in Image widget.
  bool? didInvite;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
