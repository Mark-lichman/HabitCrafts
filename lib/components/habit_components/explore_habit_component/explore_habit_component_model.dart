import '/backend/backend.dart';
import '/components/habit_components/habit_explore_list_item/habit_explore_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'explore_habit_component_widget.dart' show ExploreHabitComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';

class ExploreHabitComponentModel
    extends FlutterFlowModel<ExploreHabitComponentWidget> {
  ///  Local state fields for this component.

  bool isShowFullList = true;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  List<CategoriesRecord> simpleSearchResults = [];
  // Model for habitExploreListItem component.
  late HabitExploreListItemModel habitExploreListItemModel1;

  @override
  void initState(BuildContext context) {
    habitExploreListItemModel1 =
        createModel(context, () => HabitExploreListItemModel());
  }

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();

    habitExploreListItemModel1.dispose();
  }
}
