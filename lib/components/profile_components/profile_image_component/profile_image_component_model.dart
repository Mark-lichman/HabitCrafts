import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/components/profile_components/profile_preview_component/profile_preview_component_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:math';
import 'dart:ui';
import 'profile_image_component_widget.dart' show ProfileImageComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class ProfileImageComponentModel
    extends FlutterFlowModel<ProfileImageComponentWidget> {
  ///  Local state fields for this component.

  bool imageIsUploading = false;

  ///  State fields for stateful widgets in this component.

  bool isDataUploading_uploadDataKep = false;
  FFUploadedFile uploadedLocalFile_uploadDataKep =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadDataKep = '';

  // Model for userIcon component.
  late UserIconModel userIconModel;

  @override
  void initState(BuildContext context) {
    userIconModel = createModel(context, () => UserIconModel());
  }

  @override
  void dispose() {
    userIconModel.dispose();
  }
}
