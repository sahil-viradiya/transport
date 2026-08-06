import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase Storage images don't render in Flutter web (CanvasKit) unless the
/// Storage bucket has a CORS policy allowing the app's origin. Until that's
/// configured on the bucket, we proxy web image loads through images.weserv.nl,
/// which re-serves the image with permissive CORS headers so CanvasKit can draw
/// it. On mobile/desktop this is a no-op (native networking has no CORS).
///
/// The durable fix is to set a CORS policy on the bucket (see README/NOTES);
/// once that's done this proxy can be removed.
String corsSafeImageUrl(String url) {
  if (url.trim().isEmpty) return '';
  final clean = url.trim();
  if (kIsWeb && clean.startsWith('http') && !clean.startsWith('blob:')) {
    if (clean.contains('images.weserv.nl')) return clean;
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(clean)}';
  }
  return clean;
}
