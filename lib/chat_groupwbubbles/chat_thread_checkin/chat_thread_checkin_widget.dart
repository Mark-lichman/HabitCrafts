import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/chat_groupwbubbles/checkin_display_component/checkin_display_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'chat_thread_checkin_model.dart';
export 'chat_thread_checkin_model.dart';

class ChatThreadCheckinWidget extends StatefulWidget {
  const ChatThreadCheckinWidget({
    super.key,
    required this.checkinRef,
    required this.chatMessage,
  });

  final DocumentReference? checkinRef;
  final ChatMessagesRecord? chatMessage;

  @override
  State<ChatThreadCheckinWidget> createState() =>
      _ChatThreadCheckinWidgetState();
}

class _ChatThreadCheckinWidgetState extends State<ChatThreadCheckinWidget> {
  late ChatThreadCheckinModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadCheckinModel());

    _model.expandableExpandableController =
        ExpandableController(initialExpanded: false)
          ..addListener(() => safeSetState(() {}));
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
      width: MediaQuery.sizeOf(context).width * 0.7,
      decoration: BoxDecoration(
        color: widget!.chatMessage?.user == currentUserReference
            ? FlutterFlowTheme.of(context).messageTextBG
            : FlutterFlowTheme.of(context).tertiary,
        borderRadius: BorderRadius.circular(valueOrDefault<double>(
          FFAppConstants.borderRadius,
          0.0,
        )),
      ),
      child: Container(
        width: double.infinity,
        color: Color(0x00000000),
        child: ExpandableNotifier(
          controller: _model.expandableExpandableController,
          child: ExpandablePanel(
            header: StreamBuilder<CheckinsRecord>(
              stream: CheckinsRecord.getDocument(widget!.checkinRef!),
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

                final rowCheckinsRecord = snapshot.data!;

                return Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 4.0, 0.0),
                        child: Text(
                          valueOrDefault<String>(
                            widget!.chatMessage?.text,
                            'text',
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 12.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                      ),
                    ),
                    if (rowCheckinsRecord.feedback)
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 10.0, 0.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.asset(
                            'assets/images/chat_feedback.png',
                            width: 20.0,
                            height: 20.0,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.asset(
                        'assets/images/habit_icon.png',
                        width: 20.0,
                        height: 20.0,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ].divide(SizedBox(width: 0.0)),
                );
              },
            ),
            collapsed: Container(
              width: MediaQuery.sizeOf(context).width * 1.0,
              height: 0.0,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
              ),
            ),
            expanded: Align(
              alignment: AlignmentDirectional(-1.0, -1.0),
              child: StreamBuilder<CheckinsRecord>(
                stream: CheckinsRecord.getDocument(widget!.checkinRef!),
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

                  final containerCheckinsRecord = snapshot.data!;

                  return Container(
                    width: double.infinity,
                    height: 215.0,
                    decoration: BoxDecoration(
                      color: Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(valueOrDefault<double>(
                          containerCheckinsRecord.user == currentUserReference
                              ? 12.0
                              : 0.0,
                          0.0,
                        )),
                        topRight: Radius.circular(valueOrDefault<double>(
                          containerCheckinsRecord.user == currentUserReference
                              ? 0.0
                              : 12.0,
                          0.0,
                        )),
                        bottomLeft: Radius.circular(12.0),
                        bottomRight: Radius.circular(12.0),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 6.0, 0.0, 0.0),
                          child: Container(
                            width: double.infinity,
                            height: 1.0,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).alternate,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              20.0, 0.0, 0.0, 0.0),
                          child: wrapWithModel(
                            model: _model.checkinDisplayComponentModel,
                            updateCallback: () => safeSetState(() {}),
                            child: CheckinDisplayComponentWidget(
                              checkinRef: containerCheckinsRecord.reference,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            theme: ExpandableThemeData(
              tapHeaderToExpand: true,
              tapBodyToExpand: false,
              tapBodyToCollapse: false,
              headerAlignment: ExpandablePanelHeaderAlignment.center,
              hasIcon: true,
            ),
          ),
        ),
      ),
    );
  }
}
