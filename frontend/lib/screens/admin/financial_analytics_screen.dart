import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';

class FinancialAnalyticsScreen extends StatefulWidget {
  // Analytical dashboard for administrators
  const FinancialAnalyticsScreen({super.key});

  @override
  State<FinancialAnalyticsScreen> createState() => _FinancialAnalyticsScreenState();
}

class _FinancialAnalyticsScreenState extends State<FinancialAnalyticsScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getFinancialStats(token);
      if (mounted) {
        setState(() {
          _stats = result;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(context.translate('financial_analytics'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Collection by Payment Mode'),
                    _buildModeDistributionChart(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Top Performing Agents'),
                    _buildAgentPerformanceList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Approved', '₹ ${_stats?['total_approved'] ?? 0}', Icons.account_balance_wallet_rounded, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Today\'s Total', '₹ ${_stats?['today_total'] ?? 0}', Icons.today_rounded, Colors.green)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor)),
    );
  }

  Widget _buildModeDistributionChart() {
    final modeData = _stats?['mode_distribution'] as Map<String, dynamic>? ?? {};
    if (modeData.isEmpty) {

      return const Center(child: Text('No data distribution available'));

    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: PieChart(
        PieChartData(
          sections: modeData.entries.map((e) {
            final color = e.key == 'cash' ? Colors.orange : Colors.indigo;
            return PieChartSectionData(
              color: color,
              value: (e.value as num).toDouble(),
              title: '${e.key.toUpperCase()}\n₹${e.value}',
              radius: 60,
              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildAgentPerformanceList() {
    final agents = List<dynamic>.from(_stats?['agent_performance'] ?? []);
    if (agents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text('No agent data available')),
      );
    }

    return Column(
      children: agents.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1), child: const Icon(Icons.person, color: AppTheme.primaryColor)),
              const SizedBox(width: 16),
              Expanded(child: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
              Text('₹ ${a['total']}', style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
