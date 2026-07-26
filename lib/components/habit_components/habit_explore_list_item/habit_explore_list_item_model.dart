import '/backend/backend.dart';
import '/components/habit_components/category_list_display/category_list_display_widget.dart';
import '/components/habit_components/habit_articles_group_list_item/habit_articles_group_list_item_widget.dart';
import '/components/habit_components/habit_sub_category_group_list_item/habit_sub_category_group_list_item_widget.dart';
import '/components/habit_components/single_unactive_habit_list_item/single_unactive_habit_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'habit_explore_list_item_widget.dart' show HabitExploreListItemWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HabitExploreListItemModel
    extends FlutterFlowModel<HabitExploreListItemWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  // Model for category_list_display component.
  late CategoryListDisplayModel categoryListDisplayModel;

  @override
  void initState(BuildContext context) {
    categoryListDisplayModel =
        createModel(context, () => CategoryListDisplayModel());
  }

  @override
  void dispose() {
    expandableExpandableController.dispose();
    categoryListDisplayModel.dispose();
  }
}
