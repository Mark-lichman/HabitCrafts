import '/backend/backend.dart';
import '/components/habit_components/active_habit_list_item/active_habit_list_item_widget.dart';
import '/components/habit_components/habit_preview_component/habit_preview_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'profile_goal_habit_list_item_widget.dart'
    show ProfileGoalHabitListItemWidget;
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfileGoalHabitListItemModel
    extends FlutterFlowModel<ProfileGoalHabitListItemWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    expandableExpandableController.dispose();
  }
}
