// Cloud Function: when the app writes a `notifications/{id}` document, push it
// to the recipient's devices via FCM.
//
// The Flutter app already:
//   - creates notifications in Firestore (in-app bell works with no backend),
//   - saves each device's FCM token to users/{phone}.fcmTokens.
// This function turns those in-app notifications into real push notifications.
//
// Deploy:  firebase deploy --only functions
// Requires the Firebase Blaze (pay-as-you-go) plan.

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

      // Look up the recipient's registered device tokens.
      const userSnap = await getFirestore()
          .collection("users")
          .doc(note.toPhone)
          .get();
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
            channelId: "high_importance_channel",
            sound: "default",
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

      // Clean up tokens that are no longer valid.
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
