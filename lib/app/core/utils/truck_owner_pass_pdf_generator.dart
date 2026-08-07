import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Professional PDF Generator for Truck Owner Pass / Vehicle Loading Permit.
/// Converts admin-entered pass details into an official PDF document.
class TruckOwnerPassPdfGenerator {
  TruckOwnerPassPdfGenerator._();

  /// Generate raw PDF bytes ([Uint8List]) from pass details.
  static Future<Uint8List> generatePdfBytes({
    required String passId,
    required String ownerName,
    required String tripId,
    String? remarks,
    String? truckNo,
    String? driverName,
    String? driverPhone,
    String? pickupLocation,
    String? dropCity,
    String? generatedAt,
  }) async {
    final pdf = pw.Document();

    final formattedDate = (generatedAt != null && generatedAt.isNotEmpty)
        ? generatedAt
        : DateTime.now().toString().substring(0, 16);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal, width: 2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'HIGHWAY TERMINAL LOGISTICS',
                          style: const pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal800,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'OFFICIAL TRUCK OWNER PASS / LOADING PERMIT',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    // Badge
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        border: pw.Border.all(color: PdfColors.green700),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        'VERIFIED & APPROVED',
                        style: const pw.TextStyle(
                          color: PdfColors.green900,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.teal200, thickness: 1.5),
                pw.SizedBox(height: 16),

                // Pass ID Banner Box
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.teal300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PASS ID NUMBER',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            passId.isNotEmpty ? passId : 'TOP-PASS',
                            style: const pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'ISSUE DATE & TIME',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            formattedDate,
                            style: const pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Details Grid
                pw.Text(
                  'TRANSPORT & VEHICLE DETAILS',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Table(
                  border: pw.TableBorder.all(
                      color: PdfColors.grey300, width: 0.8),
                  children: [
                    _buildRow('Truck Owner / Transporter',
                        ownerName.isNotEmpty ? ownerName : 'N/A'),
                    _buildRow('Trip Reference ID',
                        tripId.isNotEmpty ? tripId : 'N/A'),
                    _buildRow('Vehicle / Truck No',
                        (truckNo ?? '').isNotEmpty ? truckNo! : 'N/A'),
                    _buildRow(
                        'Assigned Driver',
                        (driverName ?? '').isNotEmpty
                            ? '$driverName ${(driverPhone ?? '').isNotEmpty ? '($driverPhone)' : ''}'
                            : 'N/A'),
                    _buildRow('Pickup Point / Vendor',
                        (pickupLocation ?? '').isNotEmpty ? pickupLocation! : 'N/A'),
                    _buildRow('Destination City',
                        (dropCity ?? '').isNotEmpty ? dropCity! : 'N/A'),
                    if (remarks != null && remarks.trim().isNotEmpty)
                      _buildRow('Admin Remarks / Notes', remarks.trim()),
                  ],
                ),

                pw.Spacer(),

                // Stamp Box & Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.green600, width: 1.5),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'DIGITALLY VERIFIED',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.green800,
                                ),
                              ),
                              pw.Text(
                                'Highway Terminal Admin Portal',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          width: 140,
                          child: pw.Divider(color: PdfColors.grey400, thickness: 1),
                        ),
                        pw.Text(
                          'Authorized Admin Stamp',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),

                // Footer Note
                pw.Divider(color: PdfColors.grey300, thickness: 1),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'This is a computer-generated digital Truck Owner Pass issued for transit verification. No physical signature required.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Base64 Data URI (`data:application/pdf;base64,...`) for web / inline viewing.
  static Future<String> generatePdfBase64({
    required String passId,
    required String ownerName,
    required String tripId,
    String? remarks,
    String? truckNo,
    String? driverName,
    String? driverPhone,
    String? pickupLocation,
    String? dropCity,
    String? generatedAt,
  }) async {
    try {
      final bytes = await generatePdfBytes(
        passId: passId,
        ownerName: ownerName,
        tripId: tripId,
        remarks: remarks,
        truckNo: truckNo,
        driverName: driverName,
        driverPhone: driverPhone,
        pickupLocation: pickupLocation,
        dropCity: dropCity,
        generatedAt: generatedAt,
      );
      final b64 = base64Encode(bytes);
      return 'data:application/pdf;base64,$b64';
    } catch (e) {
      debugPrint('🚨 [PDF GENERATE FAIL] $e');
      rethrow;
    }
  }

  static pw.TableRow _buildRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }
}
