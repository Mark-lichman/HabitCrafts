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

The first three rows come from one commit, `2a42c0f`, the first successful build after leaving
FlutterFlow. Each is a single line forced by a breaking change in `font_awesome_flutter` 11, which
introduced `FaIconData` and made `FaIcon` require it. There was no version of "make the app build"
that did not touch vendored framework code, which is exactly the case S3 says is worth paying for.

| File | Adopted | Edit | Why it was worth owning |
| --- | --- | --- | --- |
| `lib/flutter_flow/flutter_flow_choice_chips.dart` | 2026-07-28 | `FaIcon` to `Icon` at the chip avatar | Generic helper taking arbitrary `IconData` from callers, so `FaIcon` was always wrong here. `IconData` carries its own font family; a forced `FaIconData` cast would crash at runtime on any Material icon. |
| `lib/flutter_flow/flutter_flow_widgets.dart` | 2026-07-28 | `FaIcon` to `Icon` at the button icon | Same generic-helper reasoning. |
| `lib/flutter_flow/flutter_flow_icon_button.dart` | 2026-07-28 | `icon.icon` cast to `FaIconData?` | This one genuinely holds a FontAwesome icon it has just unwrapped, so the cast is correct rather than a workaround. |
| `lib/flutter_flow/flutter_flow_theme.dart` | 2026-09-26 | Colour and type layers replaced to implement Quiet Room; `of()` now resolves brightness | The export hardcoded `return LightModeTheme()`, so the app could not have a second palette at all. Quiet Room specifies two. Every legacy field name is kept as an adapter because 101 files read them, and each keeps its previous colour *role* so nothing legible becomes illegible. |
| `lib/main.dart` | 2026-09-26 | Added `darkTheme`, and `scaffoldBackgroundColor` on both themes | `themeMode: ThemeMode.system` was already present with no `darkTheme` to select, so dark mode was inert. The scaffold colour is what makes the ground inversion total (direction §5.1); without it any Scaffold that does not name its own background falls back to Material grey, outside the palette. |

**Consequence to remember:** these are now maintained by hand. The next Flutter or
`font_awesome_flutter` upgrade that would have arrived as a clean regenerated file arrives here as a
manual merge instead. `flutter_flow_theme.dart` is the sharpest case: FlutterFlow regenerates that
file on every theme edit in the builder, so a future builder round-trip would silently revert Quiet
Room.

## Not an adoption: `lib/flutter_flow/quiet_room.dart`

New hand-written code has no generated original to leave, so it gets no row. It is noted here only
because it sits in `lib/flutter_flow/`, where a reader is entitled to assume builder output. It is
the closed Quiet Room token layer and the single home for every colour value in the app.

> Check before citing this table: `git log --oneline -- <path>` for any row, and this, to find
> generated files carrying human commits that are missing a row:
>
> ```
> git log --diff-filter=M --name-only --format= 2dd8e10..HEAD -- \
>   'lib/components/**' 'lib/chat_groupwbubbles/**' 'lib/backend/schema/**' 'lib/flutter_flow/**' \
>   | sort -u
> ```
