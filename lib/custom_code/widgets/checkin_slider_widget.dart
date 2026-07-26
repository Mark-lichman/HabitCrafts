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
  double _lowerValue = 0;
  double _upperValue = 5;
  double _value = 0;

  ValueNotifier<List<ui.Image?>> imageNotifier =
      ValueNotifier<List<ui.Image?>>([]);
  late Iterator<String> emojiIterator;

  List<String> emojisUrls = [
    'https://firebasestorage.googleapis.com/v0/b/tinyhabits-86bcc.appspot.com/o/cms_uploads%2Ffeelings%2F1711136417669000%2Femoji_1.png?alt=media&token=35373c42-ba7d-4bed-8217-cca8d21f65fb',
    'https://firebasestorage.googleapis.com/v0/b/tinyhabits-86bcc.appspot.com/o/cms_uploads%2Ffeelings%2F1711136425365000%2Femoji_2.png?alt=media&token=b2423a7f-f631-4b08-8305-e95383d2c3fe',
    'https://firebasestorage.googleapis.com/v0/b/tinyhabits-86bcc.appspot.com/o/cms_uploads%2Ffeelings%2F1711136432340000%2Femoji_3.png?alt=media&token=fdf70634-bd25-409f-941b-2d8f5f8de5bf',
    'https://firebasestorage.googleapis.com/v0/b/tinyhabits-86bcc.appspot.com/o/cms_uploads%2Ffeelings%2F1711136439394000%2Femoji_4.png?alt=media&token=94a00c01-ba8e-4635-87da-34d7e02c36be',
    'https://firebasestorage.googleapis.com/v0/b/tinyhabits-86bcc.appspot.com/o/cms_uploads%2Ffeelings%2F1711136447121000%2Femoji_5.png?alt=media&token=e88ebeb6-0e8c-4868-a01e-295077b45f17',
  ];

  @override
  void initState() {
    super.initState();

    emojiIterator = emojisUrls.iterator;
    emojiIterator.moveNext();
    getImage(emojiIterator.current);
  }

  getImage(String url) {
    NetworkImage networkImage = NetworkImage(url);
    ImageStream imageStream = networkImage.resolve(ImageConfiguration.empty);
    ImageStreamListener imageStreamListener =
        ImageStreamListener((imageInfo, synchronousCall) {
      imageNotifier.value.add(imageInfo.image);
      if (emojiIterator.moveNext()) {
        getImage(emojiIterator.current);
        setState(() {});
      }
    });
    imageStream.addListener(imageStreamListener);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 0, left: 20, right: 20),
      alignment: Alignment.centerLeft,
      child: ValueListenableBuilder<List<ui.Image?>>(
        builder: (BuildContext context, List<ui.Image?> value, Widget? child) {
          // This builder will only get called when the _counter
          // is updated.
          if (value.isNotEmpty) {
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Color(0xff2A405D),
                inactiveTrackColor: Color(0xff2A405D),
                trackHeight: 10.0,
                thumbShape: SliderThumbImage(value[_value.toInt()]),
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
            );
          } else
            return Container();
        },
        valueListenable: imageNotifier,
        // The child parameter is most helpful if the child is
        // expensive to build and does not depend on the value from
        // the notifier.
        child: const Padding(
          padding: EdgeInsets.all(10.0),
          child: SizedBox(
            width: 40,
            height: 40,
            child: FlutterLogo(size: 40),
          ),
        ),
      ),
    );
  }
}

class SliderThumbImage extends SliderComponentShape {
  final ui.Image? image;

  SliderThumbImage(this.image);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(0, 0);
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
    print(value);
    if (image != null) {
      final canvas = context.canvas;
      final imageWidth = image!.width;
      final imageHeight = image!.height;

      Offset imageOffset = Offset(
        center.dx - (imageWidth / 2),
        center.dy - (imageHeight / 2),
      );

      Paint paint = Paint()..filterQuality = FilterQuality.high;

      canvas.drawImage(image!, imageOffset, paint);
      // paintImage(
      //     canvas: canvas,
      //     rect: Rect.fromLTWH(0, 0, 20, 20),
      //     image: image!,
      //     fit: BoxFit.scaleDown,
      //     repeat: ImageRepeat.noRepeat,
      //     scale: 1.0,
      //     alignment: Alignment.center,
      //     flipHorizontally: false,
      //     filterQuality: FilterQuality.high);
    }
  }
}
