import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/chat_groupwbubbles/checkin_display_component/checkin_display_component_widget.dart';
import '/components/habit_components/habit_preview_component/habit_preview_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'notes_modal_component_widget.dart' show NotesModalComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NotesModalComponentModel
    extends FlutterFlowModel<NotesModalComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for checkinDisplayComponent component.
  late CheckinDisplayComponentModel checkinDisplayComponentModel;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {
    checkinDisplayComponentModel =
        createModel(context, () => CheckinDisplayComponentModel());
  }

  @override
  void dispose() {
    checkinDisplayComponentModel.dispose();
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
