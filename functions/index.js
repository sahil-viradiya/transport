// Cloud Function: when the app writes a `notifications/{id}` document, push it
// to the recipient's devices via FCM.
//
// Deploy: firebase deploy --only functions

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

exports.sendNotificationPush = onDocumentCreated(
    "notifications/{id}",
    async (event) => {
      const note = event.data && event.data.data();
      if (!note || !note.toPhone) return;

      const rawPhone = String(note.toPhone || "").trim();
      const digitsOnly = rawPhone.replace(/\D/g, "");
      const phone10 = digitsOnly.length >= 10 ? digitsOnly.slice(-10) : digitsOnly;

      const db = getFirestore();
      let userSnap = await db.collection("users").doc(rawPhone).get();
      if (!userSnap.exists && phone10) {
        userSnap = await db.collection("users").doc(phone10).get();
      }
      if (!userSnap.exists) return;

      const tokens = ((userSnap.data() || {}).fcmTokens || []).filter(Boolean);
      if (tokens.length === 0) return;

      const res = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: note.title || "Notification",
          body: note.body || "",
        },
        data: {
          type: String(note.type || "info"),
          tripId: String(note.tripId || ""),
          refId: String(note.refId || ""),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel_v2",
            sound: "default",
            priority: "max",
            visibility: "public",
          },
        },
        apns: {
          payload: {aps: {sound: "default", badge: 1}},
        },
        webpush: {
          notification: {icon: "/icons/Icon-192.png"},
          fcmOptions: {link: "/"},
        },
      });

      const stale = [];
      res.responses.forEach((r, i) => {
        if (!r.success) {
          const code = r.error && r.error.code;
          if (
            code === "messaging/invalid-registration-token" ||
            code === "messaging/registration-token-not-registered"
          ) {
            stale.push(tokens[i]);
          }
        }
      });

      if (stale.length) {
        const {FieldValue} = require("firebase-admin/firestore");
        await userSnap.ref.update({
          fcmTokens: FieldValue.arrayRemove(...stale),
        });
      }
    },
);
