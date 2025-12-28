import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final ApiService _apiService = ApiService();
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final name = await _apiService.getUserName();
    if (mounted && name != null) {
      setState(() {
        _userName = name;
      });
    }
  }

  void _handleLogout() async {
    await _apiService.clearAuth();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              context.translate('app_title'),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
                letterSpacing: 1.2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                onPressed: _handleLogout,
                tooltip: context.translate('logout'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(context),
                const SizedBox(height: 32),
                _buildStatsGrid(context),
                const SizedBox(height: 32),
                Text(
                  context.translate('quick_actions'),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: 32),
                _buildRecentActivity(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.translate('welcome')},',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          (_userName != null && _userName!.isNotEmpty) ? _userName! : context.translate('field_agent'),
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context.translate('goal'),
            '₹ 25,000',
            Icons.track_changes_rounded,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context.translate('collected'),
            '₹ 12,450',
            Icons.account_balance_wallet_rounded,
            Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E1E1E), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildActionItem(context.translate('qr_scan'), Icons.qr_code_scanner_rounded, Colors.orange),
        _buildActionItem(context.translate('collection'), Icons.add_circle_outline_rounded, Colors.greenAccent),
        _buildActionItem(context.translate('expense'), Icons.receipt_long_rounded, Colors.redAccent),
        _buildActionItem(context.translate('reports'), Icons.bar_chart_rounded, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildActionItem(String label, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E1E1E), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.translate('recent_activity'),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
          const SizedBox(height: 24),
          _buildActivityTile('Collected from John Doe', '10 mins ago', '₹ 1,200', Colors.greenAccent),
          const Divider(color: Color(0xFF1E1E1E), height: 32),
          _buildActivityTile('Collection Failed: Madhu', '1 hour ago', '₹ 800', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildActivityTile(String title, String time, String amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
