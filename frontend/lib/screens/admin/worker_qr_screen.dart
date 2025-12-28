import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/theme.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkerQrScreen extends StatelessWidget {
  final int userId;
  final String name;
  final String qrToken;

  const WorkerQrScreen({
    super.key, 
    required this.userId, 
    required this.name,
    required this.qrToken,
  });

  @override
  Widget build(BuildContext context) {
    final String qrData = qrToken;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.translate('worker_qr'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Digital Identity Token',
                  style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.7), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 240.0,
                      foregroundColor: Colors.black, // High contrast black on white for reliability
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          context.translate('qr_footer'),
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, ModalRoute.withName('/admin/dashboard'));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(
                      context.translate('done').toUpperCase(), 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
