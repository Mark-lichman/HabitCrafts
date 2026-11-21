# Adopted Files

The register required by `docs/standards.md` **S3**.

A file listed here has been edited by a human and has therefore left the generated bucket
**permanently**. It no longer gets the generated-code discount in review: verbosity, repetition and
deep nesting in an adopted file are findings, not expected noise.

Why a register rather than a commit message: the author and the reviewer are the same person weeks
apart, and the bucket question gets asked at review time, when a commit message is invisible. This is
the only bookkeeping in the standards, and S3 explains why it is worth the cost.

## What does not belong here

- `lib/custom_code/**` and `firebase/**/*.js`. Always hand-written, never generated, nothing to
  adopt. The 2026-07-27 check-in slider repair lives entirely in
  `lib/custom_code/widgets/checkin_slider_widget.dart` and is therefore not an adoption.
- Mechanical, tool-applied changes. `dart format`, `dart fix --apply`, and dependency codemods leave
  a file in the generated bucket (S3 corollary). Without that carve-out one `dart fix` run would
  adopt the whole tree.
- Deletions. Removing inherited code is the opposite of taking on its maintenance (S9).
- Files outside `lib/`. `android/`, `ios/`, `web/` and the Gradle files are platform scaffolding, not
  builder output, and are governed by `store-compliance` rather than by S3.

## Register

The rows dated 2026-07-28 come from one commit, `2a42c0f`, the first successful build after leaving
FlutterFlow. Each is a single line forced by a breaking change in `font_awesome_flutter` 11, which
introduced `FaIconData` and made `FaIcon` require it. There was no version of "make the app build"
that did not touch vendored framework code, which is exactly the case S3 says is worth paying for.

The rows dated 2026-09-26 and 2026-09-27 come from the Quiet Room build, and they are a different
kind of adoption: not forced by a dependency, but taken deliberately because the design direction
could not be expressed through the generated files as they stood.

The row dated 2026-10-27 comes from the anonymous-caller work for the speaking drill, not from the
Quiet Room build, and is a third kind of adoption: a security edit, taken so the drill's hidden
anonymous sign-in (PIN-9) never counts as a signed-in user.

The rows dated 2026-11-20 come from the web sync plan (`docs/plans/2026-11-19-jp-web-sync.md`,
Tasks 6 and 8). They make sign-in, sign-out and password reset work on the web, under the same
account as the phone (PIN-8).

The rows dated 2026-11-21 come from Phase 4 of the same plan (Tasks 11 and 14). Task 14's nav,
model and action rows let the whole app open every route in a browser (End state 6, PIN-15):
`test/web_routes_smoke_test.dart` opens each route in Chrome and fails on any uncaught error. Task
11's push token row serves web push and reminders (PIN-6). Two of them sit in `lib/custom_code/`, which
the section above keeps out of the register. They are listed anyway because both actions still
carry the FlutterFlow custom-action header, so a builder sync would write its copy over them and
drop the web guard.

