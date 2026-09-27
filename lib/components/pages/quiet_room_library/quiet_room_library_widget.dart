// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Library in Quiet Room. A rebuild rather than a re-skin, for a measured reason: the
// generated library_page_widget.dart is 1,042 lines that reference the theme FOUR times.
// Its colours are hardcoded, so swapping tokens underneath changes essentially nothing.
//
// 🚨 THERE IS NO ARTBOARD FOR THIS SCREEN. The canvas carries ClientDay / ClientNight for
// Today and the coach boards; Library, Progress and Profile were never drawn. So this
// applies the direction's RULES rather than copying a picture: canvas ground (a content
// screen is not the hero surface [§4.8]), surface cards with a hairline, no shadow at
// rest [§4.3], Fraunces for the page title and Schibsted Grotesk for everything else.
// If an artboard appears later, it wins over this.
//
// The bundled Japanese vocabulary is surfaced here as a first-class entry, because a
// library that omits the only content actually shipped with the app is a library in name
// only.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/quiet_room.dart';
import '/components/pages/library_detail_page/library_detail_page_widget.dart';
import '/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart';

class QuietRoomLibraryWidget extends StatefulWidget {
  const QuietRoomLibraryWidget({super.key});

  static String routeName = 'quietRoomLibrary';
  static String routePath = '/quietRoomLibrary';

  @override
  State<QuietRoomLibraryWidget> createState() => _QuietRoomLibraryWidgetState();
}

class _QuietRoomLibraryWidgetState extends State<QuietRoomLibraryWidget> {
  int _tab = 0; // 0 lessons, 1 resources
  String _query = '';
  Map<String, dynamic>? _jp;

  @override
  void initState() {
    super.initState();
    _loadJp();
  }

  Future<void> _loadJp() async {
    try {
      final raw = await rootBundle.loadString('assets/lessons/jp_lessons.json');
      if (mounted)
        setState(() => _jp = json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      // One absent card, not a broken screen. Bounded and deliberate.
    }
  }

  bool _matches(String? a, String? b) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (a ?? '').toLowerCase().contains(q) ||
        (b ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Library',
                    style: GoogleFonts.fraunces(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 26 * -0.015,
                      height: 1.15,
                      color: t.inkStrong,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _search(t),
                  const SizedBox(height: 14),
                  Row(children: [
                    _tabChip(t, 'Lessons', 0),
                    const SizedBox(width: 8),
                    _tabChip(t, 'Resources', 1),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _tab == 0 ? _lessons(t) : _resources(t)),
          ],
        ),
      ),
    );
  }

  Widget _search(QuietRoomTokens t) => TextField(
        onChanged: (v) => setState(() => _query = v.trim()),
        style: GoogleFonts.schibstedGrotesk(fontSize: 15, color: t.ink),
        cursorColor: t.brand600,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle:
              GoogleFonts.schibstedGrotesk(fontSize: 15, color: t.inkSubtle),
          prefixIcon: Icon(Icons.search, size: 20, color: t.inkMuted),
          filled: true,
          fillColor: t.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: t.border, width: 1),
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: t.borderFocus, width: QuietRoomMetrics.strokeFocus),
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
          ),
        ),
      );

  Widget _tabChip(QuietRoomTokens t, String label, int value) {
    final on = _tab == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _tab = value),
        child: Container(
          decoration: BoxDecoration(
            color: on ? t.surfaceTinted : t.surface,
            border: Border.all(color: on ? t.brand600 : t.border, width: 1),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Text(label,
              style: GoogleFonts.schibstedGrotesk(
                fontSize: 13.5,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                color: on ? t.brand600 : t.inkMuted,
              )),
        ),
      ),
    );
  }

  Widget _lessons(QuietRoomTokens t) {
    return StreamBuilder<List<LessonsRecord>>(
      stream: queryLessonsRecord(queryBuilder: (q) => q.orderBy('order')),
      builder: (context, snapshot) {
        final lessons = (snapshot.data ?? const <LessonsRecord>[])
            .where((l) => _matches(l.title, l.description))
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            if (_jp != null &&
                _matches('Japanese vocabulary', 'Minna no Nihongo'))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _jpCard(t),
              ),
            if (!snapshot.hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(t.inkSubtle)),
                  ),
                ),
              )
            else if (lessons.isEmpty && _jp == null)
              _empty(t, 'Nothing here yet.')
            else
              ...lessons.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _row(
                      t,
                      title: l.title,
                      subtitle: l.description,
                      meta: l.articles.isEmpty
                          ? null
                          : '${l.articles.length} '
                              '${l.articles.length == 1 ? 'article' : 'articles'}',
                      onTap: null, // lesson detail opens from its articles
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget _resources(QuietRoomTokens t) {
    return StreamBuilder<List<ArticlesRecord>>(
      stream: queryArticlesRecord(queryBuilder: (q) => q.orderBy('order')),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(t.inkSubtle)),
            ),
          );
        }
        final articles = snapshot.data!
            .where((a) => _matches(a.title, a.description))
            .toList();
        if (articles.isEmpty) {
          return _empty(t,
              _query.isEmpty ? 'No resources yet.' : 'Nothing matches that.');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: articles
              .map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _row(
                      t,
                      title: a.title.isEmpty ? a.pageTitle : a.title,
                      subtitle: a.description,
                      meta: a.videoLink.isNotEmpty ? 'Video' : null,
                      onTap: () => context.pushNamed(
                        LibraryDetailPageWidget.routeName,
                        queryParameters: {
                          'articleRef': serializeParam(
                              a.reference, ParamType.DocumentReference),
                        }.withoutNulls,
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  /// The vocabulary that actually ships with the app.
  Widget _jpCard(QuietRoomTokens t) {
    final lessons = (_jp!['lessons'] as List?) ?? const [];
    final words = _jp!['itemCount'] ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuietRoomLessonWidget()),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: t.surfaceTinted,
            border: Border.all(color: t.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Japanese vocabulary',
                        style: GoogleFonts.schibstedGrotesk(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: t.inkStrong)),
                    const SizedBox(height: 4),
                    Text(
                      '${_jp!['course']} · ${lessons.length} lessons · $words words',
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 12.5, color: t.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: t.brand600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    QuietRoomTokens t, {
    required String title,
    String? subtitle,
    String? meta,
    VoidCallback? onTap,
  }) {
    final card = Container(
      constraints: const BoxConstraints(minHeight: QuietRoomMetrics.targetMin),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.isEmpty ? 'Untitled' : title,
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: t.inkStrong)),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 12.5, height: 1.35, color: t.inkMuted)),
                ],
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(meta,
                      style: GoogleFonts.schibstedGrotesk(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 11.5 * 0.04,
                          color: t.inkSubtle)),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 18, color: t.brand600),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
          borderRadius: BorderRadius.circular(12), onTap: onTap, child: card),
    );
  }

  Widget _empty(QuietRoomTokens t, String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(message,
              style: GoogleFonts.schibstedGrotesk(
                  fontSize: 14, color: t.inkMuted)),
        ),
      );
}
