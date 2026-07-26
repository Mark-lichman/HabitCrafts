import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/instant_timer.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import 'habit_completed_snack_bar_widget.dart'
    show HabitCompletedSnackBarWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HabitCompletedSnackBarModel
    extends FlutterFlowModel<HabitCompletedSnackBarWidget> {
  ///  State fields for stateful widgets in this component.

  InstantTimer? instantTimer;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  HabitsRecord? habit;
  // Stores action output result for [Custom Action - getMostRecentCompletedDateTime] action in Button widget.
  DateTime? lastTime;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  UserActivityRecord? activityCopy;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    instantTimer?.cancel();
  }
}
