// Tests for the signed-in shell's two Japanese cards (plan 2026-11-02, Task 27, D20, End
// state 14): the Today screen's DAILY LESSON card and the Library's Japanese vocabulary card
// open the Review session, not the word-card screen on a fixed lesson.
//
// Both screens read Firestore, which a widget test cannot open, so each card is pumped on its
// own. The last case checks that each screen builds its card and names the word-card screen
// nowhere, so the card under test is the one the screen shows.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_library/quiet_room_library_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/review_page.dart';
import 'package:habit_craft/components/pages/quiet_room_today/quiet_room_today_widget.dart';

import 'jp_screen_harness.dart';

const String todayFile =
    'lib/components/pages/quiet_room_today/quiet_room_today_widget.dart';
const String libraryFile =
    'lib/components/pages/quiet_room_library/quiet_room_library_widget.dart';

/// Pumps [card] under a router that knows the session route and the word-card route, taps
/// it, and returns which route it pushed.
Future<List<String>> tapUnderRouter(WidgetTester tester, Widget card) async {
  final pushed = <String>[];
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: card)),
    GoRoute(
      name: QuietRoomReviewPage.routeName,
      path: QuietRoomReviewPage.routePath,
      builder: (_, __) {
        pushed.add(QuietRoomReviewPage.routeName);
        return const Text('the session');
      },
    ),
    GoRoute(
      name: QuietRoomLessonWidget.routeName,
      path: QuietRoomLessonWidget.routePath,
      builder: (_, __) {
        pushed.add(QuietRoomLessonWidget.routeName);
        return const Text('the word cards');
      },
    ),
  ]);
  addTearDown(router.dispose);
  await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
  await tester.tap(
      find.descendant(of: find.byWidget(card), matching: find.byType(InkWell)));
  await tester.pumpAndSettle();
  return pushed;
}

const libraryCard =
    JapaneseLibraryCard(course: 'Minna no Nihongo', lessons: 29, words: 620);

void main() {
  setUpAll(holdHttpRequests);

  group('the signed-in Today card', () {
    testWidgets('reads DAILY LESSON and names no fixed lesson', (tester) async {
      await pumpStudyScreen(tester, const Scaffold(body: DailyLessonCard()));
      expect(find.text(DailyLessonCard.label), findsOneWidget);
      expect(find.text(DailyLessonCard.title), findsOneWidget);
      expect(find.textContaining('課'), findsNothing);
    });

    testWidgets('pushes the session route, not the word-card screen',
        (tester) async {
      final pushed = await tapUnderRouter(tester, const DailyLessonCard());
      expect(pushed, [QuietRoomReviewPage.routeName]);
      expect(find.text('the session'), findsOneWidget);
      expect(find.text('the word cards'), findsNothing);
    });

    testWidgets('with no router opens the session page itself', (tester) async {
      await pumpStudyScreen(tester, const Scaffold(body: DailyLessonCard()));
      await tester.tap(find.text(DailyLessonCard.title));
      await tester.pump();
      await tester.pump();
      expect(find.byType(QuietRoomReviewPage), findsOneWidget);
      expect(find.byType(QuietRoomLessonWidget), findsNothing);
    });
  });

  group('the Library card', () {
    testWidgets('shows the course, its lessons and its words', (tester) async {
      await pumpStudyScreen(tester, const Scaffold(body: libraryCard));
      expect(find.text(JapaneseLibraryCard.title), findsOneWidget);
      expect(find.text('Minna no Nihongo · 29 lessons · 620 words'),
          findsOneWidget);
    });

    testWidgets('pushes the session route, not the word-card screen',
        (tester) async {
      final pushed = await tapUnderRouter(tester, libraryCard);
      expect(pushed, [QuietRoomReviewPage.routeName]);
      expect(find.text('the session'), findsOneWidget);
      expect(find.text('the word cards'), findsNothing);
    });

    testWidgets('with no router opens the session page itself', (tester) async {
      await pumpStudyScreen(tester, const Scaffold(body: libraryCard));
      await tester.tap(find.text(JapaneseLibraryCard.title));
      await tester.pump();
      await tester.pump();
      expect(find.byType(QuietRoomReviewPage), findsOneWidget);
      expect(find.byType(QuietRoomLessonWidget), findsNothing);
    });
  });

  test('each screen builds its card and opens the word-card screen nowhere',
      () {
    final today = File(todayFile).readAsStringSync();
    final library = File(libraryFile).readAsStringSync();
    expect(today, contains('const DailyLessonCard()'));
    expect(library, contains('JapaneseLibraryCard('));
    for (final source in [today, library]) {
      expect(source, isNot(contains('QuietRoomLessonWidget')));
    }
  });
}
