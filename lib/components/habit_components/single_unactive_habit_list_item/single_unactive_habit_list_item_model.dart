import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'single_unactive_habit_list_item_widget.dart'
    show SingleUnactiveHabitListItemWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SingleUnactiveHabitListItemModel
    extends FlutterFlowModel<SingleUnactiveHabitListItemWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - Read Document] action in Container widget.
  GoalsRecord? goal;
  // Stores action output result for [Backend Call - Read Document] action in Container widget.
  CategoriesRecord? category;
  // Stores action output result for [Backend Call - Read Document] action in Container widget.
  CategoriesRecord? category1;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
