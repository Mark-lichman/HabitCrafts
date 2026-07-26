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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'profile_image_component_model.dart';
export 'profile_image_component_model.dart';

class ProfileImageComponentWidget extends StatefulWidget {
  const ProfileImageComponentWidget({super.key});

  @override
  State<ProfileImageComponentWidget> createState() =>
      _ProfileImageComponentWidgetState();
}

class _ProfileImageComponentWidgetState
    extends State<ProfileImageComponentWidget> with TickerProviderStateMixin {
  late ProfileImageComponentModel _model;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileImageComponentModel());

    animationsMap.addAll({
      'progressBarOnActionTriggerAnimation': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: true,
        effectsBuilder: () => [
          RotateEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'progressBarOnPageLoadAnimation': AnimationInfo(
        loop: true,
        trigger: AnimationTrigger.onPageLoad,
        applyInitialState: true,
        effectsBuilder: () => [
          RotateEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
    });
    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
    );

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
      height: 165.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).grayLight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  logFirebaseEvent('PROFILE_IMAGE_COMPONENT_Container_t5q9a8');
                  logFirebaseEvent('Container_update_component_state');
                  _model.imageIsUploading = true;
                  safeSetState(() {});
                  logFirebaseEvent('Container_upload_media_to_firebase');
                  final selectedMedia = await selectMediaWithSourceBottomSheet(
                    context: context,
                    allowPhoto: true,
                  );
                  if (selectedMedia != null &&
                      selectedMedia.every(
                          (m) => validateFileFormat(m.storagePath, context))) {
                    safeSetState(
                        () => _model.isDataUploading_uploadDataKep = true);
                    var selectedUploadedFiles = <FFUploadedFile>[];

                    var downloadUrls = <String>[];
                    try {
                      selectedUploadedFiles = selectedMedia
                          .map((m) => FFUploadedFile(
                                name: m.storagePath.split('/').last,
                                bytes: m.bytes,
                                height: m.dimensions?.height,
                                width: m.dimensions?.width,
                                blurHash: m.blurHash,
                                originalFilename: m.originalFilename,
                              ))
                          .toList();

                      downloadUrls = (await Future.wait(
                        selectedMedia.map(
                          (m) async => await uploadData(m.storagePath, m.bytes),
                        ),
                      ))
                          .where((u) => u != null)
                          .map((u) => u!)
                          .toList();
                    } finally {
                      _model.isDataUploading_uploadDataKep = false;
                    }
                    if (selectedUploadedFiles.length == selectedMedia.length &&
                        downloadUrls.length == selectedMedia.length) {
                      safeSetState(() {
                        _model.uploadedLocalFile_uploadDataKep =
                            selectedUploadedFiles.first;
                        _model.uploadedFileUrl_uploadDataKep =
                            downloadUrls.first;
                      });
                    } else {
                      safeSetState(() {});
                      return;
                    }
                  }

                  logFirebaseEvent('Container_backend_call');

                  await currentUserReference!.update(createUsersRecordData(
                    photoUrl: _model.uploadedFileUrl_uploadDataKep,
                  ));
                  logFirebaseEvent('Container_update_component_state');
                  _model.imageIsUploading = false;
                  safeSetState(() {});
                },
                child: Container(
                  width: 80.0,
                  height: 80.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    shape: BoxShape.circle,
                  ),
                  child: StreamBuilder<UsersRecord>(
                    stream: UsersRecord.getDocument(currentUserReference!),
                    builder: (context, snapshot) {
                      // Customize what your widget looks like when it's loading.
                      if (!snapshot.hasData) {
                        return Center(
                          child: SizedBox(
                            width: 40.0,
                            height: 40.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        );
                      }

                      final userIconUsersRecord = snapshot.data!;

                      return wrapWithModel(
                        model: _model.userIconModel,
                        updateCallback: () => safeSetState(() {}),
                        child: UserIconWidget(
                          width: 80,
                          height: 80,
                          userDoc: userIconUsersRecord,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_model.imageIsUploading)
                Container(
                  width: 80.0,
                  height: 80.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: CircularPercentIndicator(
                      percent: 0.5,
                      radius: 25.0,
                      lineWidth: 2.0,
                      animation: true,
                      animateFromLastPercent: true,
                      progressColor: FlutterFlowTheme.of(context).primary,
                      backgroundColor: FlutterFlowTheme.of(context).accent4,
                    )
                        .animateOnPageLoad(
                            animationsMap['progressBarOnPageLoadAnimation']!)
                        .animateOnActionTrigger(
                          animationsMap['progressBarOnActionTriggerAnimation']!,
                        ),
                  ),
                ),
            ],
          ),
          AuthUserStreamWidget(
            builder: (context) => Text(
              currentUserDisplayName,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).alternate,
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ),
          FFButtonWidget(
            onPressed: () async {
              logFirebaseEvent('PROFILE_IMAGE_COMPONENT_PREVIEW_PROFILE_');
              logFirebaseEvent('Button_bottom_sheet');
              await showModalBottomSheet(
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                enableDrag: false,
                context: context,
                builder: (context) {
                  return Padding(
                    padding: MediaQuery.viewInsetsOf(context),
                    child: ProfilePreviewComponentWidget(
                      userRef: currentUserReference!,
                    ),
                  );
                },
              ).then((value) => safeSetState(() {}));
            },
            text: 'Preview Profile',
            options: FFButtonOptions(
              height: 23.0,
              padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              color: FlutterFlowTheme.of(context).secondary,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.poppins(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: Colors.white,
                    fontSize: 10.0,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
              elevation: 3.0,
              borderSide: BorderSide(
                color: Colors.transparent,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
            showLoadingIndicator: false,
          ),
        ].divide(SizedBox(height: 5.0)),
      ),
    );
  }
}
