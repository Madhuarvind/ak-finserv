import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EMIScheduleScreen extends StatefulWidget {
  final int loanId;
  const EMIScheduleScreen({super.key, required this.loanId});

  @override
  State<EMIScheduleScreen> createState() => _EMIScheduleScreenState();
}

class _EMIScheduleScreenState extends State<EMIScheduleScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  List<dynamic> _schedule = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final loanData = await _apiService.getLoanDetails(widget.loanId, token);
        if (mounted) {
          setState(() {
            _schedule = loanData['emi_schedule'] ?? [];
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('EMI Schedule', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _schedule.isEmpty
                ? const Center(child: Text("No schedule available", style: TextStyle(color: Colors.white54)))
                : Column(
                    children: [
                      const SizedBox(height: 100),
                      _buildSummaryCard(),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _schedule.length,
                          itemBuilder: (context, index) {
                      final item = _schedule[index];
                      final bool isPaid = item['status'] == 'paid';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPaid ? Colors.greenAccent.withAlpha(50) : Colors.orangeAccent.withAlpha(50),
                                child: Text("${item['emi_no']}", style: TextStyle(color: isPaid ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                              ),
                              title: Text("₹${item['amount']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                              subtitle: Text("Due: ${item['due_date']}", style: const TextStyle(color: Colors.white54)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPaid ? Colors.green : Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item['status'].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              onLongPress: isPaid ? null : () => _showPenaltyDialog(item),
                            ),
                            if (item['penalty_amount'] != null && item['penalty_amount'] > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 72, bottom: 12, right: 16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Penalty Added: ₹${item['penalty_amount']}", 
                                      style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showPenaltyDialog(dynamic emi) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Add Penalty to EMI #${emi['emi_no']}", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Penalty Amount", labelStyle: TextStyle(color: Colors.white38)),
            ),
            TextField(
              controller: notesController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Reason/Notes", labelStyle: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final amount = double.tryParse(amountController.text);
              if (amount != null) {
                final token = await _storage.read(key: 'jwt_token');
                if (token != null) {
                  final result = await _apiService.addPenalty(emi['id'], amount, notesController.text, token);
                  if (!mounted) return;
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(result['msg'] ?? "Penalty added"), backgroundColor: Colors.green)
                  );
                  _fetchSchedule();
                }
              }
            },
            child: const Text("ADD PENALTY"),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    double totalPrincipal = 0;
    double totalInterest = 0;
    double totalPenalty = 0;
    double totalPaid = 0;

    for (var item in _schedule) {
      totalPrincipal += (item['principal_part'] ?? 0);
      totalInterest += (item['interest_part'] ?? 0);
      totalPenalty += (item['penalty_amount'] ?? 0);
      if (item['status'] == 'paid') {
        totalPaid += (item['amount'] ?? 0) + (item['penalty_amount'] ?? 0);
      }
    }

    final totalDue = totalPrincipal + totalInterest + totalPenalty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withAlpha(25), Colors.white.withAlpha(12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ACCOUNT STATEMENT", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.primaryColor, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem("Total Principal", "₹${totalPrincipal.toStringAsFixed(0)}"),
              _summaryItem("Total Interest", "₹${totalInterest.toStringAsFixed(0)}"),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem("Total Penalty", "₹${totalPenalty.toStringAsFixed(0)}", color: Colors.redAccent),
              _summaryItem("Total Due", "₹${totalDue.toStringAsFixed(0)}", isHighlight: true),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalDue > 0 ? (totalPaid / totalDue) : 0,
              backgroundColor: Colors.white10,
              color: AppTheme.primaryColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Repayment Progress", style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("${(totalDue > 0 ? (totalPaid / totalDue * 100) : 0).toInt()}% Paid", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, {Color? color, bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        Text(value, style: GoogleFonts.outfit(color: color ?? (isHighlight ? AppTheme.primaryColor : Colors.white), fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
