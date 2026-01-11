import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'edit_customer_screen.dart';
import 'add_loan_screen.dart';
import 'emi_schedule_screen.dart';
import 'loan_documents_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _riskAnalysis;
  Map<String, dynamic>? _behaviorAnalysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final data = await _apiService.getCustomerDetail(widget.customerId, token);
        final risk = await _apiService.getRiskScore(widget.customerId, token);
        final behavior = await _apiService.getCustomerBehaviorAnalytics(widget.customerId, token);
        if (mounted) {
          setState(() {
            _customer = data;
            _riskAnalysis = risk;
            _behaviorAnalysis = behavior;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Customer Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
               if (_customer != null) {
                 final result = await Navigator.push(
                   context,
                   MaterialPageRoute(builder: (_) => EditCustomerScreen(customer: _customer!)),
                 );
                 if (result == true) {
                   _fetchDetails();
                 }
               }
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _customer == null 
          ? const Center(child: Text("Error loading profile"))
          : RefreshIndicator(
              onRefresh: _fetchDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                   // Profile Header
                   Container(
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(24),
                       boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
                     ),
                     child: Column(
                       children: [
                         const CircleAvatar(
                           radius: 40,
                           backgroundColor: AppTheme.backgroundColor,
                           child: Icon(Icons.person, size: 40, color: AppTheme.secondaryTextColor),
                         ),
                         const SizedBox(height: 16),
                         Text(
                           _customer!['name'],
                           style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                         ),
                         Text(
                           _customer!['customer_id'] ?? 'No ID',
                           style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                         ),
                         const SizedBox(height: 8),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             _buildStatusBadge(_customer!['status']),
                             const SizedBox(width: 8),
                             if (_customer!['is_locked'] == true)
                               const Chip(
                                 label: Text('🔒 LOCKED', style: TextStyle(fontSize: 10)),
                                 backgroundColor: Colors.red,
                                 labelStyle: TextStyle(color: Colors.white),
                               ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         Text('Version: ${_customer!['version'] ?? 1}', 
                           style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 20),
                   
                   // Admin Status Change
                   if (_isAdmin()) ...[
                     Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text('Admin Controls', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                           const SizedBox(height: 10),
                           Row(
                             children: [
                               Expanded(
                                 child: ElevatedButton.icon(
                                   onPressed: () => _showStatusChangeDialog(),
                                   icon: const Icon(Icons.sync_alt, size: 18),
                                   label: const Text('Change Status'),
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                 ),
                               ),
                               const SizedBox(width: 10),
                               Expanded(
                                 child: ElevatedButton.icon(
                                   onPressed: () => _toggleLock(),
                                   icon: Icon(_customer!['is_locked'] == true ? Icons.lock_open : Icons.lock, size: 18),
                                   label: Text(_customer!['is_locked'] == true ? 'Unlock' : 'Lock'),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: _customer!['is_locked'] == true ? Colors.green : Colors.red
                                   ),
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 12),
                           SizedBox(
                             width: double.infinity,
                             child: OutlinedButton.icon(
                               onPressed: () => _showPassbookQR(),
                               icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                               label: const Text("SHOW PASSBOOK QR"),
                               style: OutlinedButton.styleFrom(
                                 side: const BorderSide(color: AppTheme.primaryColor),
                                 padding: const EdgeInsets.symmetric(vertical: 12),
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 20),
                    ],
                    
                    if (_riskAnalysis != null) ...[
                      _buildRiskCard(),
                      const SizedBox(height: 20),
                    ],

                    if (_behaviorAnalysis != null) ...[
                      _buildBehaviorCard(),
                      const SizedBox(height: 20),
                    ],
                    
                    // Loan Section
                    _buildLoanSection(),
                    const SizedBox(height: 20),

                    // Info Cards
                   _buildInfoCard(Icons.phone, "Mobile", _customer!['mobile']),
                   _buildInfoCard(Icons.map, "Area", _customer!['area'] ?? "N/A"),
                   _buildInfoCard(Icons.home, "Address", _customer!['address'] ?? "N/A"),
                   _buildInfoCard(Icons.badge, "ID Proof", _customer!['id_proof_number'] ?? "N/A"),
                   if (_customer!['latitude'] != null && _customer!['longitude'] != null)
                     _buildInfoCard(Icons.location_on, "GPS Location", 
                       "Lat: ${_customer!['latitude'].toStringAsFixed(4)}, Long: ${_customer!['longitude'].toStringAsFixed(4)}"),

                   const SizedBox(height: 30),
                   
                   SizedBox(
                     width: double.infinity,
                     height: 55,
                     child: ElevatedButton.icon(
                       onPressed: () async {
                          final result = await Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => AddLoanScreen(customerId: widget.customerId, customerName: _customer!['name']))
                          );
                          if (result == true) {
                            _fetchDetails();
                          }
                       },
                       icon: const Icon(Icons.monetization_on_outlined, color: Colors.white),
                       label: Text("Provide Loan", style: GoogleFonts.outfit(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.primaryColor,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       ),
                     ),
                   )
                ],
              ),
            ),
          ),
    );
  }



  Widget _buildRiskCard() {
    final score = _riskAnalysis!['risk_score'] ?? 0;
    final level = _riskAnalysis!['risk_level'] ?? 'N/A';
    final insights = List<String>.from(_riskAnalysis!['insights'] ?? []);
    
    Color riskColor = Colors.green;
    if (level == 'MEDIUM') riskColor = Colors.orange;
    if (level == 'HIGH') riskColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: riskColor),
                  const SizedBox(width: 8),
                  Text("AI RISK ANALYSIS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: riskColor, letterSpacing: 1.2, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: riskColor, borderRadius: BorderRadius.circular(20)),
                child: Text(level, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                "$score",
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: riskColor),
              ),
              const SizedBox(width: 4),
              Text("/100", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey)),
              const Spacer(),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.grey[200],
                  color: riskColor,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: riskColor),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(insight, style: TextStyle(fontSize: 13, color: Colors.blueGrey[800]))),
              ],
            ),
          )),
        ],
      ),
    );
  }



  Widget _buildBehaviorCard() {
    final segment = _behaviorAnalysis!['segment'] ?? 'N/A';
    final reliability = _behaviorAnalysis!['reliability_score'] ?? 0;
    final suggestion = _behaviorAnalysis!['loan_limit_suggestion'] ?? 0;
    final observations = List<String>.from(_behaviorAnalysis!['observations'] ?? []);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue),
              const SizedBox(width: 8),
              Text("ML BEHAVIORAL ANALYSIS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 1.2, fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                child: Text(segment, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Reliability", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text("$reliability%", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Suggested Limit", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text("₹$suggestion", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text("ML Insights:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...observations.map((obs) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text("• $obs", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          )),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    );
  }

  bool _isAdmin() {
     // Allow both admin and workers to see these controls as they are operational field staff
    return true; 
  }

  Widget _buildStatusBadge(String status) {
    final colors = {
      'created': Colors.orange,
      'verified': Colors.blue,
      'active': Colors.green,
      'inactive': Colors.grey,
      'closed': Colors.red,
    };
    
    return Chip(
      label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: colors[status] ?? Colors.grey,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  Future<void> _showStatusChangeDialog() async {
    final statuses = ['created', 'verified', 'active', 'inactive', 'closed'];
    final currentStatus = _customer!['status'];
    
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Customer Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((s) => RadioListTile<String>(
            title: Text(s.toUpperCase()),
            value: s,
            // ignore: deprecated_member_use
            groupValue: currentStatus,
            // ignore: deprecated_member_use
            onChanged: (val) => Navigator.pop(context, val),
          )).toList(),
        ),
      ),
    );
    
    if (selected != null && selected != currentStatus) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        try {
          final response = await _apiService.updateCustomerStatus(widget.customerId, selected, token);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['msg'] ?? 'Status updated'), backgroundColor: Colors.green),
            );
            _fetchDetails();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Future<void> _toggleLock() async {
    final isLocked = _customer!['is_locked'] == true;
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        await _apiService.toggleCustomerLock(widget.customerId, !isLocked, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isLocked ? 'Customer unlocked' : 'Customer locked'), backgroundColor: Colors.green),
          );
          _fetchDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildLoanSection() {
    final loan = _customer!['active_loan'];
    if (loan == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.monetization_on_outlined, color: Colors.blueGrey[200], size: 40),
            const SizedBox(height: 10),
            Text("No Active Loan", style: GoogleFonts.outfit(color: Colors.blueGrey[400], fontWeight: FontWeight.bold)),
            Text("This customer has no active borrowing", style: GoogleFonts.outfit(color: Colors.blueGrey[300], fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan['status'].toString().toUpperCase() == 'ACTIVE' ? "ACTIVE LOAN" : "APPROVED LOAN", 
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                  ),
                  Text(loan['loan_id'] ?? "ID Pending", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Icon(
                loan['status'].toString().toUpperCase() == 'ACTIVE' ? Icons.verified_user : Icons.hourglass_top_rounded, 
                color: Colors.white, 
                size: 28
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _loanStats("Principal", "₹${loan['amount']}"),
              _loanStats("Interest", "${loan['interest_rate']}%"),
              _loanStats("Tenure", "${loan['tenure']} ${loan['tenure_unit']}"),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (loan['status'].toString().toLowerCase() == 'approved')
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent[400],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _activateLoan(loan['id']),
                      child: const Text("ACTIVATE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              if (loan['status'].toString().toLowerCase() == 'active')
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _forecloseLoan(loan['id']),
                      child: const Text("FORECLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _viewSchedule(loan['id']),
                  child: const Text("View EMI", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _viewDocuments(loan['id'], loan['loan_id']),
                  child: const Text("Documents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _loanStats(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  void _viewSchedule(int loanId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EMIScheduleScreen(loanId: loanId)),
    );
  }

  void _viewDocuments(int loanId, String loanNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoanDocumentsScreen(loanId: loanId, loanNumber: loanNumber)),
    );
  }

  Future<void> _activateLoan(int loanId) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        await _apiService.activateLoan(loanId, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loan Activated successfully!'), backgroundColor: Colors.green),
          );
          _fetchDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _forecloseLoan(int loanId) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Foreclose / Settle Loan"),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            const Text("Enter the final settlement amount received from customer."),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl, 
              decoration: const InputDecoration(labelText: "Settlement Amount (₹)", border: OutlineInputBorder()), 
              keyboardType: TextInputType.number
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl, 
              decoration: const InputDecoration(labelText: "Reason", border: OutlineInputBorder())
            ),
          ]
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
            child: const Text("FORECLOSE")
          ),
        ],
      )
    );
    
    if (confirmed == true && amountCtrl.text.isNotEmpty) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
          try {
            final res = await _apiService.forecloseLoan(loanId, double.tryParse(amountCtrl.text) ?? 0.0, reasonCtrl.text, token);
            if (mounted) {
               if (res.containsKey('msg') && res['msg'].toString().contains('successfully')) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan Foreclosed!"), backgroundColor: Colors.green));
                 _fetchDetails();
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res['msg']}"), backgroundColor: Colors.red));
               }
            }
          } catch (e) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
          }
      }
    }
  }

  void _showPassbookQR() {
    if (_customer == null) return;
    _displayQRDialog(_customer!['customer_id'] ?? 'N/A');
  }

  void _displayQRDialog(String customerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Center(child: Text("Customer Passbook", style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Scan this permanent QR to view customer passbook", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: QrImageView(
                  data: customerId,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(_customer!['name'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("ID: $customerId", style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Unified QR for ID Card & Passbook", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE"))
        ],
      ),
    );
  }
}
