import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class CreateLoanScreen extends StatefulWidget {
  const CreateLoanScreen({super.key});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  List<dynamic> _customers = [];
  dynamic _selectedCustomer;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestController = TextEditingController(text: "10");
  final TextEditingController _tenureController = TextEditingController(text: "100");
  final TextEditingController _processingFeeController = TextEditingController(text: "0");
  
  String _tenureUnit = "days";
  String _interestType = "flat";
  String _guarantorName = "";
  String _guarantorMobile = "";
  String _guarantorRelation = "";

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final customers = await _apiService.getCustomers(token);
        setState(() {
          _customers = customers;
        });
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
    }
  }

  Future<void> _submitLoan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a customer")));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final data = {
          "customer_id": _selectedCustomer['id'],
          "amount": double.tryParse(_amountController.text) ?? 0,
          "interest_rate": double.tryParse(_interestController.text) ?? 0,
          "tenure": int.tryParse(_tenureController.text) ?? 0,
          "tenure_unit": _tenureUnit,
          "interest_type": _interestType,
          "processing_fee": double.tryParse(_processingFeeController.text) ?? 0,
          "guarantor_name": _guarantorName,
          "guarantor_mobile": _guarantorMobile,
          "guarantor_relation": _guarantorRelation,
        };

        final result = await _apiService.createLoan(data, token);
        
        if (result.containsKey('id')) {
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("Loan Created Successfully"), backgroundColor: Colors.green));
           Navigator.pop(context, true);
        } else {
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text("Error: ${result['error']}"), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Create New Loan", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Customer Details", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildDropdown<dynamic>(
                    label: "Select Customer",
                    value: _selectedCustomer,
                    icon: Icons.person_outline,
                    items: _customers.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text("${c['name']} (${c['mobile'] ?? 'N/A'})", style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedCustomer = val),
                  ),
                  const SizedBox(height: 32),
                  
                  Text("Loan Terms", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _amountController,
                    label: "Principal Amount (₹)",
                    icon: Icons.currency_rupee,
                    validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _interestController,
                          label: "Interest (%)",
                          icon: Icons.percent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown<String>(
                          label: "Type",
                          value: _interestType,
                          items: const [
                            DropdownMenuItem(value: "flat", child: Text("Flat Rate", style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: "reducing", child: Text("Reducing", style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) => setState(() => _interestType = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                       Expanded(
                        child: _buildTextField(
                          controller: _tenureController,
                          label: "Tenure",
                          icon: Icons.timer_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown<String>(
                          label: "Unit",
                          value: _tenureUnit,
                          items: const [
                            DropdownMenuItem(value: "days", child: Text("Days", style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: "weeks", child: Text("Weeks", style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: "months", child: Text("Months", style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) => setState(() => _tenureUnit = val!),
                        ),
                      ),
                    ],
                  ),
                   const SizedBox(height: 16),
                   _buildTextField(
                    controller: _processingFeeController,
                    label: "Processing Fee (₹)",
                    icon: Icons.payments_outlined,
                  ),
                  
                  const SizedBox(height: 32),
                  Text("Guarantor (Optional)", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "Guarantor Name",
                    icon: Icons.person_add_alt,
                    onChanged: (val) => _guarantorName = val,
                  ),
                  const SizedBox(height: 16),
                   _buildTextField(
                    label: "Guarantor Mobile",
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    onChanged: (val) => _guarantorMobile = val,
                  ),
                   const SizedBox(height: 16),
                   _buildTextField(
                    label: "Relation",
                    icon: Icons.family_restroom,
                    onChanged: (val) => _guarantorRelation = val,
                  ),
    
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitLoan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("CREATE LOAN DRAFT", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    IconData? icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.primaryColor, size: 20) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}
