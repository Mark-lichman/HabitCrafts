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

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class SelectEmojiWidget extends StatefulWidget {
  const SelectEmojiWidget({
    super.key,
    this.width,
    this.height,
    required this.emojiSelected,
  });

  final double? width;
  final double? height;
  final Future Function(String? emoji) emojiSelected;

  @override
  State<SelectEmojiWidget> createState() => _SelectEmojiWidgetState();
}

class _SelectEmojiWidgetState extends State<SelectEmojiWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2), // Match emoji picker background
        borderRadius: BorderRadius.circular(16), // Rounded corners
      ),
      clipBehavior: Clip.antiAlias, // Ensures child respects border radius
      child: SizedBox(
        height: 100,
        child: EmojiPicker(
          onEmojiSelected: (Category? category, Emoji emoji) {
            widget.emojiSelected(emoji.emoji);
            Navigator.of(context).pop(emoji.emoji);
          },
          config: const Config(
            columns: 7,
            emojiSizeMax: 24 * 1.2,
            verticalSpacing: 0,
            horizontalSpacing: 0,
            initCategory: Category.SMILEYS,
            bgColor: Color(0xFFF2F2F2),
            indicatorColor: Colors.blue,
            iconColor: Colors.grey,
            iconColorSelected: Colors.blue,
            backspaceColor: Colors.red,
            recentsLimit: 28,
            noRecents: Text('No Recents'),
            categoryIcons: CategoryIcons(),
            buttonMode: ButtonMode.MATERIAL,
          ),
        ),
      ),
    );
  }
}
