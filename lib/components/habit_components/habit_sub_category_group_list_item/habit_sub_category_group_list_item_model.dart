import '/backend/backend.dart';
import '/components/habit_components/single_unactive_habit_list_item/single_unactive_habit_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'habit_sub_category_group_list_item_widget.dart'
    show HabitSubCategoryGroupListItemWidget;
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HabitSubCategoryGroupListItemModel
    extends FlutterFlowModel<HabitSubCategoryGroupListItemWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for singleUnactiveHabitListItem component.
  late SingleUnactiveHabitListItemModel singleUnactiveHabitListItemModel1;
  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  @override
  void initState(BuildContext context) {
    singleUnactiveHabitListItemModel1 =
        createModel(context, () => SingleUnactiveHabitListItemModel());
  }

  @override
  void dispose() {
    singleUnactiveHabitListItemModel1.dispose();
    expandableExpandableController.dispose();
  }
}
