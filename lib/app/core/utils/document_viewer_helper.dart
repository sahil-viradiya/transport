import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'in_app_pdf_viewer_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'app_image_helper.dart';
import 'image_url.dart';
import '../../../widgets/app_text.dart';
import '../../../widgets/dialogs/app_snackbar.dart';

class DocumentViewerHelper {
  DocumentViewerHelper._();

  static bool isPdf(String urlOrBase64) {
    if (urlOrBase64.isEmpty) return false;
    final lower = urlOrBase64.toLowerCase();
    if (lower.contains('application/pdf')) return true;
    if (lower.contains('data:image')) return false;
    if (lower.endsWith('.pdf') || lower.contains('.pdf?')) return true;
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) return false;

    // Check Base64 magic headers
    try {
      var str = urlOrBase64.trim();
      if (str.contains(',')) {
        str = str.split(',').last.trim();
      }
      str = str.replaceAll(RegExp(r'\s+'), '');
      if (str.startsWith('JVBERi')) { // Base64 encoding of %PDF
        return true;
      }
      if (str.startsWith('/9j/') || str.startsWith('iVBORw')) { // JPEG or PNG base64
        return false;
      }
    } catch (_) {}

    return false;
  }

  static Uint8List? _extractBytes(String urlOrBase64) {
    return AppImageHelper.decodeBase64(urlOrBase64);
  }

  static Future<Uint8List?> _resolveBytes(String urlOrBase64) async {
    debugPrint(
        '📄 [PDF DOWNLOAD] Starting _resolveBytes. Length: ${urlOrBase64.length}');
    if (urlOrBase64.startsWith('/')) {
      try {
        final file = File(urlOrBase64);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          debugPrint('📄 [PDF DOWNLOAD] Local file bytes read: ${bytes.length} bytes');
          return bytes;
        }
      } catch (e) {
        debugPrint('📄 [PDF DOWNLOAD] Local file read failed: $e');
      }
    }

    final bytes = _extractBytes(urlOrBase64);
    if (bytes != null && bytes.isNotEmpty) {
      debugPrint(
          '📄 [PDF DOWNLOAD] Base64 bytes extracted successfully! Size: ${bytes.length} bytes');
      return bytes;
    }

    if (urlOrBase64.startsWith('http')) {
      final safeUrl = corsSafeImageUrl(urlOrBase64);
      debugPrint(
          '📄 [PDF DOWNLOAD] Attempting HTTP fetch via Dio from: $safeUrl');
      try {
        final res = await Dio().get<List<int>>(
          safeUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null) {
          final fetched = Uint8List.fromList(res.data!);
          debugPrint(
              '📄 [PDF DOWNLOAD] HTTP fetch success! Size: ${fetched.length} bytes');
          return fetched;
        }
      } catch (e) {
        debugPrint('📄 [PDF DOWNLOAD] Dio fetch failed with safeUrl ($safeUrl): $e');
        try {
          final res = await Dio().get<List<int>>(
            urlOrBase64,
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.data != null) {
            final fetched = Uint8List.fromList(res.data!);
            return fetched;
          }
        } catch (_) {}
      }
    }
    debugPrint('📄 [PDF DOWNLOAD] Unable to resolve bytes from input!');
    return null;
  }

  static void showDocument(BuildContext context, String urlOrBase64,
      {String title = 'Document'}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pdfMode = isPdf(urlOrBase64);
    final screenWidth = MediaQuery.of(context).size.width;

    Get.dialog(
      Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: screenWidth > 540 ? 500 : screenWidth * 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    pdfMode
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    color: pdfMode ? Colors.redAccent : Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      title,
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pdfMode) ...[
                GestureDetector(
                  onTap: () {
                    Get.back();
                    viewPdf(context, urlOrBase64, title);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.picture_as_pdf_rounded,
                            size: 52, color: Colors.redAccent),
                        SizedBox(height: 10),
                        AppText(
                          'Tap to View PDF In-App 📄',
                          style: AppTextStyle.bodyLarge,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                        SizedBox(height: 4),
                        AppText(
                          'Click to view PDF document inside the app or download.',
                          style: AppTextStyle.labelMedium,
                          color: Colors.grey,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 300,
                    child: InteractiveViewer(
                      child: _buildImage(urlOrBase64),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  if (pdfMode)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.back();
                          viewPdf(context, urlOrBase64, title);
                        },
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text(
                          'View In-App',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (pdfMode) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => downloadToFolder(urlOrBase64, title, context: context),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        pdfMode ? 'Download PDF' : 'Download Image',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pdfMode
                            ? Colors.redAccent
                            : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildImage(String urlOrBase64) {
    return AppImageHelper.buildImageWidget(
      source: urlOrBase64,
      fit: BoxFit.contain,
      errorWidget: const Center(
        child: Icon(Icons.image_not_supported_rounded,
            size: 48, color: Colors.grey),
      ),
    );
  }

  /// Opens the PDF file directly IN-APP using InAppPdfViewerScreen
  static Future<void> viewPdf(
      BuildContext? context, String urlOrBase64, String title) async {
    try {
      final cleanTitle = title.replaceAll(RegExp(r'[^\w\-]'), '_');
      final bytes = await _resolveBytes(urlOrBase64);

      if (bytes != null && bytes.isNotEmpty && !kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$cleanTitle.pdf');
        await file.writeAsBytes(bytes);

        Get.to(
          () => InAppPdfViewerScreen(
            filePath: file.path,
            title: title,
            urlOrBase64: urlOrBase64,
          ),
        );
      } else if (urlOrBase64.startsWith('http')) {
        final uri = Uri.parse(urlOrBase64);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        await downloadToFolder(urlOrBase64, title);
      }
    } catch (e) {
      debugPrint('📄 [PDF VIEW ERROR] $e');
      await downloadToFolder(urlOrBase64, title);
    }
  }

  /// Downloads file directly to device's Documents & Downloads folders (My Files)
  static Future<void> downloadToFolder(String urlOrBase64, String title, {BuildContext? context, BuildContext? parentContext}) async {
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\-]'), '_');
    final ext = isPdf(urlOrBase64) ? 'pdf' : 'jpg';
    final fileName =
        '${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    debugPrint('📄 [PDF DOWNLOAD] Starting downloadToFolder for "$fileName"');

    try {
      final bytes = await _resolveBytes(urlOrBase64);

      if (bytes == null || bytes.isEmpty) {
        debugPrint('📄 [PDF DOWNLOAD ERROR] Bytes empty or null!');
        AppSnackBar.showError(
          title: 'Download Failed ❌',
          message: 'Unable to extract document file data.',
        );
        return;
      }

      if (kIsWeb) {
        final base64Str = base64Encode(bytes);
        final href = 'data:application/pdf;base64,$base64Str';
        final uri = Uri.parse(href);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AppSnackBar.showSuccess(
          title: 'Downloaded ✅',
          message: '$fileName saved.',
        );
        return;
      }

      final List<String> successfulPaths = [];
      final List<String> errors = [];

      String? openablePath;

      if (Platform.isAndroid) {
        // Path 1: App External Package Directory (Always 100% permitted for OpenFilex)
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final savedFile = File('${extDir.path}/$fileName');
            await savedFile.writeAsBytes(bytes);
            successfulPaths.add(savedFile.path);
            openablePath = savedFile.path;
            debugPrint(
                '📄 [PDF DOWNLOAD SUCCESS] Saved to External Package Dir: ${savedFile.path}');
          }
        } catch (e) {
          debugPrint('📄 [PDF DOWNLOAD FAIL] External dir failed: $e');
          errors.add('External dir: $e');
        }

        // Path 2: Primary Public - /storage/emulated/0/Documents (My Files > Documents)
        try {
          final docsFolder = Directory('/storage/emulated/0/Documents');
          if (!await docsFolder.exists()) {
            await docsFolder.create(recursive: true);
          }
          final savedFile = File('${docsFolder.path}/$fileName');
          await savedFile.writeAsBytes(bytes);
          successfulPaths.add(savedFile.path);
          debugPrint(
              '📄 [PDF DOWNLOAD SUCCESS] Saved to Documents: ${savedFile.path}');
        } catch (e) {
          debugPrint('📄 [PDF DOWNLOAD FAIL] Documents folder failed: $e');
          errors.add('Documents folder: $e');
        }

        // Path 3: Public - /storage/emulated/0/Download (My Files > Downloads)
        try {
          final downloadFolder = Directory('/storage/emulated/0/Download');
          if (!await downloadFolder.exists()) {
            await downloadFolder.create(recursive: true);
          }
          final savedFile = File('${downloadFolder.path}/$fileName');
          await savedFile.writeAsBytes(bytes);
          successfulPaths.add(savedFile.path);
          debugPrint(
              '📄 [PDF DOWNLOAD SUCCESS] Saved to Download: ${savedFile.path}');
        } catch (e) {
          debugPrint('📄 [PDF DOWNLOAD FAIL] Download folder failed: $e');
          errors.add('Download folder: $e');
        }
      }

      // Path 4: Fallback to App Documents Directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = File('${appDir.path}/$fileName');
        await savedFile.writeAsBytes(bytes);
        successfulPaths.add(savedFile.path);
        debugPrint(
            '📄 [PDF DOWNLOAD SUCCESS] Saved to App Documents: ${savedFile.path}');
      } catch (e) {
        debugPrint('📄 [PDF DOWNLOAD FAIL] App Documents failed: $e');
        errors.add('App Documents: $e');
      }

      if (successfulPaths.isNotEmpty) {
        final primaryPath = successfulPaths.firstWhere(
          (p) => p.contains('/Documents') || p.contains('/Download'),
          orElse: () => successfulPaths.first,
        );

        final isDocFolder = primaryPath.contains('/Documents');
        final folderLabel =
            isDocFolder ? 'My Files > Documents 📁' : 'My Files > Downloads 📥';

        Get.dialog(
          AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PDF Saved to Documents!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your document has been saved directly to your device storage:',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_special_rounded,
                              size: 18, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              folderLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        '📄 File: $fileName',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💾 Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Open your device "My Files" app -> tap "Documents" folder to view.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Get.back();
                  final targetPath = openablePath ?? primaryPath;
                  try {
                    final res = await OpenFilex.open(targetPath);
                    debugPrint(
                        '📄 [OPEN FILE RESULT] type: ${res.type}, message: ${res.message}');
                    if (res.type != ResultType.done) {
                      await viewPdf(null, urlOrBase64, title);
                    }
                  } catch (e) {
                    debugPrint('📄 [OPEN FILE ERROR] $e');
                    await viewPdf(null, urlOrBase64, title);
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      } else {
        throw Exception('All download paths failed: ${errors.join(", ")}');
      }
    } catch (e) {
      debugPrint('📄 [PDF DOWNLOAD FATAL ERROR] $e');
      AppSnackBar.showError(
        title: 'Download Error ❌',
        message: 'Could not save PDF to storage: ${e.toString()}',
      );
    }
  }
}
