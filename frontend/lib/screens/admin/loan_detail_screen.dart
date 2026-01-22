import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class LoanDetailScreen extends StatefulWidget {
  final int loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  dynamic _loan;
  bool _isLoading = true;
  bool _isAutomating = false;

  @override
  void initState() {
    super.initState();
    _fetchLoanDetails();
  }

  Future<void> _fetchLoanDetails() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final data = await _apiService.getLoanDetails(widget.loanId, token);
        if (mounted) {
          setState(() {
            _loan = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // Temporary Fix: Since I forgot getLoanById in ApiService, I'll add logic to fetch it specifically if needed
  // But for this pass, let's build the UI assuming _loan is populated properties.
  // Warning: The EMI schedule won't show if getAllLoans doesn't return it.
  // Backend `get_all_loans` does NOT return emi_schedule. `get_loan` DOES.
  // I will add a TODO to fix this. For now let's build the UI foundation.

  Future<void> _approveLoan() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      setState(() => _isLoading = true);
      final result = await _apiService.approveLoan(widget.loanId, token, startDate: picked.toIso8601String());
      
      if (result.containsKey('msg') && result['msg'].toString().contains('approved')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan Approved & Schedule Generated!")));
        _fetchLoanDetails(); // Refresh
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${result['error']}")));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runAutomation() async {
    setState(() => _isAutomating = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.runOverdueCheck(token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Automation finished: ${result['updated_count']} EMIs marked overdue."))
          );
          _fetchLoanDetails(); // Refresh UI
        }
      }
    } catch (e) {
      debugPrint("Automation Error: $e");
    } finally {
      if (mounted) setState(() => _isAutomating = false);
    }
  }

  Future<void> _forecloseLoan() async {
    final TextEditingController amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Foreclose Loan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter settlement amount:"),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final token = await _storage.read(key: 'jwt_token');
              if (token == null) return;
              
              setState(() => _isLoading = true);
              final result = await _apiService.forecloseLoan(
                widget.loanId, 
                double.tryParse(amountCtrl.text) ?? 0, 
                "Manual Foreclosure", 
                token
              );
              
              if (result.containsKey('msg') && result['msg'].toString().contains('foreclosed')) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loan Foreclosed!")));
                Navigator.pop(context, true);
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${result['error']}")));
              }
               setState(() => _isLoading = false);
            }, 
            child: const Text("Confirm")
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    if (_loan == null) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: Text("Loan not found", style: TextStyle(color: Colors.white))));

    double principal = double.tryParse(_loan['principal_amount'].toString()) ?? 0;
    double pending = double.tryParse(_loan['pending_amount'].toString()) ?? 0;
    double paid = principal > pending ? principal - pending : 0.0;
    double progress = principal > 0 ? paid / principal : 0.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(_loan['loan_id'] ?? 'Loan Detail', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_isAutomating)
               const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)))
            else
               IconButton(
                 icon: const Icon(Icons.auto_fix_high_rounded, color: AppTheme.primaryColor),
                 onPressed: _runAutomation,
                 tooltip: "Run Overdue Check",
               ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(progress, paid, pending),
                        const SizedBox(height: 24),
                        _buildInfoSection("CUSTOMER", [
                           _infoRow(Icons.person, "Name", _loan['customer_name'] ?? 'N/A'),
                           _infoRow(Icons.phone, "Mobile", _loan['customer_mobile'] ?? 'N/A'),
                        ]),
                        _buildInfoSection("GUARANTOR", [
                           _infoRow(Icons.verified_user, "Name", _loan['guarantor_name'] ?? 'No Guarantor'),
                           _infoRow(Icons.phone, "Mobile", _loan['guarantor_mobile'] ?? 'N/A'),
                           _infoRow(Icons.link, "Relation", _loan['guarantor_relation'] ?? 'N/A'),
                        ]),
                        const SizedBox(height: 12),
                        const TabBar(
                          labelColor: AppTheme.primaryColor,
                          unselectedLabelColor: Colors.white60,
                          indicatorColor: AppTheme.primaryColor,
                          indicatorSize: TabBarIndicatorSize.label,
                          tabs: [
                            Tab(text: "SCHEDULE"),
                            Tab(text: "HISTORY"),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 400, // Fixed height for tab content
                          child: TabBarView(
                            children: [
                               _loan['emi_schedule'] != null && (_loan['emi_schedule'] as List).isNotEmpty
                                 ? _buildScheduleTable()
                                 : _emptyState("No schedule available"),
                               _loan['collections'] != null && (_loan['collections'] as List).isNotEmpty
                                 ? _buildCollectionsList()
                                 : _emptyState("No collections yet"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildActionButtons(),
      ),
    );
  }

  Widget _emptyState(String msg) => Center(child: Text(msg, style: GoogleFonts.outfit(color: Colors.white24)));

  Widget _buildStatusCard(double progress, double paid, double pending) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("LOAN RECOVERY", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text("${(progress * 100).toInt()}%", style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: AppTheme.primaryColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _statBit("Principal", "₹${_loan['principal_amount']}", Colors.white)),
              Expanded(child: _statBit("Paid", "₹${paid.toInt()}", Colors.greenAccent)),
              Expanded(child: _statBit("Pending", "₹${_loan['pending_amount']}", Colors.orangeAccent)),
            ],
          ),
          const SizedBox(height: 16),
          _detailLine("Status", "${_loan['status']}".toUpperCase(), _getStatusColor(_loan['status'])),
        ],
      ),
    );
  }

  Widget _statBit(String label, String val, Color col) => Column(
    children: [
      Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 6),
      Text(val, style: GoogleFonts.outfit(color: col, fontSize: 16, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _detailLine(String label, String value, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 10),
        Text("$label: ", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
        Expanded(child: Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
      ],
    ),
  );

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(color: AppTheme.primaryColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCollectionsList() {
    List<dynamic> collections = _loan['collections'] ?? [];
    return ListView.builder(
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final c = collections[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("₹${c['amount']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  Text("${c['payment_mode']}".toUpperCase(), style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(c['time'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(c['time'])) : 'N/A', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
                  Text("by ${c['agent_name']}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
        Text(value, style: GoogleFonts.outfit(
          fontSize: 18, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: valueColor ?? Colors.white
        )),
      ]
    );
  }

  Color _getStatusColor(dynamic status) {
    switch (status.toString().toLowerCase()) {
      case 'active': return Colors.greenAccent;
      case 'created': return Colors.orangeAccent;
      case 'closed': return Colors.blueAccent;
      default: return Colors.white;
    }
  }

  Widget _buildScheduleTable() {
    List<dynamic> schedule = _loan['emi_schedule'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2.5),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
              children: [
                _tableHeader("No."),
                _tableHeader("Date"),
                _tableHeader("Amount"),
                _tableHeader("Status"),
              ]
            ),
            ...schedule.map((emi) => TableRow(
              children: [
                _tableCell("${emi['emi_no']}"),
                _tableCell("${emi['due_date']}"),
                _tableCell("₹${emi['amount']}"),
                _tableCell("${emi['status']}", 
                  color: emi['status'] == 'paid' ? Colors.greenAccent : Colors.redAccent),
              ]
            )),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
  );

  Widget _tableCell(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Text(text, style: GoogleFonts.outfit(color: color ?? Colors.white, fontSize: 13)),
  );

  Widget? _buildActionButtons() {
    if (_loan['status'] == 'created') {
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _approveLoan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.withOpacity(0.2),
            foregroundColor: Colors.greenAccent,
            side: const BorderSide(color: Colors.greenAccent),
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("APPROVE LOAN & GENERATE SCHEDULE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      );
    }
    if (_loan['status'] == 'active' || _loan['status'] == 'approved') {
       return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _forecloseLoan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withOpacity(0.1),
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("FORECLOSE LOAN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      );
    }
    return null;
  }
}
