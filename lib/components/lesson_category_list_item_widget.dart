import '/backend/backend.dart';
import '/components/library_list_item/library_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'lesson_category_list_item_model.dart';
export 'lesson_category_list_item_model.dart';

class LessonCategoryListItemWidget extends StatefulWidget {
  const LessonCategoryListItemWidget({
    super.key,
    required this.category,
  });

  final CategoriesRecord? category;

  @override
  State<LessonCategoryListItemWidget> createState() =>
      _LessonCategoryListItemWidgetState();
}

class _LessonCategoryListItemWidgetState
    extends State<LessonCategoryListItemWidget> {
  late LessonCategoryListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LessonCategoryListItemModel());

    _model.expandableExpandableController =
        ExpandableController(initialExpanded: true)
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
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        StreamBuilder<List<ArticlesRecord>>(
          stream: queryArticlesRecord(
            queryBuilder: (articlesRecord) => articlesRecord
                .where(
                  'category',
                  isEqualTo: widget!.category?.reference,
                )
                .orderBy('order'),
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
            List<ArticlesRecord> conditionalBuilderArticlesRecordList =
                snapshot.data!;

            return Builder(
              builder: (context) {
                if (!widget!.category!.hasParentCategory()) {
                  return Builder(
                    builder: (context) {
                      final articlesList =
                          conditionalBuilderArticlesRecordList.toList();

                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        children: List.generate(articlesList.length,
                            (articlesListIndex) {
                          final articlesListItem =
                              articlesList[articlesListIndex];
                          return LibraryListItemWidget(
                            key: Key(
                                'Keys0q_${articlesListIndex}_of_${articlesList.length}'),
                            article: articlesListItem,
                          );
                        }).divide(SizedBox(height: 5.0)),
                      );
                    },
                  );
                } else {
                  return Container(
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondary,
                      borderRadius:
                          BorderRadius.circular(valueOrDefault<double>(
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
                          header: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                10.0, 0.0, 0.0, 0.0),
                            child: Text(
                              valueOrDefault<String>(
                                widget!.category?.title,
                                'title',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                          collapsed: Container(),
                          expanded: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                10.0, 0.0, 10.0, 10.0),
                            child: Builder(
                              builder: (context) {
                                final articles =
                                    conditionalBuilderArticlesRecordList
                                        .toList();

                                return Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: List.generate(articles.length,
                                          (articlesIndex) {
                                    final articlesItem =
                                        articles[articlesIndex];
                                    return InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        logFirebaseEvent(
                                            'LESSON_CATEGORY_LIST_ITEM_Container_mn0d');
                                        logFirebaseEvent(
                                            'Container_navigate_to');

                                        context.pushNamed(
                                          LibraryDetailPageWidget.routeName,
                                          queryParameters: {
                                            'articleRef': serializeParam(
                                              articlesItem.reference,
                                              ParamType.DocumentReference,
                                            ),
                                          }.withoutNulls,
                                        );
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .whiteOverlay,
                                          borderRadius: BorderRadius.circular(
                                              valueOrDefault<double>(
                                            FFAppConstants.borderRadius,
                                            0.0,
                                          )),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(10.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  articlesItem.title,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                        fontSize: 12.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  articlesItem.description,
                                                  maxLines: 1,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                        fontSize: 10.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                      .divide(SizedBox(height: 5.0))
                                      .addToStart(SizedBox(height: 5.0)),
                                );
                              },
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
            );
          },
        ),
      ],
    );
  }
}
