import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'emojipicker_model.dart';
export 'emojipicker_model.dart';

class EmojipickerWidget extends StatefulWidget {
  const EmojipickerWidget({
    super.key,
    required this.emojiSelected,
  });

  final Future Function(String emoji)? emojiSelected;

  @override
  State<EmojipickerWidget> createState() => _EmojipickerWidgetState();
}

class _EmojipickerWidgetState extends State<EmojipickerWidget> {
  late EmojipickerModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EmojipickerModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200.0,
      decoration: BoxDecoration(),
      child: Container(
        width: double.infinity,
        height: 200.0,
        child: custom_widgets.SelectEmojiWidget(
          width: double.infinity,
          height: 200.0,
          emojiSelected: (emoji) async {
            logFirebaseEvent('EMOJIPICKER_Container_nfoeq4w7_CALLBACK');
            logFirebaseEvent('SelectEmojiWidget_execute_callback');
            await widget.emojiSelected?.call(
              emoji!,
            );
            logFirebaseEvent('SelectEmojiWidget_bottom_sheet');
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
