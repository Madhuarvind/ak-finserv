import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../utils/localizations.dart';
import '../utils/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.translate('settings'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.translate('select_language'),
                  style: GoogleFonts.outfit(
                    fontSize: 24, 
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Change application appearance language',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                ),
                const SizedBox(height: 32),
                _buildLanguageCard(
                  context, 
                  'ta', 
                  context.translate('tamil'), 
                  '🇮🇳', 
                  languageProvider
                ),
                const SizedBox(height: 16),
                _buildLanguageCard(
                  context, 
                  'en', 
                  context.translate('english'), 
                  '🇺🇸', 
                  languageProvider
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageCard(
    BuildContext context, 
    String code, 
    String name, 
    String flag, 
    LanguageProvider provider
  ) {
    bool isSelected = provider.currentLocale.languageCode == code;
    return GestureDetector(
      onTap: () => provider.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFF1E1E1E), 
            width: 2
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.white,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
