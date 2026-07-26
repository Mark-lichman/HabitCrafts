import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'media_selector_component_model.dart';
export 'media_selector_component_model.dart';

class MediaSelectorComponentWidget extends StatefulWidget {
  const MediaSelectorComponentWidget({super.key});

  @override
  State<MediaSelectorComponentWidget> createState() =>
      _MediaSelectorComponentWidgetState();
}

class _MediaSelectorComponentWidgetState
    extends State<MediaSelectorComponentWidget> {
  late MediaSelectorComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MediaSelectorComponentModel());

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
      height: 230.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          FFButtonWidget(
            onPressed: () async {
              logFirebaseEvent('MEDIA_SELECTOR_COMPONENT_CAPTURE_IMAGE_B');
              logFirebaseEvent('Button_upload_media_to_firebase');
              final selectedMedia = await selectMedia(
                multiImage: false,
              );
              if (selectedMedia != null &&
                  selectedMedia.every(
                      (m) => validateFileFormat(m.storagePath, context))) {
                safeSetState(
                    () => _model.isDataUploading_uploadDataJub4 = true);
                var selectedUploadedFiles = <FFUploadedFile>[];

                var downloadUrls = <String>[];
                try {
                  showUploadMessage(
                    context,
                    'Uploading file...',
                    showLoading: true,
                  );
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
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _model.isDataUploading_uploadDataJub4 = false;
                }
                if (selectedUploadedFiles.length == selectedMedia.length &&
                    downloadUrls.length == selectedMedia.length) {
                  safeSetState(() {
                    _model.uploadedLocalFile_uploadDataJub4 =
                        selectedUploadedFiles.first;
                    _model.uploadedFileUrl_uploadDataJub4 = downloadUrls.first;
                  });
                  showUploadMessage(context, 'Success!');
                } else {
                  safeSetState(() {});
                  showUploadMessage(context, 'Failed to upload data');
                  return;
                }
              }

              logFirebaseEvent('Button_bottom_sheet');
              Navigator.pop(context, _model.uploadedFileUrl_uploadDataJub4);
            },
            text: 'Capture Image',
            options: FFButtonOptions(
              height: 40.0,
              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              color: Colors.transparent,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.poppins(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondary,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
              elevation: 0.0,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          FFButtonWidget(
            onPressed: () async {
              logFirebaseEvent('MEDIA_SELECTOR_COMPONENT_CAPTURE_VIDEO_B');
              logFirebaseEvent('Button_upload_media_to_firebase');
              final selectedMedia = await selectMedia(
                isVideo: true,
                multiImage: false,
              );
              if (selectedMedia != null &&
                  selectedMedia.every(
                      (m) => validateFileFormat(m.storagePath, context))) {
                safeSetState(
                    () => _model.isDataUploading_uploadDataJub5 = true);
                var selectedUploadedFiles = <FFUploadedFile>[];

                var downloadUrls = <String>[];
                try {
                  showUploadMessage(
                    context,
                    'Uploading file...',
                    showLoading: true,
                  );
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
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _model.isDataUploading_uploadDataJub5 = false;
                }
                if (selectedUploadedFiles.length == selectedMedia.length &&
                    downloadUrls.length == selectedMedia.length) {
                  safeSetState(() {
                    _model.uploadedLocalFile_uploadDataJub5 =
                        selectedUploadedFiles.first;
                    _model.uploadedFileUrl_uploadDataJub5 = downloadUrls.first;
                  });
                  showUploadMessage(context, 'Success!');
                } else {
                  safeSetState(() {});
                  showUploadMessage(context, 'Failed to upload data');
                  return;
                }
              }

              logFirebaseEvent('Button_bottom_sheet');
              Navigator.pop(context, _model.uploadedFileUrl_uploadDataJub5);
            },
            text: 'Capture Video',
            options: FFButtonOptions(
              height: 40.0,
              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              color: Colors.transparent,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.poppins(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondary,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
              elevation: 0.0,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          FFButtonWidget(
            onPressed: () async {
              logFirebaseEvent('MEDIA_SELECTOR_COMPONENT_GALLERY_IMAGE_B');
              logFirebaseEvent('Button_upload_media_to_firebase');
              final selectedMedia = await selectMedia(
                mediaSource: MediaSource.photoGallery,
                multiImage: false,
              );
              if (selectedMedia != null &&
                  selectedMedia.every(
                      (m) => validateFileFormat(m.storagePath, context))) {
                safeSetState(
                    () => _model.isDataUploading_uploadDataJub6 = true);
                var selectedUploadedFiles = <FFUploadedFile>[];

                var downloadUrls = <String>[];
                try {
                  showUploadMessage(
                    context,
                    'Uploading file...',
                    showLoading: true,
                  );
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
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _model.isDataUploading_uploadDataJub6 = false;
                }
                if (selectedUploadedFiles.length == selectedMedia.length &&
                    downloadUrls.length == selectedMedia.length) {
                  safeSetState(() {
                    _model.uploadedLocalFile_uploadDataJub6 =
                        selectedUploadedFiles.first;
                    _model.uploadedFileUrl_uploadDataJub6 = downloadUrls.first;
                  });
                  showUploadMessage(context, 'Success!');
                } else {
                  safeSetState(() {});
                  showUploadMessage(context, 'Failed to upload data');
                  return;
                }
              }

              logFirebaseEvent('Button_bottom_sheet');
              Navigator.pop(context, _model.uploadedFileUrl_uploadDataJub6);
            },
            text: 'Gallery Image',
            options: FFButtonOptions(
              height: 40.0,
              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              color: Colors.transparent,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.poppins(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondary,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
              elevation: 0.0,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          FFButtonWidget(
            onPressed: () async {
              logFirebaseEvent('MEDIA_SELECTOR_COMPONENT_GALLERY_VIDEO_B');
              logFirebaseEvent('Button_upload_media_to_firebase');
              final selectedMedia = await selectMedia(
                isVideo: true,
                mediaSource: MediaSource.videoGallery,
                multiImage: false,
              );
              if (selectedMedia != null &&
                  selectedMedia.every(
                      (m) => validateFileFormat(m.storagePath, context))) {
                safeSetState(
                    () => _model.isDataUploading_uploadDataJub7 = true);
                var selectedUploadedFiles = <FFUploadedFile>[];

                var downloadUrls = <String>[];
                try {
                  showUploadMessage(
                    context,
                    'Uploading file...',
                    showLoading: true,
                  );
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
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _model.isDataUploading_uploadDataJub7 = false;
                }
                if (selectedUploadedFiles.length == selectedMedia.length &&
                    downloadUrls.length == selectedMedia.length) {
                  safeSetState(() {
                    _model.uploadedLocalFile_uploadDataJub7 =
                        selectedUploadedFiles.first;
                    _model.uploadedFileUrl_uploadDataJub7 = downloadUrls.first;
                  });
                  showUploadMessage(context, 'Success!');
                } else {
                  safeSetState(() {});
                  showUploadMessage(context, 'Failed to upload data');
                  return;
                }
              }

              logFirebaseEvent('Button_bottom_sheet');
              Navigator.pop(context, _model.uploadedFileUrl_uploadDataJub7);
            },
            text: 'Gallery Video',
            options: FFButtonOptions(
              height: 40.0,
              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              color: Colors.transparent,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.poppins(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondary,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
              elevation: 0.0,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ].divide(SizedBox(height: 6.0)).around(SizedBox(height: 6.0)),
      ),
    );
  }
}
