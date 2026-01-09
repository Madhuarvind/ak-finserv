import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'admin_customer_list_screen.dart'; // Import for search navigation
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  // Real Data State
  Map<String, dynamic> _financialStats = {};
  Map<String, dynamic>? _aiInsights;
  List<dynamic> _recentActivity = [];
  bool _isLoading = true;
  String? _userName;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchDashboardData();
  }

  void _loadUser() async {
    final name = await _storage.read(key: 'user_name');
    final role = await _storage.read(key: 'user_role');
    if (mounted) {
      setState(() {
        _userName = name;
        _role = role;
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final token = await _apiService.getToken();
    if (token != null) {
      try {
        final stats = await _apiService.getKPIStats(token);
        final insights = await _apiService.getDashboardAIInsights(token);
        final activity = await _apiService.getAuditLogs(token);
        final name = await _storage.read(key: 'user_name');
        
        if (mounted) {
          setState(() {
            _financialStats = stats;
            _aiInsights = insights;
            _recentActivity = activity;
            _userName = name ?? 'Admin';
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching dashboard data: $e");
        if (mounted) {
          setState(() => _isLoading = false); // Ensure loading is false even on error
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false); // Ensure loading is false if no token
      }
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCustomerListScreen()),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Notifications", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: _recentActivity.isEmpty 
              ? const Text("No new notifications")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _recentActivity.take(5).length,
                  itemBuilder: (context, index) {
                    final log = _recentActivity[index];
                    return ListTile(
                      leading: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryColor),
                      title: Text(log['status'] ?? 'System Event', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(log['time'] ?? '', style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format currency
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          drawer: AppDrawer(
            userName: _userName ?? 'Administrator',
            role: _role ?? 'admin',
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _openSearch,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppTheme.secondaryTextColor.withValues(alpha: 0.5), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Search customers...',
                            style: TextStyle(color: AppTheme.secondaryTextColor.withValues(alpha: 0.5), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: _showNotifications,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Card
                      // Kpi Summary Card
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/admin/collection_ledger'),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryColor, Color(0xFFD4FF8B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Outstanding Balance', style: GoogleFonts.outfit(color: Colors.black54, fontWeight: FontWeight.w600)),
                                      const Icon(Icons.trending_up, color: Colors.black54),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currencyFormatter.format(_financialStats['outstanding_balance'] ?? 0),
                                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStatItem("Collected", currencyFormatter.format(_financialStats['total_collected'] ?? 0)),
                                      _buildStatItem("Overdue", currencyFormatter.format(_financialStats['overdue_amount'] ?? 0), isRed: true),
                                      _buildStatItem("Active Loans", "${_financialStats['active_loans'] ?? 0}"),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (_aiInsights != null) ...[
                        _buildAIInsightsSection(),
                        const SizedBox(height: 32),
                      ],
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.translate('quick_actions'),
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                            ),
                            Icon(Icons.more_horiz_rounded, color: AppTheme.secondaryTextColor.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            _buildModernActionTile(context, context.translate('user_management'), Icons.manage_accounts_outlined, '/admin/user_management'),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, "Reports", Icons.bar_chart_rounded, '/admin/reports'),
                            const SizedBox(width: 16),
                             _buildModernActionTile(context, "AI Risk", Icons.psychology_outlined, '/admin/risk_prediction'),
                             const SizedBox(width: 16),
                             _buildModernActionTile(context, "Worker AI", Icons.analytics_outlined, '/admin/analytics'),
                             const SizedBox(width: 16),
                             _buildModernActionTile(context, context.translate('manage_customers'), Icons.people_outline, '/admin/customers'),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, context.translate('audit_logs'), Icons.assignment_outlined, '/admin/audit_logs'),
                            const SizedBox(width: 16),
                             _buildModernActionTile(context, "Security", Icons.gpp_good_outlined, '/admin/security'),
                             const SizedBox(width: 16),
                             _buildModernActionTile(context, "Loan Approvals", Icons.fact_check_outlined, '/admin/loan_approvals'),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, "Review Collections", Icons.fact_check_rounded, '/admin/review'),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, context.translate('settings'), Icons.settings_outlined, '/settings'),
                          ],
                        ),
                      ),
  
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Activity',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                            ),
                            InkWell(
                              onTap: () => Navigator.pushNamed(context, '/admin/audit_logs'),
                              child: Text(
                                'View All',
                                style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (_recentActivity.isEmpty)
                         const Padding(
                           padding: EdgeInsets.symmetric(horizontal: 24),
                           child: Text("No recent activity found."),
                         ),

                      ..._recentActivity.take(5).map((log) {
                        final isSuccess = log['status'].toString().toLowerCase().contains('success');
                        final icon = isSuccess ? Icons.check_circle_outline : Icons.info_outline;
                        final color = isSuccess ? Colors.green : Colors.orange;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(icon, color: color),
                            ),
                            title: Text(
                              log['status'] ?? 'Event',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              "${log['user_name']} - ${log['device'] ?? 'Unknown Device'}",
                              style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTime(log['time']),
                                  style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }
  
  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return '';
    }
  }



  Widget _buildAIInsightsSection() {
    final summaries = List<String>.from(_aiInsights!['ai_summaries'] ?? []);
    final problemLoans = List<dynamic>.from(_aiInsights!['problem_loans'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[900]!, Colors.indigo[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Text("AI ASSISTANT", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          ...summaries.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
              ],
            ),
          )),
          if (problemLoans.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            Text("PROBLEM LOANS ALERT", style: GoogleFonts.outfit(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...problemLoans.take(2).map((l) => _buildProblemLoanCard(l)),
          ]
        ],
      ),
    );
  }

  Widget _buildProblemLoanCard(Map<String, dynamic> loan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loan['customer'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Text("ID: ${loan['loan_id']}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
            child: Text("${loan['missed']} Missed", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildModernActionTile(BuildContext context, String title, IconData icon, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route).then((_) => _fetchDashboardData()),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black54, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildStatItem(String label, String value, {bool isRed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: isRed ? Colors.red : Colors.black)),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }
}
