# Trip Confirmation Workflow & Notifications

## The flow (what the client asked for)

1. **Admin assigns a trip** → it is saved as `PENDING` (not active yet) and a
   notification is created for the driver.
2. **Driver gets notified** (in-app bell + push) and sees **Accept / Reject**
   buttons on the trip card.
3. **Driver Accepts** → trip becomes `ASSIGNED` (ready to start); the admin who
   assigned it is notified. **Driver Rejects** → trip becomes `REJECTED` (with an
   optional reason) and the admin is notified so they can reassign.
4. Driver **starts** the accepted trip → `ACTIVE NOW`. Only **one trip can be
   active at a time** (starting a new one deactivates any other active trip).
5. Delivery → `DELIVERED`.

Trip statuses: `PENDING → ASSIGNED → ACTIVE NOW → DELIVERED` (plus `REJECTED`).

## Notifications

- **In-app (works now, no backend):** a `notifications` Firestore collection,
  scoped per recipient by `toPhone`. The bell icon (driver dashboard + admin app
  bar) shows an unread badge and a list. Live via `watchNotifications`.
- **Push (FCM):** the app saves each device token to `users/{phone}.fcmTokens`
  and a Cloud Function turns every new `notifications` doc into a push.

## Push notifications — foreground + background + terminated

Every in-app notification (trip assigned/accepted, load & delivery approvals,
expenses, check-in/out, priority, etc.) writes a `notifications/{id}` doc, which
triggers the Cloud Function to send an FCM push to the recipient's devices.

What's already wired in the app (`PushService`):
- **Foreground floating (no backend needed):** the live Firestore stream
  (`NotificationsController`) fires an OS heads-up notification via
  `PushService.showLocal` the moment a new notification arrives — so floating
  notifications work while the app is open **even before the Cloud Function is
  deployed**. Also shown for real FCM foreground messages.
- **Background & terminated:** the OS shows the `notification` payload; the
  Cloud Function sets the Android channel (`high_importance_channel`) + sounds.
- **Tap to open:** `onMessageOpenedApp` / `getInitialMessage` / local-notification
  tap all navigate to the trip details screen (via the `tripId` data field).
- **Web:** `web/firebase-messaging-sw.js` handles background web push.

### One-time setup (required for OS-level push)

Push needs the **Blaze** plan and a deployed Cloud Function.

```bash
npm i -g firebase-tools && firebase login
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules
```

Per platform:
- **Android:** `google-services.json` wired; `POST_NOTIFICATIONS` in the manifest
  (Android 13+ asks at runtime); channel meta-data set. Works out of the box.
- **iOS:** upload an APNs auth key in Console → Project Settings → Cloud
  Messaging, and enable Push Notifications + Background Modes in Xcode.
- **Web:** create a VAPID key (Console → Cloud Messaging → Web Push
  certificates) and paste it into `PushService.webVapidKey`. The service worker
  `web/firebase-messaging-sw.js` is already in place.

Until the function is deployed, the **in-app bell still works** — only OS-level
push (foreground banner needs no backend; background/terminated need the
function deployed).
