import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  bool _isLoading = false;

  void _handleLogin(String name) async {
    setState(() => _isLoading = true);
    
    // 1. Try Offline Validation first (if user has logged in before on this device)
    final offlineError = await _localDbService.verifyPinOffline(name, _pinController.text);
    if (offlineError == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('logged_offline'))),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    // 2. If offline fails (not found or WRONG pin), try Online Validation
    try {
      final result = await _apiService.loginPin(name, _pinController.text);
      final msg = result['msg']?.toString().toLowerCase() ?? '';
      
      if (result.containsKey('access_token')) {
        await _apiService.saveTokens(
          result['access_token'], 
          result['refresh_token'] ?? ''
        );
        await _localDbService.saveUserLocally(
          name: name, 
          pin: _pinController.text,
          token: result['access_token'],
          role: result['role'],
          isActive: result['is_active'],
          isLocked: result['is_locked'],
        );
        setState(() => _isLoading = false);
        
        if (result['role'] == 'admin') {
          Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        setState(() => _isLoading = false);
        
        // If it was a connection error, and we already tried offline above, 
        // it means either the user is new or the offline PIN was genuinely wrong.
        if (msg.contains('connection_failed') || msg.contains('error')) {
          String displayError = context.translate(offlineError); // Show why offline failed (e.g. user not found)
          if (result.containsKey('details')) {
            displayError += "\nDetails: ${result['details']}";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(displayError)),
          );
        } else {
          _pinController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate(result['msg'] ?? 'invalid_pin'))),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final name = args?['name'] ?? '';

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.6),
                radius: 1.2,
                colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView( 
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_person_outlined, size: 48, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      context.translate('welcome'),
                      style: const TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      context.translate('enter_pin'),
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PinCodeTextField(
                      appContext: context,
                      length: 4,
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      animationType: AnimationType.fade,
                      textStyle: const TextStyle(color: AppTheme.primaryColor, fontSize: 24, fontWeight: FontWeight.bold),
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(16),
                        fieldHeight: 70,
                        fieldWidth: 70,
                        activeFillColor: AppTheme.surfaceColor,
                        selectedFillColor: AppTheme.surfaceColor,
                        inactiveFillColor: AppTheme.surfaceColor,
                        activeColor: AppTheme.primaryColor,
                        selectedColor: AppTheme.primaryColor,
                        inactiveColor: const Color(0xFF2A2A2A),
                        borderWidth: 2,
                      ),
                      enableActiveFill: true,
                      onChanged: (value) {},
                      onCompleted: (value) {
                        _handleLogin(name);
                      },
                    ),
                    const SizedBox(height: 48),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                    
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        context.translate('change'),
                        style: const TextStyle(color: Colors.white38),
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
