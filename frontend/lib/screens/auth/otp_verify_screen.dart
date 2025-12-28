import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _handleVerifyOtp(String mobileNumber, bool isAdminFlow) async {
    if (_otpController.text.length != 4) return;

    setState(() => _isLoading = true);
    
    Map<String, dynamic> result;
    if (isAdminFlow) {
      result = await _apiService.adminVerify(mobileNumber, _otpController.text);
    } else {
      result = await _apiService.verifyOtp(mobileNumber, _otpController.text);
    }
    
    setState(() => _isLoading = false);

    if (result.containsKey('access_token')) {
      await _apiService.saveTokens(
        result['access_token'], 
        result['refresh_token'] ?? ''
      );
      if (isAdminFlow) {
        Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
      } else if (result['is_first_login'] == true) {
        Navigator.pushNamed(context, '/set_pin', arguments: {'mobile_number': mobileNumber});
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['msg'] ?? context.translate('invalid_otp'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final mobileNumber = args['mobile_number'];
    final isAdminFlow = args['is_admin_flow'] ?? false;

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
                    context.translate('otp_arrived'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.translate('enter_otp'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  PinCodeTextField(
                    appContext: context,
                    length: 4,
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(12),
                      fieldHeight: 70,
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
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleVerifyOtp(mobileNumber, isAdminFlow),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(context.translate('confirm'), style: const TextStyle(fontSize: 20)),
                  ),
                  const Spacer(),
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
