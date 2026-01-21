import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';

import '../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedPath;
  int? _audioNoteId;

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

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    // Upload audio note if exists
    if (_recordedPath != null) {
      // Logic for audio note upload
      final audioResult = await _apiService.uploadAudioNote(
        filePath: _recordedPath!,
        token: token,
        customerId: _selectedCustomer?['id'],
        loanId: _selectedLoan?['id'],
      );
      if (mounted) {
        setState(() {
          _audioNoteId = audioResult['id'];
        });
      }
    }

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
        audioNoteId: _audioNoteId,
        token: token,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['status'] == 'flagged') {
          // AI Fraud Alert
          _showFraudWarningDialog(result['fraud_warning'] ?? ["Unknown anomaly detected"]);
        } else if (result['msg']?.contains('success') ?? false) {
          _showSuccessSheet();
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

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B), // Dark Slate
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 80),
            ),
            const SizedBox(height: 32),
            Text(
              "Collection Published!",
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              "Awaiting manager verification.\nThe digital passbook has been updated.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.pop(context, true); // Go back to dashboard
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text("DONE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('collection'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
            // Custom Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Customer'),
                  _buildStepConnector(0),
                  _buildStepIndicator(1, 'Amount'),
                  _buildStepConnector(1),
                  _buildStepIndicator(2, 'Review'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading && _currentStep == 0
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildCurrentStepChild(),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              if (_currentStep > 0)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _currentStep--),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Text('BACK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white60)),
                                  ),
                                ),
                              if (_currentStep > 0) const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: (_currentStep == 0 && _selectedCustomer == null) || (_currentStep == 1 && (_selectedLoan == null || _amountController.text.isEmpty))
                                      ? null 
                                      : () {
                                          if (_currentStep == 0) {
                                            _fetchLoans(_selectedCustomer!['id']);
                                            setState(() => _currentStep++);
                                          } else if (_currentStep == 1) {
                                            setState(() => _currentStep++);
                                          } else {
                                            _submit();
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                    child: Text(_currentStep == 2 ? 'SUBMIT' : 'CONTINUE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCurrent = _currentStep == step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCurrent ? AppTheme.primaryColor : (isActive ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1)),
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.1), width: 2),
          ),
          child: Center(
            child: isActive && !isCurrent 
              ? const Icon(Icons.check, size: 16, color: AppTheme.primaryColor)
              : Text('${step + 1}', style: TextStyle(color: isCurrent ? Colors.black : Colors.white24, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: isCurrent ? FontWeight.w900 : FontWeight.normal, color: isCurrent ? Colors.white : Colors.white38, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildStepConnector(int step) {
    bool isActive = _currentStep > step;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 2,
        color: isActive ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildCurrentStepChild() {
    switch (_currentStep) {
      case 0: return _buildCustomerSelection();
      case 1: return _buildAmountEntry();
      case 2: return _buildReview();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildCustomerSelection() {
    return Column(
      key: const ValueKey(0),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: TextField(
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search customer...',
              hintStyle: GoogleFonts.outfit(color: Colors.white24),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _customers.length,
            itemBuilder: (context, index) {
              final item = _customers[index];
              if (item is! Map) return const SizedBox.shrink();
              final c = item as Map<String, dynamic>;
              final isSelected = _selectedCustomer?['id'] == c['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedCustomer = c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05), width: 1),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.1),
                        child: Icon(Icons.person_rounded, color: isSelected ? Colors.black : Colors.white38),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            Text("${c['area'] ?? ''} • ${c['mobile'] ?? ''}", style: TextStyle(color: Colors.white38, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountEntry() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loans.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Text('No active loans found', style: GoogleFonts.outfit(color: Colors.red[900], fontWeight: FontWeight.bold)),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SELECT ACTIVE LOAN', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                items: _loans.whereType<Map>().map((l) {
                  final mapLoan = l as Map<String, dynamic>;
                  return DropdownMenuItem(
                    value: mapLoan,
                    child: Text("Loan #${mapLoan['loan_id'] ?? mapLoan['id']} - ₹${mapLoan['pending'] ?? mapLoan['amount']}", style: GoogleFonts.outfit(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedLoan = val),
              ),
            ],
          ),
        const SizedBox(height: 24),
        const SizedBox(height: 24),
        Text('COLLECTION AMOUNT', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.outfit(color: Colors.white24),
            prefixText: '₹ ',
            prefixStyle: GoogleFonts.outfit(color: Colors.white),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: _buildModeTile('cash', Icons.payments_outlined, 'Cash')),
            const SizedBox(width: 16),
            Expanded(child: _buildModeTile('upi', Icons.qr_code_2_rounded, 'UPI')),
          ],
        ),
        if (_paymentMode == 'upi') ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.2), blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.translate('pay_to_upi_id'), style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
                    _buildCopyButton(_systemSettings['upi_id'] ?? 'arun.finance@okaxis'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _systemSettings['upi_id'] ?? 'arun.finance@okaxis',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final amount = double.tryParse(_amountController.text) ?? 0.0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('enter_valid_amount_first'))));
                        return;
                      }
                      Navigator.pushNamed(context, '/collection/upi', arguments: {
                        'amount': amount,
                        'customer_name': _selectedCustomer?['name'] ?? 'Unknown',
                        'loan_id': _selectedLoan?['loan_id']?.toString() ?? _selectedLoan?['id']?.toString() ?? 'N/A',
                      });
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(context.translate('generate_dynamic_qr')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildModeTile(String mode, IconData icon, String label) {
    bool isSelected = _paymentMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05)),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.2), blurRadius: 16)] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white38),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyButton(String text) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('upi_id_copied')), behavior: SnackBarBehavior.floating));
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      key: const ValueKey(2),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              _buildReviewRow('Customer', _selectedCustomer?['name'] ?? '', isTitle: true),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: Colors.white12),
              ),
              _buildReviewRow('Loan Reference', '#${_selectedLoan?['loan_id'] ?? _selectedLoan?['id']}'),
              _buildReviewRow('Payment Mode', _paymentMode.toUpperCase()),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL AMOUNT', style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    Text('₹ ${_amountController.text}', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.amber[800], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'GPS will be captured upon submission for security purposes.',
                  style: GoogleFonts.outfit(color: Colors.amber[900], fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildVoiceNoteSection(),
      ],
    );
  }

  Widget _buildVoiceNoteSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 12),
              Text("AI VOICE FIELD NOTE", style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 16),
          if (_recordedPath == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: _isRecording ? Colors.redAccent : Colors.black),
                label: Text(_isRecording ? "STOP RECORDING" : "TAP TO RECORD UPDATE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _isRecording ? Colors.redAccent : Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.redAccent.withValues(alpha: 0.1) : AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Text("Recording Saved", style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => setState(() => _recordedPath = null),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                ),
              ],
            ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(child: Text("Recording in progress...", style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
            ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status == PermissionStatus.permanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Microphone permission permanently denied. Please enable in settings."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission is required to record voice notes.")),
          );
        }
        return;
      }

      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig();
      await _audioRecorder.start(config, path: path);
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error starting recorder: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error stopping recorder: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Widget _buildReviewRow(String label, String value, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(
            value, 
            style: GoogleFonts.outfit(
              fontWeight: isTitle ? FontWeight.w900 : FontWeight.bold, 
              fontSize: isTitle ? 18 : 14,
              color: Colors.white,
            )
          ),
        ],
      ),
    );
  }
}

