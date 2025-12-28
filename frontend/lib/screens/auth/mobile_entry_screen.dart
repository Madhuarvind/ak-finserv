import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class MobileEntryScreen extends StatefulWidget {
  const MobileEntryScreen({super.key});

  @override
  State<MobileEntryScreen> createState() => _MobileEntryScreenState();
}

class _MobileEntryScreenState extends State<MobileEntryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    final user = await _localDbService.getLastUser();
    if (user != null) {
      Navigator.pushReplacementNamed(
        context, 
        '/'
      );
    }
  }

  void _handleContinue() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('error_name'))),
      );
      return;
    }

    Navigator.pushNamed(
      context, 
      '/'
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.6),
                radius: 1.2,
                colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vasool Drive',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white70),
                          onPressed: () => Navigator.pushNamed(context, '/admin/login'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      context.translate('worker_login'),
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.translate('worker_name'),
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _nameController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
                      decoration: InputDecoration(
                        hintText: "Enter Name",
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 28),
                        contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleContinue,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(context.translate('continue')),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/settings'),
                        child: Text(
                          context.translate('settings'),
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
