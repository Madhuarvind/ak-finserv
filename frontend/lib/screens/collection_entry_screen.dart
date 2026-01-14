import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';

import '../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CollectionEntryScreen extends StatefulWidget {
  const CollectionEntryScreen({super.key});

  @override
  State<CollectionEntryScreen> createState() => _CollectionEntryScreenState();
}

class _CollectionEntryScreenState extends State<CollectionEntryScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  int _currentStep = 0;
  List<dynamic> _customers = [];
  Map<String, dynamic>? _selectedCustomer;
  List<dynamic> _loans = [];
  Map<String, dynamic>? _selectedLoan;
  
  final TextEditingController _amountController = TextEditingController();
  String _paymentMode = 'cash';
  bool _isLoading = false;
  Position? _currentPosition;
  Map<String, dynamic> _systemSettings = {};
  int? _lineId;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    
    // Check for pre-selected customer from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        final Map<String, dynamic> customerData = Map<String, dynamic>.from(args);
        setState(() {
          _selectedCustomer = customerData;
          _lineId = customerData['line_id'];
          // Use id or customer_id depending on context
          final cid = customerData['id'] ?? customerData['customer_id'];
          if (cid != null) {
             _currentStep = 1; // Advance to Amount step
             _fetchLoans(cid);
          }
        });
      }
    });
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getCustomers(token);
      setState(() {
        _customers = result;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLoans(int customerId) async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getCustomerLoans(customerId, token);
      setState(() {
        _loans = result;
        _isLoading = false;
      });
      _fetchSettings();
    }
  }

  Future<void> _fetchSettings() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final settings = await _apiService.getSystemSettings(token);
      if (mounted) {
        setState(() => _systemSettings = settings);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {

      return;

    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {

        return;

      }
    }
    
    if (permission == LocationPermission.deniedForever) {

    
      return;

    
    }

    final pos = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = pos);
  }

  Future<void> _submit() async {
    if (_selectedLoan == null || _amountController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    await _getCurrentLocation(); 
    
    final collectionData = {
      'loan_id': _selectedLoan!['id'],
      'amount': double.parse(_amountController.text),
      'payment_mode': _paymentMode,
      'latitude': _currentPosition?.latitude,
      'longitude': _currentPosition?.longitude,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      
      final result = await _apiService.submitCollection(
        loanId: collectionData['loan_id'] as int,
        amount: collectionData['amount'] as double,
        paymentMode: collectionData['payment_mode'] as String,
        lineId: _lineId,
        latitude: collectionData['latitude'] as double?,
        longitude: collectionData['longitude'] as double?,
        token: token,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['status'] == 'flagged') {
          // AI Fraud Alert
          _showFraudWarningDialog(result['fraud_warning'] ?? ["Unknown anomaly detected"]);
        } else if (result['msg']?.contains('success') ?? false) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collection submitted successfully! Awaiting admin approval.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result['msg']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Fallback to local save if server fails
        final LocalDbService localDb = LocalDbService();
        await localDb.addCollectionLocally(collectionData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline: Collection saved locally!'), backgroundColor: Colors.blue),
        );
        Navigator.pop(context, true);
      }
    }
  }

  void _showFraudWarningDialog(List<dynamic> warnings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text("AI Security Warning", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This collection has been flagged for Admin review due to:"),
            const SizedBox(height: 12),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text("• $w", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
            )),
            const SizedBox(height: 12),
            const Text("You can continue, but the payment won't reflect until verified by the office.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context); // Close dialog
               Navigator.pop(context, true); // Go back
            },
            child: const Text("I UNDERSTAND"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(context.translate('collection'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading && _currentStep == 0
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0 && _selectedCustomer != null) {
                  _fetchLoans(_selectedCustomer!['id']);
                  setState(() => _currentStep++);
                } else if (_currentStep == 1 && _selectedLoan != null && _amountController.text.isNotEmpty) {
                  setState(() => _currentStep++);
                } else if (_currentStep == 2) {
                  _submit();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {

                  setState(() => _currentStep--);

                }
              },
              steps: [
                Step(
                  title: const Text('Customer'),
                  isActive: _currentStep >= 0,
                  content: _buildCustomerSelection(),
                ),
                Step(
                  title: const Text('Amount'),
                  isActive: _currentStep >= 1,
                  content: _buildAmountEntry(),
                ),
                Step(
                  title: const Text('Review'),
                  isActive: _currentStep >= 2,
                  content: _buildReview(),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomerSelection() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search customer...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (val) {
             // Basic local filter if needed
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: _customers.length,
            itemBuilder: (context, index) {
              final item = _customers[index];
              if (item is! Map) return const SizedBox.shrink();
              final c = item as Map<String, dynamic>;
              final isSelected = _selectedCustomer?['id'] == c['id'];
              return ListTile(
                selected: isSelected,
                selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(c['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text("${c['area'] ?? ''} • ${c['mobile'] ?? ''}"),
                onTap: () => setState(() => _selectedCustomer = c),
                trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loans.isEmpty)
          const Text('No active loans found for this customer', style: TextStyle(color: Colors.red))
        else
          DropdownButtonFormField<Map<String, dynamic>>(
            decoration: InputDecoration(
              labelText: 'Select Loan',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _loans.whereType<Map>().map((l) {
              final mapLoan = l as Map<String, dynamic>;
              return DropdownMenuItem(
                value: mapLoan,
                child: Text("Loan #${mapLoan['loan_id'] ?? mapLoan['id']} - Bal: ₹${mapLoan['pending'] ?? mapLoan['amount']}"),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedLoan = val),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Collection Amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold)),
        Column(
          children: [
            RadioListTile<String>(
              title: const Text('Cash'),
              value: 'cash',
              // ignore: deprecated_member_use
              groupValue: _paymentMode,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _paymentMode = v!),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              title: const Text('UPI'),
              value: 'upi',
              // ignore: deprecated_member_use
              groupValue: _paymentMode,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _paymentMode = v!),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        if (_paymentMode == 'upi') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pay to UPI ID", style: GoogleFonts.outfit(fontSize: 12, color: Colors.indigo[900], fontWeight: FontWeight.bold)),
                    _buildCopyButton(_systemSettings['upi_id'] ?? 'arun.finance@okaxis'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _systemSettings['upi_id'] ?? 'arun.finance@okaxis',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.indigo[900]),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showQRCodeDialog(context),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text("SHOW QR CODE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCopyButton(String text) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI ID copied to clipboard"), behavior: SnackBarBehavior.floating));
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.copy_rounded, size: 16, color: Colors.indigo[900]),
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context) {
    final upiId = _systemSettings['upi_id'] ?? 'arun.finance@okaxis';
    final amount = _amountController.text;
    final amountStr = amount.isEmpty ? '0' : amount; // Ensure amount is not empty for UPI URL
    final upiUrl = "upi://pay?pa=$upiId&pn=${Uri.encodeComponent('AK Finserv')}&am=$amountStr&cu=INR";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Center(child: Text("Scan to Pay", style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_systemSettings['upi_qr_url'] != null && _systemSettings['upi_qr_url'].toString().isNotEmpty)
              Image.network(_systemSettings['upi_qr_url'].toString(), height: 200, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50))
            else
              SizedBox(
                height: 200,
                width: 200,
                child: QrImageView(
                  data: upiUrl,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
            const SizedBox(height: 16),
            Text("₹$amount", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(upiId, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      children: [
        _buildReviewRow('Customer', _selectedCustomer?['name'] ?? ''),
        _buildReviewRow('Loan ID', _selectedLoan?['id'].toString() ?? ''),
        _buildReviewRow('Amount', '₹ ${_amountController.text}'),
        _buildReviewRow('Mode', _paymentMode.toUpperCase()),
        const SizedBox(height: 20),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          const Text('GPS will be captured upon submission', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
