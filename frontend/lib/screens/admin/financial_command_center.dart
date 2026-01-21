import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class FinancialCommandCenter extends StatefulWidget {
  const FinancialCommandCenter({super.key});

  @override
  State<FinancialCommandCenter> createState() => _FinancialCommandCenterState();
}

class _FinancialCommandCenterState extends State<FinancialCommandCenter> {
  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  Map<String, dynamic> _summary = {};
  List<dynamic> _expenses = [];
  bool _isLoading = true;
  String _period = 'today';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final summary = await _apiService.getFinancialSummary(token, period: _period);
      final expenses = await _apiService.getExpenses(token);
      setState(() {
        _summary = summary;
        _expenses = expenses;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Financial Center", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          DropdownButton<String>(
            value: _period,
            dropdownColor: const Color(0xFF1E293B),
            underline: const SizedBox(),
            items: ['today', 'week', 'month', 'all'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _period = val);
                _fetchData();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_business_rounded, color: Colors.black),
        label: Text("ADD EXPENSE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainCards(),
                    const SizedBox(height: 32),
                    if ((_summary['expense_breakdown'] as Map?)?.isNotEmpty ?? false) ...[
                      Text("EXPENSE BREAKDOWN", style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 20),
                      _buildChart(),
                      const SizedBox(height: 32),
                    ],
                    Text("RECENT EXPENSES", style: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    _buildExpenseList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMainCards() {
    return Column(
      children: [
        _statCard("TOTAL REVENUE", "₹${_summary['revenue'] ?? 0}", Colors.greenAccent, Icons.trending_up),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard("EXPENSES", "₹${_summary['expenses'] ?? 0}", Colors.redAccent, Icons.trending_down, compact: true)),
            const SizedBox(width: 16),
            Expanded(child: _statCard("NET PROFIT", "₹${_summary['net_profit'] ?? 0}", AppTheme.primaryColor, Icons.account_balance_wallet_rounded, compact: true)),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: compact ? 20 : 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: compact ? 18 : 26, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final Map<String, dynamic> breakdown = _summary['expense_breakdown'] ?? {};
    final sections = breakdown.entries.map((e) {
      return PieChartSectionData(
        value: (e.value as num).toDouble(),
        title: '',
        radius: 40,
        color: _getCategoryColor(e.key),
      );
    }).toList();

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40))),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: breakdown.entries.map((e) => _legendItem(e.key, "₹${e.value}")).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String cat, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _getCategoryColor(cat), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(cat.toUpperCase().replaceAll('_', ' '), style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(val, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_expenses.isEmpty) return const Text("No expenses recorded yet.", style: TextStyle(color: Colors.white24));
    return Column(
      children: _expenses.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _getCategoryColor(e['category']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Icon(Icons.receipt_long_rounded, size: 18, color: _getCategoryColor(e['category']))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['category'].toUpperCase().replaceAll('_', ' '), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(e['description'] ?? 'No description', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("-₹${e['amount']}", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14)),
                Text(e['date'], style: GoogleFonts.outfit(color: Colors.white10, fontSize: 10)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'petrol_oil_lubricants': return Colors.orangeAccent;
      case 'salary': return Colors.blueAccent;
      case 'rent': return Colors.purpleAccent;
      case 'commission': return Colors.yellowAccent;
      case 'office_expense': return Colors.cyanAccent;
      default: return Colors.white24;
    }
  }

  void _showAddExpenseDialog() {
    final categories = ['petrol_oil_lubricants', 'salary', 'rent', 'commission', 'office_expense', 'miscellaneous'];
    String selectedCat = categories[0];
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Log Business Expense", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: selectedCat,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Category", labelStyle: TextStyle(color: Colors.white60)),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase().replaceAll('_', ' ')))).toList(),
              onChanged: (v) => selectedCat = v!,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Amount (₹)", labelStyle: TextStyle(color: Colors.white60)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.white60)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final amt = double.tryParse(amountController.text);
                  if (amt != null) {
                    final token = await _storage.read(key: 'jwt_token');
                    if (token != null) {
                      await _apiService.addExpense({
                        'category': selectedCat,
                        'amount': amt,
                        'description': descController.text,
                      }, token);
                      navigator.pop();
                      _fetchData();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("CONFIRM RECORD", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
