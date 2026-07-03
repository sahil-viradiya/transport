// Firebase Cloud Messaging service worker — handles web push while the tab is
// in the background or closed. firebase_messaging looks for this file at the web
// root automatically.
importScripts(
    "https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts(
    "https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCFte8SaEM25uQNis6B7-Ls0T3nE9uN7W0",
  authDomain: "transport-1faf4.firebaseapp.com",
  projectId: "transport-1faf4",
  storageBucket: "transport-1faf4.firebasestorage.app",
  messagingSenderId: "1048359203148",
  appId: "1:1048359203148:web:5e3d6694adb35a22765fe9",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || "Notification", {
    body: n.body || "",
    icon: "/icons/Icon-192.png",
    data: payload.data || {},
  });
});

// Focus / open the app when the notification is clicked.
self.addEventListener("notificationclick", function (event) {
  event.notification.close();
  event.waitUntil(
      clients.matchAll({type: "window"}).then(function (clientList) {
        for (const client of clientList) {
          if ("focus" in client) return client.focus();
        }
        if (clients.openWindow) return clients.openWindow("/");
      }),
  );
});
