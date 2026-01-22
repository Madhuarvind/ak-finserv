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
import 'cash_settlement_screen.dart';
import '../common/qr_scan_screen.dart';

class AdminDashboard extends StatefulWidget {
  final int initialTab;
  const AdminDashboard({super.key, this.initialTab = 0});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Real Data State
  Map<String, dynamic> _financialStats = {};
  Map<String, dynamic> _dailyOpsSummary = {};
  Map<String, dynamic>? _aiInsights;
  Map<String, dynamic>? _autoAccountingData;
  Map<String, dynamic>? _validationErrorData;
  List<dynamic> _recentActivity = [];
  bool _isLoading = true;
  String? _userName;
  String? _role;

  int _currentIndex = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _pulseController = AnimationController(
       duration: const Duration(seconds: 2),
       vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _tabController = TabController(length: 2, vsync: this);
    _loadUser();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tabController.dispose();
    super.dispose();
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
        final summary = await _apiService.getDailyOpsSummary(token);
        final insights = await _apiService.getAIInsights(token);
        final autoAccounting = await _apiService.getAutoAccountingData();
        final validationErrors = await _apiService.getValidationErrorLogs();
        final activity = await _apiService.getAuditLogs(token);
        final name = await _storage.read(key: 'user_name');
        
        if (mounted) {
          setState(() {
            _financialStats = stats;
            _dailyOpsSummary = summary;
            _aiInsights = insights;
            _autoAccountingData = autoAccounting;
            _validationErrorData = validationErrors;
            _recentActivity = activity.take(5).toList();
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          key: _scaffoldKey,
          extendBodyBehindAppBar: true,
          drawer: AppDrawer(
            userName: _userName ?? 'Administrator',
            role: _role ?? 'admin',
          ),
          appBar: _buildAppBar(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF0F172A),
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: Colors.white54,
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: context.translate('dashboard')),
              BottomNavigationBarItem(icon: const Icon(Icons.currency_rupee_rounded), label: context.translate('tally')),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: SafeArea( // Added SafeArea to avoid overlap with transparent AppBar and status bar
              bottom: false, // Let content go behind bottom nav if needed, or stick to safe area
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                     _buildDashboardBody(context, languageProvider),
                     const CashSettlementScreen(isTab: true),
                  ],
                ),
            ),
          ),
          floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
            onPressed: () => _showAIAnalyst(context),
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text("Ask AI", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ) : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_currentIndex == 1) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(context.translate('daily_tally'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      );
    }
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: InkWell(
        onTap: _openSearch,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                context.translate('search_customers_hint'),
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: _showNotifications,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDashboardBody(BuildContext context, LanguageProvider languageProvider) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return _isLoading 
      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
      : RefreshIndicator(
          onRefresh: _fetchDashboardData,
          color: AppTheme.primaryColor,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/admin/collection_ledger'),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF334155)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.translate('outstanding_balance'),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, color: AppTheme.primaryColor, size: 24),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              currencyFormatter.format(_financialStats['outstanding_balance'] ?? 0),
                              style: GoogleFonts.outfit(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem(context.translate('collected'), currencyFormatter.format(_financialStats['total_collected'] ?? 0), isDark: true),
                                _buildStatItem(context.translate('overdue'), currencyFormatter.format(_financialStats['overdue_amount'] ?? 0), isRed: true, isDark: true),
                                _buildStatItem(context.translate('active_loans'), "${_financialStats['active_loans'] ?? 0}", isDark: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildAutoAccountingSection(),
                const SizedBox(height: 12),
                _buildErrorDetectionSection(),
                const SizedBox(height: 24),
                _buildDailyPulseSection(),
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
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Icon(Icons.more_horiz_rounded, color: Colors.white54),
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
                      _buildModernActionTile(context, context.translate('qr_scan'), Icons.qr_code_scanner_rounded, '/admin/qr_scan'),
                      const SizedBox(width: 16),
                      _buildModernActionTile(context, "Loan Management", Icons.monetization_on_rounded, '/admin/loan_management'),
                      const SizedBox(width: 16),
                      _buildModernActionTile(context, "Review Collections", Icons.fact_check_rounded, '/admin/review'),
                      const SizedBox(width: 16),
                      _buildModernActionTile(context, "Live Tracking", Icons.map_rounded, '/admin/tracking'),
                      const SizedBox(width: 16),
                      _buildModernActionTile(context, "Operations", Icons.bolt_rounded, '/admin/optimization'),
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
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/admin/audit_logs'),
                        child: Text(
                          'View All',
                          style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (_recentActivity.isEmpty)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: Text("No recent activity found.", style: GoogleFonts.outfit(color: Colors.white54)),
                   ),

                ..._recentActivity.take(5).map((log) {
                  final isSuccess = log['status'].toString().toLowerCase().contains('success');
                  final icon = isSuccess ? Icons.check_circle_outline : Icons.info_outline;
                  final color = isSuccess ? Colors.greenAccent : Colors.orangeAccent;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      subtitle: Text(
                        "${log['user_name']} - ${log['device'] ?? 'Unknown Device'}",
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(log['time']),
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
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

  Widget _buildDailyPulseSection() {
    final progress = ((_dailyOpsSummary['progress_percentage'] ?? 0.0) as num).toDouble() / 100.0;
    final collected = (_dailyOpsSummary['collected_today'] ?? 0.0) as num;
    final total = (_dailyOpsSummary['target_today'] ?? 0.0) as num;
    final agents = _dailyOpsSummary['active_agents'] ?? 0;
    final leaders = _dailyOpsSummary['leaders'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  context.translate('daily_recovery_pulse'),
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text("$agents ${context.translate('agents_live')}", style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    height: 14,
                    width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFFD4FF8B)]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "₹${NumberFormat('#,##,###').format(collected)} of ₹${NumberFormat('#,##,###').format(total)}",
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(context.translate('collected_today_pulse'), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1)),
                ],
              ),
              Text("${(progress * 100).toStringAsFixed(1)}%", style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontSize: 28, fontWeight: FontWeight.w900)),
            ],
          ),
          if (leaders.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(context.translate('top_performers'), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: leaders.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final leader = leaders[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Center(
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "${leader['name']} • ₹${NumberFormat('#,###').format(leader['amount'])}",
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildAIInsightsSection() {
    final summaries = List<String>.from(_aiInsights?['ai_summaries'] ?? []);
    final problemLoans = List<dynamic>.from(_aiInsights?['problem_loans'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Text(context.translate('ai_assistant_title'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
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
                Expanded(child: Text(s, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, height: 1.4))),
              ],
            ),
          )),
          if (problemLoans.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            Text(context.translate('problem_loans_alert'), style: GoogleFonts.outfit(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...problemLoans.take(2).map((l) => _buildProblemLoanCard(l)),
          ]
        ],
      ),
    );
  }

  Widget _buildProblemLoanCard(Map<String, dynamic> loan) {
    final riskScore = (loan['risk_score'] ?? 0) as num;
    final riskColor = riskScore > 80 ? Colors.redAccent : (riskScore > 50 ? Colors.orangeAccent : Colors.amberAccent);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: riskColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan['customer_name'] ?? 'Unknown', 
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                ),
                const SizedBox(height: 2),
                Text(
                  loan['reason'] ?? 'Anomaly detected', 
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11)
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "RISK", 
                style: GoogleFonts.outfit(color: riskColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)
              ),
              Text(
                "$riskScore%", 
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionTile(BuildContext context, String title, IconData icon, String route, {bool isCustom = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: isCustom ? onTap : () => Navigator.pushNamed(context, route).then((_) => _fetchDashboardData()),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white70, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  void _showAIAnalyst(BuildContext context) {
    final textController = TextEditingController();
    List<Map<String, dynamic>> messages = [
      {'text': 'Hello! I am your AI Financial Analyst. Ask me anything about collections or performance.', 'isAi': true}
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Text("AI Analyst", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isAi = msg['isAi'];
                      return Align(
                        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isAi ? Colors.white.withValues(alpha: 0.1) : AppTheme.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isAi ? Colors.white.withValues(alpha: 0.05) : AppTheme.primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            msg['text'],
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -5))]
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          style: GoogleFonts.outfit(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Type your question...",
                            hintStyle: GoogleFonts.outfit(color: Colors.white38),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onSubmitted: (v) async {
                            final query = textController.text.trim();
                            if (query.isEmpty) return;
                            
                            setModalState(() {
                              messages.add({'text': query, 'isAi': false});
                            });
                            textController.clear();

                            final token = await _apiService.getToken();
                            if (token != null) {
                              final response = await _apiService.askAiAnalyst(query, token);
                              if (context.mounted) {
                                setModalState(() {
                                  messages.add({'text': response['text'], 'isAi': true});
                                });
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () async {
                          final query = textController.text.trim();
                          if (query.isEmpty) return;
                          
                          setModalState(() {
                            messages.add({'text': query, 'isAi': false});
                          });
                          textController.clear();

                          final token = await _apiService.getToken();
                          if (token != null) {
                            final response = await _apiService.askAiAnalyst(query, token);
                            if (context.mounted) {
                              setModalState(() {
                                messages.add({'text': response['text'], 'isAi': true});
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorDetectionSection() {
    if (_validationErrorData == null) return const SizedBox.shrink();
    
    final data = _validationErrorData!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark blue-grey
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.security_rounded, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 8),
                  Text("Error-Detection Agent", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("ACTIVE", style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildAccountingMiniCard(
                  title: "Total Alerts",
                  value: "${data['total_alerts'] ?? 0}",
                  icon: Icons.notifications_active_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountingMiniCard(
                  title: "Risk Coverage",
                  value: data['risk_coverage'] ?? '0%',
                  icon: Icons.shield_rounded,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAccountingMiniCard(
                  title: "Double Entries",
                  value: "${data['double_entries'] ?? 0}",
                  icon: Icons.repeat_rounded,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountingMiniCard(
                  title: "Abnormal Amounts",
                  value: "${data['abnormal_amounts'] ?? 0}",
                  icon: Icons.error_outline_rounded,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/admin/audit_logs'), // Or dedicated alert log
              icon: const Icon(Icons.list_alt_rounded, size: 18, color: Colors.orangeAccent),
              label: Text("VIEW ALERT LOGS", 
                style: GoogleFonts.outfit(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoAccountingSection() {
    if (_autoAccountingData == null) return const SizedBox.shrink();
    
    final data = _autoAccountingData!;
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate-900 / Deep Dark
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: Color(0xFFD4FF8B), size: 20),
                  const SizedBox(width: 8),
                  Text(context.translate('auto_accounting'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text(data['date'] ?? '', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildAccountingMiniCard(
                  title: context.translate('morning'),
                  value: currencyFormatter.format(data['morning'] ?? 0),
                  icon: Icons.wb_sunny_rounded,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountingMiniCard(
                  title: context.translate('evening'),
                  value: currencyFormatter.format(data['evening'] ?? 0),
                  icon: Icons.nightlight_round,
                  color: Colors.indigoAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAccountingMiniCard(
                  title: context.translate('cash'),
                  value: currencyFormatter.format(data['cash'] ?? 0),
                  icon: Icons.payments_rounded,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountingMiniCard(
                  title: context.translate('upi'),
                  value: currencyFormatter.format(data['upi'] ?? 0),
                  icon: Icons.qr_code_scanner_rounded,
                  color: Colors.lightBlueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAccountingMiniCard(
                  title: context.translate('principal'),
                  value: currencyFormatter.format(data['loan_principal'] ?? 0),
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFFD4FF8B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountingMiniCard(
                  title: context.translate('interest'),
                  value: currencyFormatter.format(data['loan_interest'] ?? 0),
                  icon: Icons.show_chart_rounded,
                  color: Colors.pinkAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/admin/daily_reports'),
              icon: const Icon(Icons.history_rounded, size: 18, color: Color(0xFFD4FF8B)),
              label: Text(context.translate('view_history_archives'), 
                style: GoogleFonts.outfit(color: const Color(0xFFD4FF8B), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountingMiniCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }


  Widget _buildStatItem(String label, String value, {bool isRed = false, bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value, 
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, 
            fontSize: 20, 
            color: isRed ? Colors.redAccent : (isDark ? Colors.white : Colors.black)
          )
        ),
        Text(
          label, 
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54, 
            fontSize: 12,
            fontWeight: isDark ? FontWeight.w500 : FontWeight.normal
          )
        ),
      ],
    );
  }
}
