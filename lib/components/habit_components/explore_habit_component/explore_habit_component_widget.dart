import '/backend/backend.dart';
import '/components/habit_components/habit_explore_list_item/habit_explore_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';
import 'explore_habit_component_model.dart';
export 'explore_habit_component_model.dart';

class ExploreHabitComponentWidget extends StatefulWidget {
  const ExploreHabitComponentWidget({
    super.key,
    this.articleRef,
    this.categoryRef,
  });

  final DocumentReference? articleRef;
  final DocumentReference? categoryRef;

  @override
  State<ExploreHabitComponentWidget> createState() =>
      _ExploreHabitComponentWidgetState();
}

class _ExploreHabitComponentWidgetState
    extends State<ExploreHabitComponentWidget> {
  late ExploreHabitComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExploreHabitComponentModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (widget!.articleRef == null)
              TextFormField(
                controller: _model.textController,
                focusNode: _model.textFieldFocusNode,
                onChanged: (_) => EasyDebounce.debounce(
                  '_model.textController',
                  Duration(milliseconds: 2000),
                  () async {
                    logFirebaseEvent(
                        'EXPLORE_HABIT_COMPONENT_TextField_mmy0ne');
                    if (_model.textController.text == '') {
                      logFirebaseEvent('TextField_update_component_state');
                      _model.isShowFullList = true;
                      safeSetState(() {});
                    } else {
                      logFirebaseEvent('TextField_update_component_state');
                      _model.isShowFullList = false;
                      safeSetState(() {});
                      logFirebaseEvent('TextField_simple_search');
                      await queryCategoriesRecordOnce()
                          .then(
                            (records) => _model.simpleSearchResults =
                                TextSearch(
                              records
                                  .map(
                                    (record) => TextSearchItem.fromTerms(
                                        record, [record.title!]),
                                  )
                                  .toList(),
                            )
                                    .search(_model.textController.text)
                                    .map((r) => r.object)
                                    .toList(),
                          )
                          .onError((_, __) => _model.simpleSearchResults = [])
                          .whenComplete(() => safeSetState(() {}));
                    }
                  },
                ),
                autofocus: false,
                obscureText: false,
                decoration: InputDecoration(
                  isDense: true,
                  alignLabelWithHint: true,
                  hintText: 'Search',
                  hintStyle: FlutterFlowTheme.of(context).labelMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).tertiary,
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).tertiary,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: FlutterFlowTheme.of(context).tertiary,
                    size: 20.0,
                  ),
                  suffixIcon: _model.textController!.text.isNotEmpty
                      ? InkWell(
                          onTap: () async {
                            _model.textController?.clear();
                            logFirebaseEvent(
                                'EXPLORE_HABIT_COMPONENT_TextField_mmy0ne');
                            if (_model.textController.text == '') {
                              logFirebaseEvent(
                                  'TextField_update_component_state');
                              _model.isShowFullList = true;
                              safeSetState(() {});
                            } else {
                              logFirebaseEvent(
                                  'TextField_update_component_state');
                              _model.isShowFullList = false;
                              safeSetState(() {});
                              logFirebaseEvent('TextField_simple_search');
                              await queryCategoriesRecordOnce()
                                  .then(
                                    (records) => _model.simpleSearchResults =
                                        TextSearch(
                                      records
                                          .map(
                                            (record) =>
                                                TextSearchItem.fromTerms(
                                                    record, [record.title!]),
                                          )
                                          .toList(),
                                    )
                                            .search(_model.textController.text)
                                            .map((r) => r.object)
                                            .toList(),
                                  )
                                  .onError((_, __) =>
                                      _model.simpleSearchResults = [])
                                  .whenComplete(() => safeSetState(() {}));
                            }

                            safeSetState(() {});
                          },
                          child: Icon(
                            Icons.clear,
                            color: FlutterFlowTheme.of(context).tertiary,
                            size: 20.0,
                          ),
                        )
                      : null,
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).alternate,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                cursorColor: FlutterFlowTheme.of(context).tertiary,
                validator: _model.textControllerValidator.asValidator(context),
              ),
            Builder(
              builder: (context) {
                if (widget!.articleRef != null) {
                  return StreamBuilder<ArticlesRecord>(
                    stream: ArticlesRecord.getDocument(widget!.articleRef!),
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

                      final containerArticlesRecord = snapshot.data!;

                      return Container(
                        decoration: BoxDecoration(),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 10.0, 0.0, 0.0),
                          child: StreamBuilder<CategoriesRecord>(
                            stream: CategoriesRecord.getDocument(
                                widget!.categoryRef!),
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

                              final habitExploreListItemCategoriesRecord =
                                  snapshot.data!;

                              return wrapWithModel(
                                model: _model.habitExploreListItemModel1,
                                updateCallback: () => safeSetState(() {}),
                                child: HabitExploreListItemWidget(
                                  category:
                                      habitExploreListItemCategoriesRecord,
                                  article: containerArticlesRecord,
                                  isExpanded: false,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Builder(
                    builder: (context) {
                      if (_model.isShowFullList) {
                        return StreamBuilder<List<CategoriesRecord>>(
                          stream: queryCategoriesRecord(
                            queryBuilder: (categoriesRecord) => categoriesRecord
                                .where(
                                  'isLesson',
                                  isEqualTo: false,
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
                            List<CategoriesRecord>
                                containerCategoriesRecordList = snapshot.data!;

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 10.0, 0.0, 0.0),
                                child: Builder(
                                  builder: (context) {
                                    final containerVar =
                                        containerCategoriesRecordList
                                            .where((e) =>
                                                e.parentCategory ==
                                                FFAppState().noParentCategory)
                                            .toList();

                                    return Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children:
                                          List.generate(containerVar.length,
                                              (containerVarIndex) {
                                        final containerVarItem =
                                            containerVar[containerVarIndex];
                                        return Container(
                                          decoration: BoxDecoration(),
                                          child: HabitExploreListItemWidget(
                                            key: Key(
                                                'Key1kg_${containerVarIndex}_of_${containerVar.length}'),
                                            category: containerVarItem,
                                          ),
                                        );
                                      }).divide(SizedBox(height: 5.0)),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        return Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 10.0, 0.0, 0.0),
                          child: Builder(
                            builder: (context) {
                              final searchResults =
                                  _model.simpleSearchResults.toList();

                              return Column(
                                mainAxisSize: MainAxisSize.max,
                                children: List.generate(searchResults.length,
                                    (searchResultsIndex) {
                                  final searchResultsItem =
                                      searchResults[searchResultsIndex];
                                  return Container(
                                    decoration: BoxDecoration(),
                                    child: HabitExploreListItemWidget(
                                      key: Key(
                                          'Keyql7_${searchResultsIndex}_of_${searchResults.length}'),
                                      category: searchResultsItem,
                                    ),
                                  );
                                }).divide(SizedBox(height: 5.0)),
                              );
                            },
                          ),
                        );
                      }
                    },
                  );
                }
              },
            ),
          ].addToEnd(SizedBox(height: 120.0)),
        ),
      ),
    );
  }
}
