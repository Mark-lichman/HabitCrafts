# Web app runbook: habitcraftapp.com

This is the one-time setup that puts the Flutter web build on `habitcraftapp.com`
(plan 2026-11-19, Task 12). Each step is a console or registrar action that no workflow
can do. Mark owns all of them (plan assumption A7).

This page does not repeat paths or deploy commands. Read them from the source:

* `firebase/firebase.json`, the `hosting` block: what is served and how every route
  rewrites to `/index.html`.
* `.github/workflows/deploy-web.yml`: when a deploy runs, the build command, the deploy
  command, and the secret and variable it needs.
* `docs/deploy.md`: rules and functions. The web deploy never touches them.

The Firebase project is `tiny-habits-jf61nl`, the only one. There is no staging site.

## Order

Do the steps in this order. Each later step assumes the earlier ones hold.

1. Service account and web push key (so the first deploy can run).
2. Rules, the `deleteAllUserData` function and the push sender functions (so the first
   web sign-in can write and web pushes carry the icon and the click link).
3. First deploy, then check the `web.app` URL.
4. Custom domain in Firebase Hosting, then the Porkbun DNS change.
5. Authorized domains.
6. Apple Services ID.
7. The backstop checks at the end.

## 1. Deploy credentials

### Service account

`deploy-web.yml` reads the secret `FIREBASE_SERVICE_ACCOUNT`.

1. Google Cloud console, project `tiny-habits-jf61nl`, IAM and Admin, Service Accounts.
2. Create a service account named `github-deploy-web`.
3. Grant it **Firebase Hosting Admin** and nothing else. It needs no Firestore, Functions
   or Storage role, because the workflow deploys hosting only.
4. Create a JSON key for it.
5. GitHub repo, Settings, Secrets and variables, Actions, New repository secret.
   Name it `FIREBASE_SERVICE_ACCOUNT` and paste the whole JSON file.
6. Delete the downloaded key file from your machine.

### FCM web push key

The web push key (VAPID public key) lets a browser get a push token. Without it the app
runs, but no browser gets pushes or reminders. The deploy workflow refuses to build
without it.

1. Firebase console, Project settings, Cloud Messaging, Web configuration,
   Web Push certificates.
2. If no key pair exists, choose **Generate key pair**.
3. Copy the public key string.
4. GitHub repo, Settings, Secrets and variables, Actions, **Variables** tab,
   New repository variable. Name it `FCM_WEB_VAPID_KEY` and paste the key.

It is a variable, not a secret, because the key is public by design: every browser that
loads the app receives it. Never commit it to the repo. A test fails if the build
constant carries a default value (`test/push_web_test.dart`).

If you rotate the key pair, every existing web token stops working. Users get a new
token the next time they open the app.

## 2. Rules and functions

The web deploy never publishes Firestore rules or functions. If the committed rules are
not live, the first web sign-in gets permission-denied on `jp_events`, `jp_days` and
`devices`.

1. Deploy the committed rules, as `docs/deploy.md` describes.
2. Deploy the `deleteAllUserData` function, as `docs/deploy.md` describes.
3. Deploy the push sender functions of the `functions` codebase:
   `sendPushNotificationsTrigger`, `sendUserPushNotificationsTrigger` and
   `sendScheduledPushNotifications`. Name each one in the `functions:<codebase>:<name>`
   form that `docs/deploy.md` describes. Each sender bundles the shared helper that adds
   the `webpush` block, so web pushes carry the icon and the click link to
   `habitcraftapp.com` only after this step. Old senders still deliver to web tokens, so
   backstop check 3 passes without this step and hides the gap.

## 3. First deploy

Run **Deploy web** from the GitHub Actions tab with **Run workflow** on `main`. A manual
run on any other branch skips the deploy job. Later deploys run on their own after CI
passes on a merge to `main`.

The merge that adds `deploy-web.yml` to `main` also starts a deploy after CI passes. If
section 1 is not done by then, that run fails at the **Check web push key** step or the
**Deploy to Firebase Hosting** step. That is expected. If section 1 is done but section 2
is not, that run publishes the app before the rules and functions land. Run **Deploy
web** by hand after section 2 in either case.

Then open `https://tiny-habits-jf61nl.web.app/homePage`. It must show the app, not a
404. If it shows a 404, the rewrite in `firebase/firebase.json` did not deploy. Check the
workflow log before you go on.

## 4. Custom domain and the Porkbun DNS change (PIN-7)

Today `habitcraftapp.com/homePage` still serves the old FlutterFlow publish from Google
Cloud Storage (response header `x-goog-generation`, last modified 2025-06-05). DNS is at
Porkbun.

1. Firebase console, Hosting, **Add custom domain**. Enter `habitcraftapp.com`.
   Leave "Redirect to an existing website" off.
