import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AddAgentScreen extends StatefulWidget {
  const AddAgentScreen({super.key});

  @override
  State<AddAgentScreen> createState() => _AddAgentScreenState();
}

class _AddAgentScreenState extends State<AddAgentScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _idProofController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _handleRegister() async {
    if (_nameController.text.isEmpty || _mobileController.text.length != 10 || _pinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('name_required'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    final token = await _apiService.getToken();
    if (token != null) {
      final result = await _apiService.registerWorker(
        _nameController.text, 
        _mobileController.text, 
        _pinController.text,
        token,
        area: _areaController.text,
        address: _addressController.text,
        idProof: _idProofController.text,
      );
      
      final msg = result['msg']?.toString().toLowerCase() ?? '';
      if (result.containsKey('msg') && msg.contains('successfully')) {
        int userId = result['user_id'];
        String qrToken = result['qr_token'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('worker_added'))),
        );
        
        // Navigate to Face Registration next
        Navigator.pushReplacementNamed(
          context, 
          '/admin/face_register',
          arguments: {
            'user_id': userId,
            'name': _nameController.text,
            'qr_token': qrToken,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['msg'] ?? context.translate('failure'))),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.translate('add_worker'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personnel Details',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: context.translate('worker_name'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: context.translate('mobile_number'),
                    prefixIcon: const Icon(Icons.phone_iphone_rounded),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 4),
                  decoration: InputDecoration(
                    labelText: 'Login PIN',
                    prefixIcon: const Icon(Icons.password_rounded),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Area & Identity',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _areaController,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: context.translate('area'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: context.translate('address'),
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _idProofController,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: context.translate('id_proof'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          context.translate('create_worker'), 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)
                        ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
