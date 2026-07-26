// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

Future<String?> selectEmoji(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 200,
          child: EmojiPicker(
            onEmojiSelected: (Category? category, Emoji emoji) {
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
      ),
    ),
  );
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
