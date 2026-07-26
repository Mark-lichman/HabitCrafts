import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/day_time_frequency_picker_component/day_time_frequency_picker_component_widget.dart';
import '/components/reminder_text_component_widget.dart';
import '/flutter_flow/flutter_flow_autocomplete_options_list.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'new_habit_component_widget.dart' show NewHabitComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NewHabitComponentModel extends FlutterFlowModel<NewHabitComponentWidget> {
  ///  Local state fields for this component.

  bool isEditing = false;

  ///  State fields for stateful widgets in this component.

  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  // State field(s) for InputField widget.
  final inputFieldKey = GlobalKey();
  FocusNode? inputFieldFocusNode;
  TextEditingController? inputFieldTextController;
  String? inputFieldSelectedOption;
  String? Function(BuildContext, String?)? inputFieldTextControllerValidator;
  // Model for reminderTextComponent component.
  late ReminderTextComponentModel reminderTextComponentModel;
  // State field(s) for Switch widget.
  bool? switchValue;
  // Stores action output result for [Backend Call - Read Document] action in IconButton widget.
  RemindersRecord? reminder;

  @override
  void initState(BuildContext context) {
    reminderTextComponentModel =
        createModel(context, () => ReminderTextComponentModel());
  }

  @override
  void dispose() {
    expandableExpandableController.dispose();
    inputFieldFocusNode?.dispose();

    reminderTextComponentModel.dispose();
  }
}
