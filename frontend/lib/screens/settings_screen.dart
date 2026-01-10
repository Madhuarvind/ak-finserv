import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.translate('settings'),
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.translate('select_language'),
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Change application appearance language",
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Tamil Card
                _buildLanguageCard(
                  context, 
                  'ta', 
                  context.translate('tamil'), 
                  '🇮🇳', 
                  languageProvider
                ),
                const SizedBox(height: 16),
                
                // English Card
                _buildLanguageCard(
                  context, 
                  'en', 
                  context.translate('english'), 
                  '🇺🇸', 
                  languageProvider
                ),
                
                const SizedBox(height: 16),

                _buildActionCard(
                  context,
                  "Security Hub",
                  "Manage your biometric and login security",
                  Icons.security,
                  const Color(0xFFEFF6FF),
                  const Color(0xFF3B82F6),
                  () => Navigator.pushNamed(context, '/security')
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageCard(BuildContext context, String code, String name, String flag, LanguageProvider provider) {
    final isSelected = provider.currentLocale.languageCode == code;
    final borderColor = isSelected ? const Color(0xFFB4F23E) : Colors.black;
    
    return InkWell(
      onTap: () => provider.setLanguage(code),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFFB4F23E) : Colors.black,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFB4F23E), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    Color iconBg, 
    Color iconColor,
    VoidCallback onTap
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black, size: 20),
          ],
        ),
      ),
    );
  }
}
