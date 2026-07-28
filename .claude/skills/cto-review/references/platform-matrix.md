# Reference — `plat-matrix`

Body for the Platform Matrix category. Load when the category fires (it always fires).

Every embedded fact below carries a **Check before citing** predicate. Run it. If it no longer
holds, the claim has expired — do not cite it, and apply the retirement instruction.

---

## Why this category ranks first

For Android and web this review is a filter *before* empirical testing — a missed defect costs a
debug cycle. For iOS there is no Mac, no simulator, no build. This review is the **only**
verification an iOS code path receives before TestFlight. iOS-only defects are not caught later;
they are caught by a user, or by a reviewer at Apple.

That asymmetry is the whole justification for the mandatory iOS line in the output. It is not
ceremony. It is the record of the only iOS check that happened.

## The required statement

Every change gets a sentence per platform, or one sentence saying the change is platform-neutral
and why. "Should be fine" is not a statement. Each platform's answer must be one of:

- **works** — and how you established that
- **degrades deliberately** — and where the user is told
- **unreachable by design** — and what makes it unreachable
- **unknown** — which means this category has not finished; escalate to a Question

## Web-incompatible plugins

Three dependencies have no web implementation and are used in hand-written Dart.

- `flutter_local_notifications` — `lib/custom_code/actions/cancel_all_reminders.dart`
- `flutter_contacts` — `lib/custom_code/actions/fetch_contacts_action.dart`,
  `lib/custom_code/widgets/phone_contacts_widget.dart`
- `flutter_open_app_settings` — `lib/custom_code/actions/open_notification_settings.dart`

> **Check before citing:**
> `rg -l "flutter_local_notifications|flutter_contacts|flutter_open_app_settings" lib/custom_code/`
> Cite only the files this returns. If it returns nothing, the plugins have been isolated —
> delete this list from the reference and check the new isolation layer instead.

Flag any new or modified call into these plugins that is not behind a `kIsWeb` or
`defaultTargetPlatform` guard as **Warning** — **Critical** if the unguarded path sits on a
documented journey, because on web it throws and takes the journey with it.

**The guard gap.** Every platform guard in this project is inherited; none was authored.

> **Check before citing:** `rg -l "kIsWeb" lib/ | wc -l` and `rg -c "kIsWeb" lib/custom_code/`
> At last measurement: 12 files across `lib/`, **zero** occurrences in `lib/custom_code/`.
> If the `custom_code` count is now non-zero, the "no authored guard exists" claim has expired.
> Drop it and review the guards that exist on their merits.

## Permission, notification, and auth flows — walk each platform by name

Do not accept a single narrative. Required beats:

**Android 13+ (API 33).** `POST_NOTIFICATIONS` is a runtime permission. Declaration is not grant —
the request must happen and its denial must be handled. `minSdkVersion 28` means the pre-33 path
also still runs, so both branches are live. `SCHEDULE_EXACT_ALARM` and `RECEIVE_BOOT_COMPLETED`
carry their own Android-version conditions and their own Play justification requirements.

> **Check before citing:** `rg -n "uses-permission" android/app/src/main/AndroidManifest.xml`
> Confirms which permissions are actually declared. Cite from this output, not from memory.

**iOS.** APNs. `ios/Runner/Runner.entitlements` sets `aps-environment`. A notification change must
state its effect on the entitlement, the provisioning profile, and the permission prompt. This is
the least verifiable surface in the project — treat any change to it as escalated, and put the
consequence in the iOS line of Platform Impact.

> **Check before citing:** `rg -n "aps-environment" ios/Runner/Runner.entitlements`

**Web.** FCM on web needs a service worker and a VAPID key, plus the browser's own notification
permission prompt, which is per-origin and cannot be re-requested by the page once denied.

> **Check before citing:** `ls web/` — at last measurement there was no `firebase-messaging-sw.js`.
> If one now exists, web push is no longer definitionally broken: review it on its merits instead
> of asserting absence.

Any change that assumes web push works must say what makes it work.

## New routes are reviewed as URLs first

`usePathUrlStrategy()` is called in `lib/main.dart`, so every route is a real, shareable,
bookmarkable web URL.

> **Check before citing:** `rg -n "usePathUrlStrategy" lib/main.dart`
> If this returns nothing, the URL strategy changed — this whole subsection is void.

For any added or renamed route, answer four questions before anything else:

1. **Direct entry** — the user pastes the URL cold, with no in-app navigation history. What renders?
2. **Refresh** — F5 mid-flow. Is required state held in `FFAppState` or in route params? Unpersisted
   `FFAppState` is gone.
3. **Back button** — the browser's, not an in-app one. Does it strand the user or double-submit?
4. **Unauthenticated arrival** — a signed-out visitor reaches the route by URL. What do they see?

> **Check before citing (#6):** `rg -n "requireAuth" lib/flutter_flow/nav/nav.dart`
> At last measurement no route set it, so every route was reachable signed-out. When #6 lands and
> this returns hits, stop asserting the gap and start checking that new routes opt in.

## Desktop widths

Web means a mouse and a 1440px-wide window, not a phone. For any new screen: layouts that do not
stretch unusably wide, fixed pixel widths that do not clip, and hover and focus states for controls
whose only affordance on mobile was touch.

## Sign in with Apple — App Store Guideline 4.8

Guideline 4.8 requires an equivalent private sign-in option wherever a third-party social login is
offered. Google Sign-In and Sign in with Apple are both present on the login page.

> **Check before citing:**
> `rg -n "signInWithGoogle|signInWithApple" lib/components/pages/login_page/login_page_widget.dart`
> Both must appear. If Google appears without Apple, that is the Critical finding, not a
> hypothetical.

Any change that removes, hides, or breaks the Apple path on iOS while Google remains is
**Critical** — a store rejection, not a bug. The same rule fires for any newly added third-party
provider.

## Do not flag

- Server-side code in `firebase/`, which has no client platform.
- Pure Dart logic in `lib/flutter_flow/custom_functions.dart` with no plugin or `dart:io` dependency.
- Changes to generated widget trees that use only platform-neutral Flutter widgets.
- A `kIsWeb` branch that already handles the web case, even if the web behaviour is a no-op — as
  long as the user is told rather than silently given an empty result.
