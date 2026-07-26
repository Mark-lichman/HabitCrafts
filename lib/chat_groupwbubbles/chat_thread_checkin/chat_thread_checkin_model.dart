import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/chat_groupwbubbles/checkin_display_component/checkin_display_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'chat_thread_checkin_widget.dart' show ChatThreadCheckinWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChatThreadCheckinModel extends FlutterFlowModel<ChatThreadCheckinWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  // Model for checkinDisplayComponent component.
  late CheckinDisplayComponentModel checkinDisplayComponentModel;

  @override
  void initState(BuildContext context) {
    checkinDisplayComponentModel =
        createModel(context, () => CheckinDisplayComponentModel());
  }

  @override
  void dispose() {
    expandableExpandableController.dispose();
    checkinDisplayComponentModel.dispose();
  }
}