2. Firebase shows the records to set. Usually that is a TXT record to prove ownership,
   then one or more A records. Copy the exact values from the console, because they
   differ per project.
3. Porkbun, Domain Management, `habitcraftapp.com`, **DNS**.
4. Write down every existing A, AAAA, ALIAS and CNAME record on the root (`@`) and on
   `www`.
   That list is your rollback.
5. Add the TXT record. Wait until the Firebase console shows the domain as verified.
6. Delete the old A, AAAA, ALIAS or CNAME records on the root that point at Google
   Cloud Storage. If they stay, browsers get both sites at random, and Porkbun refuses
   new A records beside a root ALIAS.
7. Add the A records Firebase gave you.
8. Optional: add `www.habitcraftapp.com` in Firebase as a redirect to
   `habitcraftapp.com`, and set the record Firebase shows for it at Porkbun.
9. Wait. Firebase issues the TLS certificate after DNS resolves. That can take up to
   24 hours. The console shows "Connected" when it is done.

Rollback: restore the records from step 4 at Porkbun. The old Cloud Storage site has
not been deleted, so it comes back as DNS propagates.

Do not delete the old Cloud Storage bucket until the backstop check at the end passes.

## 5. Authorized domains

Firebase Auth refuses a popup sign-in from a domain it does not know. Google and Apple
sign-in on the web both use a popup.

1. Firebase console, Authentication, Settings, **Authorized domains**.
2. Confirm `tiny-habits-jf61nl.firebaseapp.com` and `tiny-habits-jf61nl.web.app` are
   listed. Firebase adds both by default.
3. Add `habitcraftapp.com`. Add `www.habitcraftapp.com` if you set it up in section 4.
4. Leave `localhost` in place for local runs.

Google sign-in needs nothing more. The app's web config sets
`authDomain: tiny-habits-jf61nl.firebaseapp.com`, and the Google OAuth client already
trusts that handler.

Email sign-in and password reset need no domain change. The reset email links to the
Firebase handler page.

## 6. Apple Services ID

Apple sign-in on the web uses Firebase's `apple.com` provider in a popup. Apple only
accepts it through a **Services ID**, which is separate from the iOS app's bundle ID.

In the Apple Developer account (Certificates, Identifiers and Profiles):

1. Identifiers, **+**, **Services IDs**. Use a description such as "HabitCrafts web"
   and an identifier such as `com.habitcrafts.web`. It must differ from the app's
   bundle ID.
2. Enable **Sign in with Apple** on it, then **Configure**:
   * Primary App ID: the iOS app's App ID.
   * Domains and Subdomains: `tiny-habits-jf61nl.firebaseapp.com`
   * Return URLs: `https://tiny-habits-jf61nl.firebaseapp.com/__/auth/handler`
3. Keys, **+**. Enable Sign in with Apple, link it to the same primary App ID, and
   download the `.p8` key. Apple lets you download it once. Note the Key ID and your
   Team ID.

In the Firebase console, Authentication, Sign-in method, **Apple**:

4. Fill in the Services ID from step 1.
5. Under OAuth code flow configuration, fill in the Team ID, the Key ID and the
   contents of the `.p8` key.
6. Save. Store the `.p8` file in the password manager, then delete it from disk.

The iOS app keeps working through its bundle ID. Adding a Services ID changes nothing
for it.

The Sign in with Apple key does not expire, but a revoked key breaks web sign-in at once.

## 7. Backstop checks

These are the deferred checks from the plan. Run them after sections 1 to 6.

1. `curl -sI https://habitcraftapp.com/homePage` returns HTTP 200 with no
   `x-goog-generation` header. It should also carry the `Cache-Control` value set in
   `firebase/firebase.json`. A response that still carries `x-goog-generation` means
   the old Cloud Storage site is still answering. Check section 4. (The local Hosting
   emulator serves the rewrite but does not add custom headers, so only the live site
   proves the header.)
2. Open `https://habitcraftapp.com/homePage` in Chrome. Sign in with Google, then sign
   out and sign in with Apple. Both sign-ins must complete with no error. Then sign in
   with the method the phone uses. That account must show the phone's study record.
   Firebase gives each provider its own account unless the emails match. An Apple
   account with a hidden email gets a relay address, so it is a separate account.
   That is correct, not a failure.
3. Allow notifications when the app asks. Send a test push from the Firebase console
   to the web token, and wait for one scheduled reminder. Both must arrive with the tab
   in the background.
4. Reload the page. You must still be signed in.
5. The Firestore Rules tab in the Firebase console shows the same text as
   `firebase/firestore.rules`. If it differs, redo section 2.

If check 3 fails, confirm `FCM_WEB_VAPID_KEY` is set and the deploy that ran used it.
The workflow log shows the build step. If a push arrives with no icon or no click link,
redo step 3 of section 2: the push sender functions are not live.