| File | Adopted | Edit | Why it was worth owning |
| --- | --- | --- | --- |
| `lib/flutter_flow/flutter_flow_choice_chips.dart` | 2026-07-28 | `FaIcon` to `Icon` at the chip avatar | Generic helper taking arbitrary `IconData` from callers, so `FaIcon` was always wrong here. `IconData` carries its own font family; a forced `FaIconData` cast would crash at runtime on any Material icon. |
| `lib/flutter_flow/flutter_flow_widgets.dart` | 2026-07-28 | `FaIcon` to `Icon` at the button icon | Same generic-helper reasoning. |
| `lib/flutter_flow/flutter_flow_icon_button.dart` | 2026-07-28 | `icon.icon` cast to `FaIconData?` | This one genuinely holds a FontAwesome icon it has just unwrapped, so the cast is correct rather than a workaround. |
| `lib/flutter_flow/flutter_flow_theme.dart` | 2026-09-26 | Colour and type layers replaced to implement Quiet Room; `of()` now resolves brightness | The export hardcoded `return LightModeTheme()`, so the app could not have a second palette at all. Quiet Room specifies two. Every legacy field name is kept as an adapter because 101 files read them, and each keeps its previous colour *role* so nothing legible becomes illegible. |
| `lib/main.dart` | 2026-09-26, 2026-11-20 | Added `darkTheme`, and `scaffoldBackgroundColor` on both themes; pinned `themeMode` to `light`. On 2026-11-20 (Task 6): sets the `JpSyncHost.askOwner` dialog, calls `attach()` so app resumes reach `JpSyncHost`, feeds the auth stream to `JpSyncHost.userChanged`, and calls `detach()` in `dispose` | `themeMode: ThemeMode.system` was already present with no `darkTheme` to select, so dark mode was inert. The scaffold colour is what makes the ground inversion total (direction §5.1); without it any Scaffold that does not name its own background falls back to Material grey, outside the palette. ⚠️ Nightfall is built and selectable but **not reachable at runtime**: the same change pins `_themeMode` to `ThemeMode.light`, so this supplied the machinery and then switched it off. One line to revert. A regenerate would also drop the `JpSyncHost` wiring, so the study record would never sync and the other-account ask would never show (PIN-8). |
| `lib/flutter_flow/nav/nav.dart` | 2026-09-27, 2026-11-20, 2026-11-21 | Five route builders repointed at Quiet Room screens; two new routes registered for the lesson and practice screens. On 2026-11-20 (Task 7): registers the `DevicesPageWidget` route that the profile page opens. On 2026-11-21 (Task 14): a route whose URL names a document shows a blank page until that document loads, in place of building the screen with no document | The generated screens are still routed for everything not yet converted, so the route NAMES are kept and only their builders change — renaming them would have broken every generated caller. Sharpest risk in the table alongside the theme: FlutterFlow regenerates this file on any route edit in the builder, and a round-trip would silently restore the old screens app-wide. A regenerate would also drop the devices route, so the profile entry would open the error page, and would restore the early build: a web reload of a chat or image screen keeps only the URL, and those screens read their document with `!`, so they would throw before it loads. |
| `lib/auth/firebase_auth/firebase_user_provider.dart` | 2026-10-27 | `loggedIn` is false for an anonymous Firebase user (`user != null && !user!.isAnonymous`) | The speaking drill signs in anonymously to call the scoring function (PIN-9). A FlutterFlow regenerate would restore `user != null`, and the router and every screen would treat that hidden user as signed in. |
| `lib/auth/firebase_auth/firebase_auth_manager.dart` | 2026-11-20 | Constructor seams for the auth instance, profile create and analytics; email sign-in calls the seam; a closed popup returns quietly and a blocked popup says to allow pop-ups; a web sign-in pins IndexedDB persistence; password reset trims the email and never reads a null `message` | The web sign-in (End state 7) needs a Chrome test with Firebase faked, and the generated manager reached `FirebaseAuth.instance` directly. A regenerate would drop the seams, so `test/web_auth_test.dart` stops compiling, and would restore `e.message!`, which throws on an error with no message. |
| `lib/auth/firebase_auth/google_auth.dart` | 2026-11-20 | `googleSignInFunc` takes the auth instance and the platform as seams | The same Chrome test drives the web popup path through these seams. The popup call stays ahead of any `await`, or the browser blocks it. |
| `lib/components/pages/profile_page/profile_page_widget.dart` | 2026-11-20 | A "Signed-in devices" entry that opens `DevicesPageWidget.routeName`; sign-out clears this browser's study data (Task 6) | The devices list and the sign-out wipe are account features of the web sync (PIN-8). A regenerate would drop the entry and the wipe, so sign-out on a shared browser would leave the study record behind. |
| `lib/backend/push_notifications/push_notifications_util.dart` | 2026-11-21 | Registers the browser's FCM token with the existing `addFcmToken` function, so the scheduled push function can send reminders to the web (Task 11) | The generated stream asked for a token only on iOS and Android, so a browser never got push or reminders (PIN-6). A regenerate would restore that check, and web reminders would stop arriving with no error. |
| `lib/custom_code/actions/fetch_contacts_action.dart` | 2026-11-21 | Returns no contacts on the web (Task 14) | `flutter_contacts` has no web side, so its permission call never answers and the home page init that awaits it never finishes. A builder sync would restore the call. |
| `lib/custom_code/actions/open_notification_settings.dart` | 2026-11-21 | On the web, asks the browser for notification permission in place of opening the phone's settings (Task 14) | A browser has no app settings page for the native call to open, so the profile page's Notifications row did nothing on the web. A builder sync would restore the native call. |
| `lib/components/lifestyle_list_component_model.dart`, `lib/components/habit_components/habit_explore_list_item/habit_explore_list_item_model.dart`, `lib/components/habit_components/new_habit_component/new_habit_component_model.dart` | 2026-11-21 | The Expandable controller is nullable behind the same getter and setter, and `dispose` skips it when the widget never set it. The new habit model no longer disposes the Autocomplete's focus node (Task 14) | A page creates and disposes each of these models even when it never builds the widget (a tab not shown, an empty list, a step not reached). The generated `late` field then threw `LateInitializationError` on leaving the progress, explore and create habit pages, and the second focus node dispose asserted. A regenerate would restore both, and the route smoke test would fail on those three pages. |

**Consequence to remember:** these are now maintained by hand. The next Flutter or
`font_awesome_flutter` upgrade that would have arrived as a clean regenerated file arrives here as a
manual merge instead. `flutter_flow_theme.dart` and `nav/nav.dart` are the sharpest cases, because
FlutterFlow regenerates both on ordinary builder edits — a theme change or a route change — and
either round-trip would silently revert Quiet Room across the whole app.

## Not an adoption: `lib/flutter_flow/quiet_room.dart`

New hand-written code has no generated original to leave, so it gets no row. It is noted here only
because it sits in `lib/flutter_flow/`, where a reader is entitled to assume builder output. It is
the closed Quiet Room token layer and the single home for every colour value in the app.

> Check before citing this table: `git log --oneline -- <path>` for any row, and this, to find
> generated files carrying human commits that are missing a row:
>
> ```sh
> git log --diff-filter=M --name-only --format= 2dd8e10..HEAD -- \
>   'lib/components/**' 'lib/chat_groupwbubbles/**' 'lib/backend/schema/**' 'lib/flutter_flow/**' \
>   'lib/auth/**' \
>   | sort -u
> ```
