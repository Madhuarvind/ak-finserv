import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class AdminLoanManagementScreen extends StatefulWidget {
  const AdminLoanManagementScreen({super.key});

  @override
  State<AdminLoanManagementScreen> createState() => _AdminLoanManagementScreenState();
}

class _AdminLoanManagementScreenState extends State<AdminLoanManagementScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  late TabController _tabController;
  
  List<dynamic> _loans = [];
  bool _isLoading = true;
  String _currentStatusFilter = 'pending_approval'; // custom filter

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        String filter = 'pending_approval';
        if (_tabController.index == 1) filter = 'active';
        if (_tabController.index == 2) filter = 'closed';
        if (_tabController.index == 3) filter = 'all';
        
        setState(() {
          _currentStatusFilter = filter;
          _fetchData();
        });
      }
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      // Map custom UI filter to backend query params
      String? backendStatus;
      if (_currentStatusFilter == 'active') {
        backendStatus = 'active';
      } else if (_currentStatusFilter == 'closed') {
        backendStatus = 'closed';
      } else if (_currentStatusFilter == 'all') {
        backendStatus = null;
      } else if (_currentStatusFilter == 'pending_approval') {
        backendStatus = null; // fetch all and filter manually for created/approved
      }

      final loans = await _apiService.getLoans(
        status: backendStatus, 
        token: token
      );
      
      setState(() {
        if (_currentStatusFilter == 'pending_approval') {
          _loans = loans.where((l) => l['status'] == 'created' || l['status'] == 'approved').toList();
        } else {
          _loans = loans;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Loan Management", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.white24,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "PENDING"),
            Tab(text: "ACTIVE"),
            Tab(text: "CLOSED"),
            Tab(text: "ALL"),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _loans.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _loans.length,
                  itemBuilder: (context, index) => _buildLoanCard(_loans[index]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_rounded, size: 80, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          Text("No loans found".toUpperCase(), style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildLoanCard(dynamic loan) {
    final status = (loan['status'] ?? 'N/A').toString().toUpperCase();
    Color statusColor = Colors.grey;
    if (status == 'CREATED') statusColor = Colors.orange;
    if (status == 'ACTIVE') statusColor = Colors.green;
    if (status == 'CLOSED') statusColor = Colors.blue;
    if (status == 'OVERDUE') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loan['loan_id'] ?? "ID UNKNOWN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(status, style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (loan['recovery_level'] != null)
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 12, color: _getRecoveryColor(loan['recovery_level'])),
                      const SizedBox(width: 4),
                      Text(
                        "RECOVERY: ${loan['recovery_level']}", 
                        style: GoogleFonts.outfit(
                          color: _getRecoveryColor(loan['recovery_level']), 
                          fontSize: 9, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 1
                        )
                      ),
                      const Spacer(),
                      if (loan['recovery_score'] != null)
                        Text(
                          "${(loan['recovery_score'] * 100).toInt()}% CONFIDENCE",
                          style: GoogleFonts.outfit(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold)
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(loan['customer_name'] ?? "Unknown Customer", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _miniInfo(Icons.payments_rounded, "Principal", "₹${loan['principal_amount']}"),
                    const Spacer(),
                    _miniInfo(Icons.calendar_month_rounded, "Tenure", "${loan['tenure']} ${loan['tenure_unit']}"),
                  ],
                ),
              ],
            ),
          ),
          if (loan['status'] == 'created' || loan['status'] == 'active')
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  if (loan['status'] == 'created')
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _approveLoan(loan),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text("APPROVE"),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                      ),
                    ),
                  if (loan['status'] == 'active')
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _showRestructureDialog(loan),
                        icon: const Icon(Icons.history_edu, size: 18),
                        label: const Text("RESTRUCTURE"),
                        style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                      ),
                    ),
                  if (loan['status'] == 'active')
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _forecloseLoan(loan),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text("FORECLOSE"),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                    ),
                  const VerticalDivider(color: Colors.white10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        if (loan['customer_id'] != null) {
                          Navigator.pushNamed(
                            context, 
                            '/admin/customer_detail', 
                            arguments: loan['customer_id']
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Customer ID not found. Available keys: ${loan.keys.join(', ')}"))
                          );
                        }
                      },
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      label: const Text("DETAILS"),
                      style: TextButton.styleFrom(foregroundColor: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.w900)),
            Text(value, style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  void _approveLoan(dynamic loan) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        await _apiService.approveLoan(loan['id'], {'start_date': picked.toIso8601String()}, token);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan Approved Successfully"), backgroundColor: Colors.green));
        _fetchData();
      }
    }
  }

  Color _getRecoveryColor(String level) {
    if (level == 'HIGH') return Colors.greenAccent;
    if (level == 'MEDIUM') return Colors.orangeAccent;
    return Colors.redAccent;
  }

  void _showRestructureDialog(dynamic loan) async {
    final TextEditingController tenureController = TextEditingController(text: loan['tenure'].toString());
    final TextEditingController interestController = TextEditingController(text: loan['interest_rate'].toString());
    final TextEditingController remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Restructure Loan", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Restructuring will close the current loan and create a new one with the remaining balance of ₹${loan['principal_amount']}.",
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tenureController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "New Tenure", labelStyle: TextStyle(color: Colors.white38)),
            ),
            TextField(
              controller: interestController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "New Interest Rate (%)", labelStyle: TextStyle(color: Colors.white38)),
            ),
            TextField(
              controller: remarksController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Remarks", labelStyle: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final token = await _storage.read(key: 'jwt_token');
              if (token != null) {
                final result = await _apiService.restructureLoan(loan['id'], {
                  'tenure': int.tryParse(tenureController.text),
                  'interest_rate': double.tryParse(interestController.text),
                  'remarks': remarksController.text
                }, token);
                
                if (!mounted) return;
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(result['msg'] ?? "Restructured"), backgroundColor: Colors.green)
                );
                _fetchData();
              }
            },
            child: const Text("RESTRUCTURE"),
          )
        ],
      ),
    );
  }

  void _forecloseLoan(dynamic loan) async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Foreclose Loan", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Settlement Amount",
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Reason",
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final amount = double.tryParse(amountController.text);
              if (amount != null) {
                final token = await _storage.read(key: 'jwt_token');
                if (token != null) {
                  await _apiService.forecloseLoan(loan['id'], amount, reasonController.text, token);
                  if (!mounted) return;
                  navigator.pop();
                  _fetchData();
                }
              }
            },
            child: const Text("FORECLOSE"),
          ),
        ],
      ),
    );
  }
}
