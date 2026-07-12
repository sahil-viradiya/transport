# Firebase Storage images on Flutter Web — CORS fix

## Symptom
Uploaded images (driver photo, driving/heavy licence, proof of delivery,
receipts, avatars) show fine in the Firebase console but **don't display in the
deployed web app** (blank avatar / broken image).

## Why
Flutter web renders with CanvasKit, which draws network images onto a canvas.
For a cross-origin image (Firebase Storage → your Vercel domain) the browser
requires the storage bucket to send CORS headers. By default the bucket doesn't,
so the image fails to load in the app even though the URL is valid.

## Two layers of fix

### 1. In-app proxy (already applied — works now)
Web image loads go through `corsSafeImageUrl()`
(`lib/app/core/utils/image_url.dart`), which re-serves the image via
`images.weserv.nl` with permissive CORS headers. No setup needed; already live
for avatars, driver documents, POD and receipts. On mobile it's a no-op.

### 2. Bucket CORS policy (the durable fix — do this once)
Once the bucket allows CORS, images load natively and the proxy can be removed.

```bash
# Requires gcloud (or gsutil) authenticated to the project.
# Bucket name is from your firebase config: storageBucket.
gcloud storage buckets update gs://transport-1faf4.firebasestorage.app \
  --cors-file=cors.json

# Older tooling equivalent:
# gsutil cors set cors.json gs://transport-1faf4.firebasestorage.app
```

`cors.json` (in the repo root) currently allows GET from any origin, which is
appropriate for publicly-viewable images. To restrict it to your site, replace
`"*"` with your exact origin, e.g. `["https://your-app.vercel.app"]`.

Verify:
```bash
gcloud storage buckets describe gs://transport-1faf4.firebasestorage.app \
  --format="default(cors_config)"
```

After confirming native loads work, the `corsSafeImageUrl()` proxy can be
simplified to return the url unchanged.
