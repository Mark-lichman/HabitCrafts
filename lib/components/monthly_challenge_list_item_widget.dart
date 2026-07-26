import '/backend/backend.dart';
import '/components/habit_components/single_unactive_habit_list_item/single_unactive_habit_list_item_widget.dart';
import '/components/webinar_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'monthly_challenge_list_item_model.dart';
export 'monthly_challenge_list_item_model.dart';

class MonthlyChallengeListItemWidget extends StatefulWidget {
  const MonthlyChallengeListItemWidget({
    super.key,
    required this.monthlyChallenge,
  });

  final MonthlyChallengesRecord? monthlyChallenge;

  @override
  State<MonthlyChallengeListItemWidget> createState() =>
      _MonthlyChallengeListItemWidgetState();
}

class _MonthlyChallengeListItemWidgetState
    extends State<MonthlyChallengeListItemWidget> {
  late MonthlyChallengeListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MonthlyChallengeListItemModel());

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
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).whiteOverlay,
        borderRadius: BorderRadius.circular(valueOrDefault<double>(
          FFAppConstants.borderRadius,
          0.0,
        )),
      ),
      child: Align(
        alignment: AlignmentDirectional(-1.0, 0.0),
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional(-1.0, 0.0),
                child: Text(
                  valueOrDefault<String>(
                    widget!.monthlyChallenge?.title,
                    'title',
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).accent1,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ),
              Text(
                valueOrDefault<String>(
                  widget!.monthlyChallenge?.description,
                  'description',
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).alternate,
                      fontSize: 12.0,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 0.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(valueOrDefault<double>(
                      FFAppConstants.borderRadius,
                      0.0,
                    )),
                  ),
                  child: Builder(
                    builder: (context) {
                      final habits =
                          widget!.monthlyChallenge?.habits?.toList() ?? [];

                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        children: List.generate(habits.length, (habitsIndex) {
                          final habitsItem = habits[habitsIndex];
                          return StreamBuilder<HabitsRecord>(
                            stream: HabitsRecord.getDocument(habitsItem),
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

                              final singleUnactiveHabitListItemHabitsRecord =
                                  snapshot.data!;

                              return SingleUnactiveHabitListItemWidget(
                                key: Key(
                                    'Keyynb_${habitsIndex}_of_${habits.length}'),
                                habit: singleUnactiveHabitListItemHabitsRecord,
                              );
                            },
                          );
                        })
                            .divide(SizedBox(height: 5.0))
                            .addToEnd(SizedBox(height: 5.0)),
                      );
                    },
                  ),
                ),
              ),
              if (widget!.monthlyChallenge!.webinars.length > 0)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                  child: Text(
                    'Webinars',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).tertiary,
                          fontSize: 10.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w500,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
                ),
              Container(
                width: double.infinity,
                height: 1.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).whiteOverlay,
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 0.0),
                child: Builder(
                  builder: (context) {
                    final webinars =
                        widget!.monthlyChallenge?.webinars?.toList() ?? [];

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(webinars.length, (webinarsIndex) {
                        final webinarsItem = webinars[webinarsIndex];
                        return StreamBuilder<WebinarsRecord>(
                          stream: WebinarsRecord.getDocument(webinarsItem),
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

                            final containerWebinarsRecord = snapshot.data!;

                            return Container(
                              width: double.infinity,
                              height: 100.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).secondary,
                                borderRadius: BorderRadius.circular(
                                    valueOrDefault<double>(
                                  FFAppConstants.borderRadius,
                                  0.0,
                                )),
                              ),
                              child: WebinarListItemWidget(
                                key: Key(
                                    'Key6ht_${webinarsIndex}_of_${webinars.length}'),
                                webinar: containerWebinarsRecord,
                              ),
                            );
                          },
                        );
                      }).divide(SizedBox(height: 5.0)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
