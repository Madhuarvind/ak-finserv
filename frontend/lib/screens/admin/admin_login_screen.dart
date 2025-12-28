import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _handleAdminLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('failure'))),
      );
      return;
    }

    try {
      final result = await _apiService.adminLogin(
        _usernameController.text, 
        _passwordController.text
      );
      setState(() => _isLoading = false);

      if (result.containsKey('access_token')) {
        await _apiService.saveTokens(
          result['access_token'], 
          result['refresh_token'] ?? ''
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('success'))),
        );
        
        Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate(result['msg'] ?? 'failure'))),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.5, -0.6),
                radius: 1.2,
                colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security_rounded, size: 48, color: AppTheme.errorColor),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      context.translate('admin_login'),
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.translate('admin_auth_subtitle'),
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                    const SizedBox(height: 48),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: context.translate('username'),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: context.translate('password'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAdminLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(context.translate('login'), style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                const Icon(Icons.shield_outlined, size: 24),
                              ],
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
