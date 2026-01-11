import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'package:intl/intl.dart';

class PublicPassbookScreen extends StatefulWidget {
  final String token;
  const PublicPassbookScreen({super.key, required this.token});

  @override
  State<PublicPassbookScreen> createState() => _PublicPassbookScreenState();
}

class _PublicPassbookScreenState extends State<PublicPassbookScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _passbook;

  @override
  void initState() {
    super.initState();
    _fetchPassbook();
  }

  Future<void> _fetchPassbook() async {
    final res = await _apiService.getPublicPassbook(widget.token);
    if (mounted) {
      setState(() {
        if (res.containsKey('customer_name')) {
          _passbook = res;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Digital Passbook", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _passbook == null
          ? _buildErrorView()
          : _buildPassbookView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text("Passbook Link Invalid", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("The link might be expired or incorrect."),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  Widget _buildPassbookView() {
    final loan = _passbook!['active_loan'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(DateTime.now()),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_passbook!['customer_name'] ?? 'Customer', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(_passbook!['customer_id'] ?? 'ID: Unknown', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          Text("ACTIVE LOAN SUMMARY", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 16),
          
          if (loan == null)
            _buildNoLoanCard()
          else
            _buildLoanCard(loan),
            
          const SizedBox(height: 48),
          Center(
            child: Text(
              "Powered by Arun Finance Digital Systems",
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLoanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey[300], size: 48),
          const SizedBox(height: 16),
          const Text("No active loans found for this profile.", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildDetailRow("Loan ID", loan['loan_id'] ?? 'N/A'),
          const Divider(height: 32),
          _buildDetailRow("Loan Amount", "₹${loan['principal']}", isBold: true),
          const SizedBox(height: 12),
          _buildDetailRow("Pending Balance", "₹${loan['pending']}", valueColor: Colors.red, isBold: true),
          const SizedBox(height: 12),
          _buildDetailRow("Tenure", loan['tenure'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(
          value, 
          style: GoogleFonts.outfit(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
            color: valueColor ?? Colors.black
          )
        ),
      ],
    );
  }
}
