import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  final _storage = FlutterSecureStorage();
  bool _isLoading = false;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final bioToken = await _storage.read(key: 'biometrics_enabled');
    final name = await _storage.read(key: 'user_name');
    final token = await _storage.read(key: 'jwt_token');
    
    // Only allow biometric button if:
    // 1. User has successfully logged in before (has name & token)
    // 2. User explicitly enabled biometrics in settings
    if (mounted) {
      setState(() {
        _biometricsEnabled = (bioToken == 'true' && name != null && name.isNotEmpty && token != null);
      });
    }
  }

  void _handleBiometricLogin() async {
    final name = await _storage.read(key: 'user_name');
    if (name == null || name.isEmpty) return;
    
    if (!mounted) return;
    Navigator.pushNamed(context, '/verify_face', arguments: name);
  }

  void _handleLogin() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();

    if (name.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('failure'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Try Online Validation
    try {
      final result = await _apiService.loginPin(name, pin);
      setState(() => _isLoading = false);

      if (result.containsKey('access_token')) {
        await _apiService.saveTokens(
          result['access_token'], 
          result['refresh_token'] ?? ''
        );
        await _apiService.saveUserData(name, result['role'] ?? 'field_agent');
        
        await _localDbService.saveUserLocally(
          name: name, 
          pin: pin,
          token: result['access_token'],
          role: result['role'],
          isActive: result['is_active'],
          isLocked: result['is_locked'],
        );
        if (!mounted) return;
        
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (result['msg'] == 'requires_face_verification') {
        if (!mounted) return;
        Navigator.pushNamed(context, '/verify_face', arguments: name);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate(result['msg'] ?? 'failure'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection Failed: $e\nURL: ${ApiService.baseUrl}"),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          body: Container(
            color: AppTheme.backgroundColor,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AK Finserv',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: AppTheme.secondaryTextColor),
                              onPressed: () => Navigator.pushNamed(context, '/settings'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.secondaryTextColor),
                              onPressed: () => Navigator.pushNamed(context, '/admin/login'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_pin_rounded, size: 48, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      context.translate('worker_login'),
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.translate('worker_auth_subtitle'),
                      style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 16),
                    ),
                    const SizedBox(height: 48),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                      decoration: InputDecoration(
                        labelText: context.translate('worker_name'),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8, color: AppTheme.textColor),
                      decoration: InputDecoration(
                        labelText: context.translate('pin'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    if (_biometricsEnabled) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _handleBiometricLogin,
                          icon: const Icon(Icons.face_unlock_rounded, color: AppTheme.primaryColor),
                          label: Text(
                            "Login with Face",
                            style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                    if (_isLoading) ...[
                      const SizedBox(height: 32),
                      const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                    ],
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(context.translate('login'), style: const TextStyle(fontSize: 20, color: Colors.black)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 24, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Center(
                      child: Text(
                        "v1.5.2",
                        style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12),
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
