// Firebase Cloud Messaging service worker for the web build (plan 2026-11-19,
// Task 11). firebase_messaging registers this file when the app asks for a
// web FCM token. It shows pushes and reminders that arrive while the tab is
// in the background or closed.
//
// The SDK version matches firebase_core_web's supportedFirebaseJsSdkVersion.
// The config is the public web app config from
// lib/backend/firebase/firebase_config.dart. The web push key is not here:
// the app passes it to getToken from build config.
importScripts(
  "https://www.gstatic.com/firebasejs/11.7.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/11.7.0/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyBN3usT-YwAYqQ7tzVz6KsmfHdO-0Se0NA",
  authDomain: "tiny-habits-jf61nl.firebaseapp.com",
  projectId: "tiny-habits-jf61nl",
  storageBucket: "tiny-habits-jf61nl.firebasestorage.app",
  messagingSenderId: "68894759253",
  appId: "1:68894759253:web:8ac60bbb0abb52694bf7dc",
});

const messaging = firebase.messaging();

// A message with a `notification` block is shown by the SDK itself. This
// handler shows a data-only message, so no push arrives silently.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) {
    return;
  }
  const data = payload.data || {};
  const title = data.notification_title || data.title || "HabitCrafts";
  const body = data.notification_text || data.body || "";
  return self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    data,
  });
});
