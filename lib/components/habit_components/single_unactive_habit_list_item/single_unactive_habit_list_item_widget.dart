import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'single_unactive_habit_list_item_model.dart';
export 'single_unactive_habit_list_item_model.dart';

class SingleUnactiveHabitListItemWidget extends StatefulWidget {
  const SingleUnactiveHabitListItemWidget({
    super.key,
    required this.habit,
  });

  final HabitsRecord? habit;

  @override
  State<SingleUnactiveHabitListItemWidget> createState() =>
      _SingleUnactiveHabitListItemWidgetState();
}

class _SingleUnactiveHabitListItemWidgetState
    extends State<SingleUnactiveHabitListItemWidget> {
  late SingleUnactiveHabitListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SingleUnactiveHabitListItemModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        logFirebaseEvent('SINGLE_UNACTIVE_HABIT_LIST_ITEM_Containe');
        if (widget!.habit!.hasGoal() && (widget!.habit?.goal?.id != '0')) {
          logFirebaseEvent('Container_backend_call');
          _model.goal = await GoalsRecord.getDocumentOnce(widget!.habit!.goal!);
          if (widget!.habit!.hasCategory()) {
            logFirebaseEvent('Container_backend_call');
            _model.category = await CategoriesRecord.getDocumentOnce(
                widget!.habit!.category!);
            logFirebaseEvent('Container_navigate_to');

            context.pushNamed(
              CreateHabitPageWidget.routeName,
              queryParameters: {
                'prefillGoal': serializeParam(
                  _model.goal?.name,
                  ParamType.String,
                ),
                'prefillWhy': serializeParam(
                  widget!.habit?.why,
                  ParamType.String,
                ),
                'prefillPrompt': serializeParam(
                  widget!.habit?.prompt,
                  ParamType.String,
                ),
                'prefillBehavior': serializeParam(
                  widget!.habit?.behavior,
                  ParamType.String,
                ),
                'prefillCelebration': serializeParam(
                  widget!.habit?.celebration,
                  ParamType.String,
                ),
                'prefillGoalIcon': serializeParam(
                  _model.category?.icon,
                  ParamType.DocumentReference,
                ),
              }.withoutNulls,
            );
          } else {
            logFirebaseEvent('Container_navigate_to');

            context.pushNamed(
              CreateHabitPageWidget.routeName,
              queryParameters: {
                'prefillGoal': serializeParam(
                  _model.goal?.name,
                  ParamType.String,
                ),
                'prefillWhy': serializeParam(
                  widget!.habit?.why,
                  ParamType.String,
                ),
                'prefillPrompt': serializeParam(
                  widget!.habit?.prompt,
                  ParamType.String,
                ),
                'prefillBehavior': serializeParam(
                  widget!.habit?.behavior,
                  ParamType.String,
                ),
                'prefillCelebration': serializeParam(
                  widget!.habit?.celebration,
                  ParamType.String,
                ),
              }.withoutNulls,
            );
          }
        } else {
          if (widget!.habit!.hasCategory()) {
            logFirebaseEvent('Container_backend_call');
            _model.category1 = await CategoriesRecord.getDocumentOnce(
                widget!.habit!.category!);
            logFirebaseEvent('Container_navigate_to');

            context.pushNamed(
              CreateHabitPageWidget.routeName,
              queryParameters: {
                'prefillWhy': serializeParam(
                  widget!.habit?.why,
                  ParamType.String,
                ),
                'prefillPrompt': serializeParam(
                  widget!.habit?.prompt,
                  ParamType.String,
                ),
                'prefillBehavior': serializeParam(
                  widget!.habit?.behavior,
                  ParamType.String,
                ),
                'prefillCelebration': serializeParam(
                  widget!.habit?.celebration,
                  ParamType.String,
                ),
                'prefillGoalIcon': serializeParam(
                  _model.category1?.icon,
                  ParamType.DocumentReference,
                ),
              }.withoutNulls,
            );
          } else {
            logFirebaseEvent('Container_navigate_to');

            context.pushNamed(
              CreateHabitPageWidget.routeName,
              queryParameters: {
                'prefillWhy': serializeParam(
                  widget!.habit?.why,
                  ParamType.String,
                ),
                'prefillPrompt': serializeParam(
                  widget!.habit?.prompt,
                  ParamType.String,
                ),
                'prefillBehavior': serializeParam(
                  widget!.habit?.behavior,
                  ParamType.String,
                ),
                'prefillCelebration': serializeParam(
                  widget!.habit?.celebration,
                  ParamType.String,
                ),
              }.withoutNulls,
            );
          }
        }

        safeSetState(() {});
      },
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: 73.0,
        ),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).whiteTransparent10,
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(
                        valueOrDefault<String>(
                          widget!.habit?.behavior,
                          'behavior',
                        ),
                        minFontSize: 8.0,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).alternate,
                              fontSize: 14.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w500,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                      ),
                      if (widget!.habit?.hasPrompt() ?? true)
                        Text(
                          valueOrDefault<String>(
                            widget!.habit?.prompt,
                            'prompt',
                          ),
                          maxLines: 1,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).alternate,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                      if (widget!.habit?.hasCelebration() ?? true)
                        Text(
                          valueOrDefault<String>(
                            widget!.habit?.celebration,
                            'celebration',
                          ),
                          maxLines: 1,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).alternate,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
