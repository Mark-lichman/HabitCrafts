// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class HtmlVideoWidget extends StatefulWidget {
  const HtmlVideoWidget({
    super.key,
    this.width,
    this.height,
    required this.htmlContent,
  });

  final double? width;
  final double? height;
  final String htmlContent;

  @override
  State<HtmlVideoWidget> createState() => _NewCustomWidgetState();
}

class _NewCustomWidgetState extends State<HtmlVideoWidget> {
  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      // the first parameter (`html`) is required
      widget.htmlContent,

      // select the render mode for HTML body
      // by default, a simple `Column` is rendered
      // consider using `ListView` or `SliverList` for better performance
      renderMode: RenderMode.column,

      // set the default styling for text
      textStyle: TextStyle(fontSize: 14),
    );
  }
}
