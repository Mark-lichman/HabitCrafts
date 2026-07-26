import '/backend/backend.dart';
import '/components/habit_components/single_unactive_habit_list_item/single_unactive_habit_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'habit_articles_group_list_item_model.dart';
export 'habit_articles_group_list_item_model.dart';

class HabitArticlesGroupListItemWidget extends StatefulWidget {
  const HabitArticlesGroupListItemWidget({
    super.key,
    required this.article,
  });

  final ArticlesRecord? article;

  @override
  State<HabitArticlesGroupListItemWidget> createState() =>
      _HabitArticlesGroupListItemWidgetState();
}

class _HabitArticlesGroupListItemWidgetState
    extends State<HabitArticlesGroupListItemWidget> {
  late HabitArticlesGroupListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HabitArticlesGroupListItemModel());

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
    return StreamBuilder<List<HabitsRecord>>(
      stream: queryHabitsRecord(
        queryBuilder: (habitsRecord) => habitsRecord.where(
          'article',
          isEqualTo: widget!.article?.reference,
        ),
      ),
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
        List<HabitsRecord> containerHabitsRecordList = snapshot.data!;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(),
          child: Builder(
            builder: (context) {
              if (containerHabitsRecordList.length == 1) {
                return wrapWithModel(
                  model: _model.singleUnactiveHabitListItemModel1,
                  updateCallback: () => safeSetState(() {}),
                  child: SingleUnactiveHabitListItemWidget(
                    habit: containerHabitsRecordList.firstOrNull!,
                  ),
                );
              } else {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondary,
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
                        header: Container(
                          width: double.infinity,
                          height: 40.0,
                          decoration: BoxDecoration(),
                          child: Align(
                            alignment: AlignmentDirectional(-1.0, 0.0),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  10.0, 0.0, 0.0, 0.0),
                              child: Text(
                                valueOrDefault<String>(
                                  widget!.article?.title,
                                  'title',
                                ),
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
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
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
                        ),
                        collapsed: Container(
                          width: MediaQuery.sizeOf(context).width * 1.0,
                          height: 0.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 8.0, 0.0, 0.0),
                            child: Text(
                              'Lorem ipsum dolor sit amet, consectetur adipiscing...',
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
                                    color: Color(0x8A000000),
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
                        expanded: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 0.0, 10.0, 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Align(
                                alignment: AlignmentDirectional(-1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 20.0),
                                  child: Text(
                                    valueOrDefault<String>(
                                      widget!.article?.description,
                                      'description',
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: Color(0x8A000000),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final habitsList =
                                      containerHabitsRecordList.toList();

                                  return Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: List.generate(habitsList.length,
                                            (habitsListIndex) {
                                      final habitsListItem =
                                          habitsList[habitsListIndex];
                                      return SingleUnactiveHabitListItemWidget(
                                        key: Key(
                                            'Keyn01_${habitsListIndex}_of_${habitsList.length}'),
                                        habit: habitsListItem,
                                      );
                                    })
                                        .divide(SizedBox(height: 5.0))
                                        .addToEnd(SizedBox(height: 5.0)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        theme: ExpandableThemeData(
                          tapHeaderToExpand: true,
                          tapBodyToExpand: false,
                          tapBodyToCollapse: false,
                          headerAlignment:
                              ExpandablePanelHeaderAlignment.center,
                          hasIcon: true,
                          iconColor: FlutterFlowTheme.of(context).alternate,
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
