import '/backend/backend.dart';
import '/components/habit_components/category_list_display/category_list_display_widget.dart';
import '/components/habit_components/habit_articles_group_list_item/habit_articles_group_list_item_widget.dart';
import '/components/habit_components/habit_sub_category_group_list_item/habit_sub_category_group_list_item_widget.dart';
import '/components/habit_components/single_unactive_habit_list_item/single_unactive_habit_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'habit_explore_list_item_model.dart';
export 'habit_explore_list_item_model.dart';

class HabitExploreListItemWidget extends StatefulWidget {
  const HabitExploreListItemWidget({
    super.key,
    this.category,
    this.article,
    this.isExpanded,
  });

  final CategoriesRecord? category;
  final ArticlesRecord? article;
  final bool? isExpanded;

  @override
  State<HabitExploreListItemWidget> createState() =>
      _HabitExploreListItemWidgetState();
}

class _HabitExploreListItemWidgetState
    extends State<HabitExploreListItemWidget> {
  late HabitExploreListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HabitExploreListItemModel());

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
    return Builder(
      builder: (context) {
        if (widget!.category != null) {
          return StreamBuilder<List<ArticlesRecord>>(
            stream: queryArticlesRecord(
              queryBuilder: (articlesRecord) => articlesRecord.where(
                'category',
                isEqualTo: widget!.category?.reference,
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
              List<ArticlesRecord> expandableArticlesRecordList =
                  snapshot.data!;

              return Container(
                width: double.infinity,
                color: Colors.transparent,
                child: ExpandableNotifier(
                  controller: _model.expandableExpandableController,
                  child: ExpandablePanel(
                    header: wrapWithModel(
                      model: _model.categoryListDisplayModel,
                      updateCallback: () => safeSetState(() {}),
                      child: CategoryListDisplayWidget(
                        category: widget!.category!,
                      ),
                    ),
                    collapsed: Container(
                      width: MediaQuery.sizeOf(context).width * 1.0,
                      height: 0.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                        child: Text(
                          'Lorem ipsum dolor sit amet, consectetur adipiscing...',
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
                    expanded: StreamBuilder<List<HabitsRecord>>(
                      stream: queryHabitsRecord(
                        queryBuilder: (habitsRecord) => habitsRecord.where(
                          'category',
                          isEqualTo: widget!.category?.reference,
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
                        List<HabitsRecord> containerHabitsRecordList =
                            snapshot.data!;

                        return Container(
                          decoration: BoxDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 10.0, 0.0, 0.0),
                                child: Text(
                                  '${containerHabitsRecordList.length.toString()} habits',
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
                              Stack(
                                children: [
                                  Align(
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: StreamBuilder<IconsRecord>(
                                      stream: IconsRecord.getDocument(
                                          widget!.category!.icon!),
                                      builder: (context, snapshot) {
                                        // Customize what your widget looks like when it's loading.
                                        if (!snapshot.hasData) {
                                          return Center(
                                            child: SizedBox(
                                              width: 40.0,
                                              height: 40.0,
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        final imageIconsRecord = snapshot.data!;

                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(0.0),
                                          child: CachedNetworkImage(
                                            fadeInDuration:
                                                Duration(milliseconds: 500),
                                            fadeOutDuration:
                                                Duration(milliseconds: 500),
                                            imageUrl: imageIconsRecord.image,
                                            width: double.infinity,
                                            height: (containerHabitsRecordList
                                                        .length *
                                                    (73 + 5))
                                                .toDouble(),
                                            fit: BoxFit.contain,
                                            errorWidget:
                                                (context, error, stackTrace) =>
                                                    Image.asset(
                                              'assets/images/error_image.png',
                                              width: double.infinity,
                                              height: (containerHabitsRecordList
                                                          .length *
                                                      (73 + 5))
                                                  .toDouble(),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (false)
                                    Builder(
                                      builder: (context) {
                                        final articles =
                                            expandableArticlesRecordList
                                                .toList();

                                        return ListView.separated(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          scrollDirection: Axis.vertical,
                                          itemCount: articles.length,
                                          separatorBuilder: (_, __) =>
                                              SizedBox(height: 5.0),
                                          itemBuilder:
                                              (context, articlesIndex) {
                                            final articlesItem =
                                                articles[articlesIndex];
                                            return HabitArticlesGroupListItemWidget(
                                              key: Key(
                                                  'Key05l_${articlesIndex}_of_${articles.length}'),
                                              article: articlesItem,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          final habits =
                                              containerHabitsRecordList
                                                  .toList();

                                          return Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: List.generate(
                                                habits.length, (habitsIndex) {
                                              final habitsItem =
                                                  habits[habitsIndex];
                                              return SingleUnactiveHabitListItemWidget(
                                                key: Key(
                                                    'Keyimm_${habitsIndex}_of_${habits.length}'),
                                                habit: habitsItem,
                                              );
                                            }).divide(SizedBox(height: 5.0)),
                                          );
                                        },
                                      ),
                                      StreamBuilder<List<CategoriesRecord>>(
                                        stream: queryCategoriesRecord(
                                          queryBuilder: (categoriesRecord) =>
                                              categoriesRecord.where(
                                            'parentCategory',
                                            isEqualTo:
                                                widget!.category?.reference,
                                          ),
                                        ),
                                        builder: (context, snapshot) {
                                          // Customize what your widget looks like when it's loading.
                                          if (!snapshot.hasData) {
                                            return Center(
                                              child: SizedBox(
                                                width: 40.0,
                                                height: 40.0,
                                                child:
                                                    CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          List<CategoriesRecord>
                                              columnCategoriesRecordList =
                                              snapshot.data!;

                                          return Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: List.generate(
                                                columnCategoriesRecordList
                                                    .length, (columnIndex) {
                                              final columnCategoriesRecord =
                                                  columnCategoriesRecordList[
                                                      columnIndex];
                                              return HabitSubCategoryGroupListItemWidget(
                                                key: Key(
                                                    'Keyw5w_${columnIndex}_of_${columnCategoriesRecordList.length}'),
                                                category:
                                                    columnCategoriesRecord,
                                              );
                                            }).divide(SizedBox(height: 5.0)),
                                          );
                                        },
                                      ),
                                    ].divide(SizedBox(height: 5.0)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    theme: ExpandableThemeData(
                      tapHeaderToExpand: true,
                      tapBodyToExpand: false,
                      tapBodyToCollapse: false,
                      headerAlignment: ExpandablePanelHeaderAlignment.center,
                      hasIcon: false,
                    ),
                  ),
                ),
              );
            },
          );
        } else if (widget!.article != null) {
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
              List<HabitsRecord> columnHabitsRecordList = snapshot.data!;

              return Column(
                mainAxisSize: MainAxisSize.max,
                children:
                    List.generate(columnHabitsRecordList.length, (columnIndex) {
                  final columnHabitsRecord =
                      columnHabitsRecordList[columnIndex];
                  return SingleUnactiveHabitListItemWidget(
                    key: Key(
                        'Key7uq_${columnIndex}_of_${columnHabitsRecordList.length}'),
                    habit: columnHabitsRecord,
                  );
                }).divide(SizedBox(height: 5.0)).around(SizedBox(height: 5.0)),
              );
            },
          );
        } else {
          return Container(
            width: 100.0,
            height: 0.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
            ),
          );
        }
      },
    );
  }
}
