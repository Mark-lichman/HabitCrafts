import '/backend/backend.dart';
import '/components/reminder_text_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'habit_preview_component_widget.dart' show HabitPreviewComponentWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HabitPreviewComponentModel
    extends FlutterFlowModel<HabitPreviewComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for reminderTextComponent component.
  late ReminderTextComponentModel reminderTextComponentModel;

  @override
  void initState(BuildContext context) {
    reminderTextComponentModel =
        createModel(context, () => ReminderTextComponentModel());
  }

  @override
  void dispose() {
    reminderTextComponentModel.dispose();
  }
}
