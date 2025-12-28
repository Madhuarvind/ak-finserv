import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LocalDbService _localDbService = LocalDbService();
  bool _isConfirming = false;
  bool _isLoading = false;

  void _handleSetPin(String name) async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.setPin(name, _pinController.text);
      final msg = result['msg']?.toString().toLowerCase() ?? '';
      
      if (result.containsKey('msg') && (msg.contains('success') || msg.contains('successfully'))) {
        await _localDbService.saveUserLocally(
          name: name, 
          pin: _pinController.text
        );
        setState(() => _isLoading = false);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate(result['msg'] ?? 'failure'))),
        );
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
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final name = args['name'] ?? args['mobile_number'] ?? '';

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: AppTheme.primaryColor),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    _isConfirming ? context.translate('confirm_pin') : context.translate('set_pin'), 
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.translate('pin_usage_info'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  PinCodeTextField(
                    appContext: context,
                    length: 4,
                    controller: _isConfirming ? _confirmPinController : _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(12),
                      fieldHeight: 60,
                      fieldWidth: 60,
                      activeFillColor: Colors.white,
                      selectedFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                      activeColor: AppTheme.primaryColor,
                      selectedColor: AppTheme.accentColor,
                      inactiveColor: Colors.grey.shade300,
                    ),
                    enableActiveFill: true,
                    onChanged: (value) {},
                    onCompleted: (value) {
                      if (!_isConfirming) {
                        setState(() {
                          _isConfirming = true;
                        });
                      } else {
                        _handleSetPin(name);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      if (!_isConfirming) {
                         setState(() => _isConfirming = true);
                      } else {
                        _handleSetPin(name);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(context.translate('save'), style: const TextStyle(fontSize: 20)),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (_isConfirming && !_isLoading)
                    TextButton(
                      onPressed: () => setState(() => _isConfirming = false),
                      child: Text(context.translate('change'), style: const TextStyle(fontSize: 18)),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
