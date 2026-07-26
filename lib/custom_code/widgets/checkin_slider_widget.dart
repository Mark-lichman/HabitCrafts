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

import 'dart:ui' as ui;

class CheckinSliderWidget extends StatefulWidget {
  const CheckinSliderWidget({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<CheckinSliderWidget> createState() => _CheckinSliderWidgetState();
}

class _CheckinSliderWidgetState extends State<CheckinSliderWidget> {
  double _value = 0;

  // Drawn as text rather than loaded as images, so the slider has no network
  // dependency and renders on the first frame.
  static const List<String> _emojis = ['😞', '🙁', '😐', '🙂', '😄'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 0, left: 20, right: 20),
      alignment: Alignment.centerLeft,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Color(0xff2A405D),
          inactiveTrackColor: Color(0xff2A405D),
          trackHeight: 10.0,
          thumbShape: SliderThumbEmoji(_emojis[_value.toInt()]),
          activeTickMarkColor: Color(0xff2A405D),
          inactiveTickMarkColor: Color(0xff2A405D),
        ),
        child: Slider(
          value: _value,
          max: 4,
          divisions: 4,
          onChanged: (value) {
            setState(() {
              _value = value;
              FFAppState().checkinSliderValue = value.toInt() + 1;
            });
          },
        ),
      ),
    );
  }
}

class SliderThumbEmoji extends SliderComponentShape {
  final String emoji;
  final double size;

  const SliderThumbEmoji(this.emoji, {this.size = 36});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(size, size);
  }

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required ui.TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final textPainter = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
      textDirection: textDirection,
    )..layout();

    textPainter.paint(
      context.canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
}
