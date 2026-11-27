---
name: web-push-link-built-from-route-name-not-route-path
description: The web push click link uses the FlutterFlow route name, which differs from the route path for chat pages
metadata:
  type: project
  keywords: [web push, fcmOptions link, initial_page_name, routeName, routePath, chat_2_Details, chat2Details, webpushConfig, deep link]
  provenance: code-verified
  slug: web-push-link-built-from-route-name-not-route-path
  phase: 4
  tags: [push, web, flutterflow, open-nit]
  created: 2026-11-21
---

`webpushConfig` in `firebase/functions/index.js` builds the click link as `<origin>/<initial_page_name>`.
`initial_page_name` holds a FlutterFlow route name, but the web router matches route paths.

For `groupsPage`, `libraryDetailPage` and `homePage` the name equals the path, so the click opens the page.
For the chat details screen the name is `chat_2_Details` and the path is `/chat2Details`.
A click then opens `/chat_2_Details`, and the `errorBuilder` in `lib/flutter_flow/nav/nav.dart` shows the entry page.
That equals the root-link fallback, so the outcome is harmless but the link does not deep-link.

Task 11 landed this as a Nit with disposition note, and nobody fixed it.
The code comment saying the click opens the page is only loosely true for chat names.

Fix if it matters: map name to path in the function, or send the path in the notification data.
End state 12 (real browser push) stays unverified until someone checks it by hand after deploy.

Verify still present before acting: `webpushConfig` in `firebase/functions/index.js` and `static String routePath` in `lib/chat_groupwbubbles/chat_2_details/chat2_details_widget.dart` @ phase 4 tip cc5bd6e.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
