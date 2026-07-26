import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'time_picker_component_model.dart';
export 'time_picker_component_model.dart';

class TimePickerComponentWidget extends StatefulWidget {
  const TimePickerComponentWidget({super.key});

  @override
  State<TimePickerComponentWidget> createState() =>
      _TimePickerComponentWidgetState();
}

class _TimePickerComponentWidgetState extends State<TimePickerComponentWidget> {
  late TimePickerComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TimePickerComponentModel());

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
      height: 100.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Builder(
            builder: (context) {
              final hours = functions.hours().toList();

              return Container(
                width: 50.0,
                height: 180.0,
                child: CarouselSlider.builder(
                  itemCount: hours.length,
                  itemBuilder: (context, hoursIndex, _) {
                    final hoursItem = hours[hoursIndex];
                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          hoursItem.toString(),
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
                    );
                  },
                  carouselController: _model.carouselController1 ??=
                      CarouselSliderController(),
                  options: CarouselOptions(
                    initialPage: max(0, min(1, hours.length - 1)),
                    viewportFraction: 0.5,
                    disableCenter: true,
                    enlargeCenterPage: true,
                    enlargeFactor: 0.25,
                    enableInfiniteScroll: false,
                    scrollDirection: Axis.vertical,
                    autoPlay: false,
                    onPageChanged: (index, _) =>
                        _model.carouselCurrentIndex1 = index,
                  ),
                ),
              );
            },
          ),
          Text(
            ':',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.poppins(
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
          Builder(
            builder: (context) {
              final minutes = functions.minutes().toList();

              return Container(
                width: 50.0,
                height: 180.0,
                child: CarouselSlider.builder(
                  itemCount: minutes.length,
                  itemBuilder: (context, minutesIndex, _) {
                    final minutesItem = minutes[minutesIndex];
                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          minutesItem.toString(),
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
                    );
                  },
                  carouselController: _model.carouselController2 ??=
                      CarouselSliderController(),
                  options: CarouselOptions(
                    initialPage: max(0, min(1, minutes.length - 1)),
                    viewportFraction: 0.5,
                    disableCenter: true,
                    enlargeCenterPage: true,
                    enlargeFactor: 0.25,
                    enableInfiniteScroll: false,
                    scrollDirection: Axis.vertical,
                    autoPlay: false,
                    onPageChanged: (index, _) =>
                        _model.carouselCurrentIndex2 = index,
                  ),
                ),
              );
            },
          ),
          Container(
            width: 50.0,
            height: 180.0,
            child: CarouselSlider(
              items: [
                Text(
                  'am',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
                Text(
                  'pm',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ],
              carouselController: _model.carouselController3 ??=
                  CarouselSliderController(),
              options: CarouselOptions(
                initialPage: 1,
                viewportFraction: 0.5,
                disableCenter: true,
                enlargeCenterPage: true,
                enlargeFactor: 0.25,
                enableInfiniteScroll: false,
                scrollDirection: Axis.vertical,
                autoPlay: false,
                onPageChanged: (index, _) =>
                    _model.carouselCurrentIndex3 = index,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
