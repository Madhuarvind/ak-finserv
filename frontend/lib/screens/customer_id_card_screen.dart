import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/theme.dart';

class CustomerIdCardScreen extends StatelessWidget {
  final Map<String, dynamic> customer;

  const CustomerIdCardScreen({super.key, required this.customer});

  Future<void> _printCard(BuildContext context) async {
    try {
      final doc = pw.Document();

      // Standard ID card size: 85.6mm x 54mm
      final cardFormat = PdfPageFormat.roll80.copyWith(
        width: 85.6 * PdfPageFormat.mm,
        height: 54.0 * PdfPageFormat.mm,
        marginTop: 0,
        marginBottom: 0,
        marginLeft: 0,
        marginRight: 0,
      );

      doc.addPage(
        pw.Page(
          pageFormat: cardFormat,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.green700,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                   pw.Expanded(
                     child: pw.Column(
                       crossAxisAlignment: pw.CrossAxisAlignment.start,
                       children: [
                         pw.Text(
                           'ARUN FINANCE',
                           style: pw.TextStyle(
                             color: PdfColors.white,
                             fontSize: 10,
                             fontWeight: pw.FontWeight.bold,
                           ),
                         ),
                         pw.SizedBox(height: 4),
                         pw.Text(
                           customer['name']?.toString().toUpperCase() ?? 'N/A',
                           style: pw.TextStyle(
                             color: PdfColors.white,
                             fontSize: 12,
                             fontWeight: pw.FontWeight.bold,
                           ),
                           maxLines: 1,
                         ),
                         pw.Spacer(),
                         pw.Text(
                           'ID: ${customer['customer_id'] ?? 'N/A'}',
                           style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
                         ),
                         pw.Text(
                           'MOB: ${customer['mobile'] ?? 'N/A'}',
                           style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
                         ),
                         pw.Text(
                           'AREA: ${customer['area'] ?? 'N/A'}',
                           style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
                         ),
                       ],
                     ),
                   ),
                   pw.SizedBox(width: 8),
                   pw.Column(
                     mainAxisAlignment: pw.MainAxisAlignment.center,
                     children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          color: PdfColors.white,
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: customer['customer_id'] ?? '',
                            width: 50,
                            height: 50,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('PASSBOOK QR', style: const pw.TextStyle(color: PdfColors.white, fontSize: 5)),
                     ],
                   ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'ID_Card_${customer['customer_id']}.pdf',
        format: cardFormat,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Customer ID Card', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Card',
            onPressed: () => _printCard(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Customer Card Generated!',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Print or save this card for the customer',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _buildIdCard(),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('Done', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => _printCard(context),
                    icon: const Icon(Icons.print),
                    label: const Text('Print Card'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildIdCard() {
    return Container(
      width: 400,
      height: 250,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF7CB342)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -30,
            top: -30,
            child: Opacity(
              opacity: 0.1,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: -50,
            child: Opacity(
              opacity: 0.1,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ARUN FINANCE',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'CUSTOMER',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Customer details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer['name'] ?? 'N/A',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ID: ${customer['customer_id'] ?? 'N/A'}',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customer['mobile'] ?? 'N/A',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: customer['customer_id'] ?? '',
                        version: QrVersions.auto,
                        size: 80,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
