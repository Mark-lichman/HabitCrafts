import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'user_icon_model.dart';
export 'user_icon_model.dart';

class UserIconWidget extends StatefulWidget {
  const UserIconWidget({
    super.key,
    required this.userDoc,
    int? width,
    int? height,
  })  : this.width = width ?? 50,
        this.height = height ?? 50;

  final UsersRecord? userDoc;
  final int width;
  final int height;

  @override
  State<UserIconWidget> createState() => _UserIconWidgetState();
}

class _UserIconWidgetState extends State<UserIconWidget> {
  late UserIconModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserIconModel());

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
      width: widget!.width.toDouble(),
      height: widget!.height.toDouble(),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(valueOrDefault<double>(
          widget!.width / 2,
          0.0,
        )),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(valueOrDefault<double>(
          widget!.width / 2,
          0.0,
        )),
        child: Image.network(
          widget!.userDoc!.hasPhotoUrl()
              ? widget!.userDoc!.photoUrl
              : 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/tiny-habits-jf61nl/assets/2hnbxi7qtu55/user_icon.png',
          width: widget!.width.toDouble(),
          height: widget!.height.toDouble(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/error_image.png',
            width: widget!.width.toDouble(),
            height: widget!.height.toDouble(),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
