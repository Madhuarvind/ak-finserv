import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';

class MasterSettingsScreen extends StatefulWidget {
  const MasterSettingsScreen({super.key});

  @override
  State<MasterSettingsScreen> createState() => _MasterSettingsScreenState();
}

class _MasterSettingsScreenState extends State<MasterSettingsScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _interestRateController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _gracePeriodController = TextEditingController();
  final _maxLoanController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _upiQrUrlController = TextEditingController();
  
  // Toggles
  bool _workerCanEditCustomer = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final settings = await _apiService.getSystemSettings(token);
      if (mounted) {
        setState(() {
          _interestRateController.text = settings['default_interest_rate'] ?? '10.0';
          _penaltyController.text = settings['penalty_amount'] ?? '50.0';
          _gracePeriodController.text = settings['grace_period_days'] ?? '3';
          _maxLoanController.text = settings['max_loan_amount'] ?? '50000.0';
          _upiIdController.text = settings['upi_id'] ?? 'arun.finance@okaxis';
          _upiQrUrlController.text = settings['upi_qr_url'] ?? '';
          _workerCanEditCustomer = (settings['worker_can_edit_customer'] ?? 'false') == 'true';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final data = {
        "default_interest_rate": _interestRateController.text,
        "penalty_amount": _penaltyController.text,
        "grace_period_days": _gracePeriodController.text,
        "max_loan_amount": _maxLoanController.text,
        "upi_id": _upiIdController.text,
        "upi_qr_url": _upiQrUrlController.text,
        "worker_can_edit_customer": _workerCanEditCustomer.toString(),
      };
      
      final result = await _apiService.updateSystemSettings(data, token);
      if (mounted) {
         setState(() => _isLoading = false);
         if (result['msg'] == 'Settings updated successfully') {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings updated!")));
           Navigator.pop(context);
         } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${result['msg']}")));
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Global Configuration", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: AppTheme.primaryColor),
            onPressed: _saveSettings,
          )
        ],
      ),
      body: _isLoading 
         ? const Center(child: CircularProgressIndicator())
         : SingleChildScrollView(
             padding: const EdgeInsets.all(24),
             child: Form(
               key: _formKey,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _buildSectionHeader("Default Loan Terms"),
                   _buildCard([
                     _buildTextField("Default Interest Rate (%)", _interestRateController, icon: Icons.percent),
                     _buildTextField("Max Loan Amount (₹)", _maxLoanController, icon: Icons.currency_rupee),
                   ]),
                   
                   const SizedBox(height: 24),
                   _buildSectionHeader("Penalties & Rules"),
                   _buildCard([
                     _buildTextField("Penalty Amount (₹)", _penaltyController, icon: Icons.warning_amber),
                     _buildTextField("Grace Period (Days)", _gracePeriodController, icon: Icons.calendar_today),
                   ]),
                   
                   const SizedBox(height: 24),
                   _buildSectionHeader("UPI Payment (Collection)"),
                   _buildCard([
                     _buildTextField("Default UPI ID", _upiIdController, icon: Icons.account_balance_wallet_rounded),
                     _buildTextField("Custom QR Image URL (Optional)", _upiQrUrlController, icon: Icons.image_rounded),
                   ]),
                   
                   const SizedBox(height: 24),
                   _buildSectionHeader("Permissions"),
                   _buildCard([
                     SwitchListTile(
                       title: Text("Field Agents Can Edit Customers", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                       subtitle: const Text("Allow workers to modify customer details after creation"),
                       value: _workerCanEditCustomer,
                       activeThumbColor: AppTheme.primaryColor,
                       onChanged: (val) => setState(() => _workerCanEditCustomer = val),
                     )
                   ]),
                   
                   const SizedBox(height: 32),
                   SizedBox(
                     width: double.infinity,
                     height: 50,
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.primaryColor,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       onPressed: _saveSettings,
                       child: Text("Save Configuration", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                     ),
                   )
                 ],
               ),
             ),
           ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: AppTheme.primaryColor) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppTheme.backgroundColor,
        ),
        validator: (val) => val == null || val.isEmpty ? "Required" : null,
      ),
    );
  }
}
