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
  bool _isPinVisible = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final name = await _storage.read(key: 'user_name');
    final bioToken = await _storage.read(key: 'biometrics_enabled_$name');
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Text(
                            'AK Finserv',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _buildCircleAction(context, Icons.settings_outlined, '/settings'),
                            const SizedBox(width: 8),
                            _buildCircleAction(context, Icons.admin_panel_settings_outlined, '/admin/login'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 80),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.5)],
                              ),
                              boxShadow: [
                                 BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)
                              ]
                            ),
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                backgroundImage: const AssetImage('assets/logo.png'),
                                onBackgroundImageError: (exception, stackTrace) => const Icon(Icons.account_balance_rounded, color: AppTheme.primaryColor, size: 40),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            context.translate('worker_login'),
                            style: GoogleFonts.outfit(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.translate('worker_auth_subtitle'),
                            style: GoogleFonts.outfit(
                              color: Colors.white38, 
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            decoration: InputDecoration(
                              labelText: context.translate('worker_name'),
                              labelStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pinController,
                            obscureText: !_isPinVisible,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold, 
                              letterSpacing: _isPinVisible ? 2 : 12, 
                              color: Colors.white
                            ),
                            decoration: InputDecoration(
                              labelText: context.translate('pin'),
                              labelStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white38),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPinVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white38,
                                ),
                                onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                            ),
                          ),
                          if (_biometricsEnabled) ...[
                            const SizedBox(height: 24),
                            TextButton.icon(
                              onPressed: _handleBiometricLogin,
                              icon: const Icon(Icons.face_unlock_rounded, color: AppTheme.primaryColor),
                              label: Text(
                                "Quick Login with Face",
                                style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 32),
                      const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                    ],
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 10,
                          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.translate('login').toUpperCase(), 
                              style: GoogleFonts.outfit(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1)
                            ),
                            const SizedBox(width: 12),
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

  Widget _buildCircleAction(BuildContext context, IconData icon, String route) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
