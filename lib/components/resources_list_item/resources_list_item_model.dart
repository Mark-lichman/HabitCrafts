import '/backend/backend.dart';
import '/components/habit_components/category_list_display/category_list_display_widget.dart';
import '/components/resource_article_list_item/resource_article_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'resources_list_item_widget.dart' show ResourcesListItemWidget;
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ResourcesListItemModel extends FlutterFlowModel<ResourcesListItemWidget> {
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
