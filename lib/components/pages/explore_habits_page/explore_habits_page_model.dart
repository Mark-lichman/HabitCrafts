import '/components/habit_components/explore_habit_component/explore_habit_component_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'explore_habits_page_widget.dart' show ExploreHabitsPageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ExploreHabitsPageModel extends FlutterFlowModel<ExploreHabitsPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for exploreHabitComponent component.
  late ExploreHabitComponentModel exploreHabitComponentModel;

  @override
  void initState(BuildContext context) {
    exploreHabitComponentModel =
        createModel(context, () => ExploreHabitComponentModel());
  }

  @override
  void dispose() {
    exploreHabitComponentModel.dispose();
  }
}
