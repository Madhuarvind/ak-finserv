import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'line_report_screen.dart';

class AgentLinesScreen extends StatefulWidget {
  const AgentLinesScreen({super.key});

  @override
  State<AgentLinesScreen> createState() => _AgentLinesScreenState();
}

class _AgentLinesScreenState extends State<AgentLinesScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  List<dynamic> _lines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLines();
  }

  Future<void> _fetchLines() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final lines = await _apiService.getAllLines(token);
        setState(() {
          _lines = lines;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('my_lines'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context).translate('no_lines_found')),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: const Icon(Icons.route, color: Colors.blue),
                        title: Text(line['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${line['area']} • ${line['customer_count']} Customers'),
                        trailing: line['is_locked'] ? const Icon(Icons.lock, color: Colors.red) : const Icon(Icons.chevron_right),
                        onTap: line['is_locked'] 
                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Line is locked')))
                          : () => _viewLineCustomers(line),
                      ),
                    );
                  },
                ),
    );
  }

  void _viewLineCustomers(dynamic line) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _LineCustomersSheet(line: line, apiService: _apiService, storage: _storage),
    );
  }
}

class _LineCustomersSheet extends StatefulWidget {
  final dynamic line;
  final ApiService apiService;
  final FlutterSecureStorage storage;

  const _LineCustomersSheet({required this.line, required this.apiService, required this.storage});

  @override
  State<_LineCustomersSheet> createState() => _LineCustomersSheetState();
}

class _LineCustomersSheetState extends State<_LineCustomersSheet> {
  List<dynamic> _pendingCustomers = [];
  List<dynamic> _collectedCustomers = [];
  bool _isLoading = true;
  double _totalCollected = 0;
  double _totalCash = 0;
  double _totalUpi = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await widget.storage.read(key: 'jwt_token');
      if (token != null) {
        // 1. Fetch all customers in this line
        final custs = await widget.apiService.getLineCustomers(widget.line['id'], token);
        
        // 2. Fetch today's collections to see who already paid
        final history = await widget.apiService.getCollectionHistory(token);
        
        final today = DateTime.now();
        double collected = 0;
        double cash = 0;
        double upi = 0;

        final dailyCollections = history.where((c) {
          final dateStr = c['time'] ?? c['created_at'];
          if (dateStr == null) return false;
          try {
            final date = DateTime.parse(dateStr).toLocal();
            return date.year == today.year && date.month == today.month && date.day == today.day && c['status'] != 'rejected';
          } catch(e) { return false; }
        }).toList();

        final collectedIdMap = {for (var c in dailyCollections) (c['customer_id'] ?? c['customer']): c};

        for (var c in dailyCollections) {
          final amt = (c['amount'] ?? 0).toDouble();
          collected += amt;
          if (c['payment_mode'] == 'cash') cash += amt;
          if (c['payment_mode'] == 'upi') upi += amt;
        }

        if (mounted) {
          setState(() {
            _collectedCustomers = custs.where((c) => collectedIdMap.containsKey(c['id'])).map((c) {
               final coll = collectedIdMap[c['id']];
               return {...c as Map<String, dynamic>, 'amount': coll['amount'], 'mode': coll['payment_mode']};
            }).toList();
            _pendingCustomers = custs.where((c) => !collectedIdMap.containsKey(c['id'])).toList();
            _totalCollected = collected;
            _totalCash = cash;
            _totalUpi = upi;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('AgentLines _fetchData error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _optimizeRoute() async {
    setState(() => _isLoading = true);
    // 1. Get current location (Heuristic coordinates for demo)
    double lat = 12.9716; 
    double lng = 77.5946;
    
    final token = await widget.storage.read(key: 'jwt_token');
    if (token != null) {
      final optimized = await widget.apiService.optimizeRoute(widget.line['id'], lat, lng, token);
      if (mounted) {
        setState(() {
          // Re-map pending customers based on AI priority
          final collectedIds = _collectedCustomers.map((c) => c['id']).toSet();
          _pendingCustomers = optimized.where((c) => !collectedIds.contains(c['id'])).toList();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI: Route prioritized by proximity & risk factor'),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.line['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      _isLoading 
                        ? const Text("Loading...", style: TextStyle(fontSize: 12, color: Colors.grey))
                        : Text(
                            "${_collectedCustomers.length} / ${_pendingCustomers.length + _collectedCustomers.length} Collected Today",
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _optimizeRoute, 
                  icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.indigo),
                  label: Text("AI Optimize", style: GoogleFonts.outfit(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: TextButton.styleFrom(backgroundColor: Colors.indigo.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                  child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildReportButton(context, Icons.summarize_rounded, "Daily Report", 'daily'),
                const SizedBox(width: 8),
                _buildReportButton(context, Icons.calendar_view_week_rounded, "Weekly Report", 'weekly'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                ),
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: "PENDING"),
                  Tab(text: "COLLECTED"),
                  Tab(text: "REPORT"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : TabBarView(
                      children: [
                        _buildCustomerList(_pendingCustomers, true),
                        _buildCustomerList(_collectedCustomers, false),
                        _buildReportTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList(List<dynamic> customers, bool isPending) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline : Icons.history_rounded, 
              size: 64, 
              color: Colors.grey.withValues(alpha: 0.2)
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? "All collections done!" : "No collections yet",
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final cust = customers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isPending ? AppTheme.primaryColor : Colors.green).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (index + 1).toString(),
                  style: TextStyle(
                    color: isPending ? AppTheme.primaryColor : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(cust['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(cust['area'] ?? 'No Area', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, color: Colors.blue, size: 20),
                  onPressed: () {
                     // Open customer detail directly to the Passbook section or show QR dialog
                     // For simplicity, we'll navigate to detail and then they can tap the button there
                     // Or even better, let's just navigate to the detail screen as it's the source of truth
                     Navigator.pushNamed(context, '/admin/customer_detail', arguments: cust['id']);
                  },
                ),
                isPending 
                    ? const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor)
                    : const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            onTap: isPending ? () {
              Navigator.pop(context); // Close sheet
              Navigator.pushNamed(context, '/collection_entry', arguments: {
                ...cust,
                'line_id': widget.line['id'],
              });
            } : null,
          ),
        );
      },
    );
  }
  Widget _buildReportTab() {
    final totalCustomers = _pendingCustomers.length + _collectedCustomers.length;
    final paidCount = _collectedCustomers.length;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _buildSummaryRow("Total Collected", "₹$_totalCollected", icon: Icons.payments_rounded, color: Colors.green),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildSimpleTally("Cash", "₹$_totalCash", Icons.money_rounded, Colors.orange)),
                    Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
                    Expanded(child: _buildSimpleTally("UPI", "₹$_totalUpi", Icons.account_balance_rounded, Colors.indigo)),
                  ],
                ),
                const Divider(height: 24),
                _buildSummaryRow("Coverage", "$paidCount / $totalCustomers Customers", icon: Icons.people_rounded, color: Colors.blue),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Route Breakdown", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              _buildReportButton(context, Icons.print_rounded, "Print Full PDF", 'daily'),
            ],
          ),
          const SizedBox(height: 12),
          ... [
            ..._collectedCustomers.map((c) => _buildReportItem(c, true)),
            ..._pendingCustomers.map((c) => _buildReportItem(c, false)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {IconData? icon, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) Icon(icon, size: 18, color: color ?? Colors.grey),
            if (icon != null) const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ],
        ),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: color ?? Colors.black)),
      ],
    );
  }

  Widget _buildSimpleTally(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }

  Widget _buildReportItem(dynamic cust, bool isPaid) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isPaid) {
            Navigator.pushNamed(context, '/collection_entry', arguments: {
              ...cust as Map<String, dynamic>,
              'line_id': widget.line['id'],
            });
          } else {
            Navigator.pushNamed(context, '/admin/customer_detail', arguments: cust['id']);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
          ),
          child: Row(
            children: [
              Icon(isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: isPaid ? Colors.green : Colors.grey, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(cust['name'] ?? 'Unknown', style: TextStyle(fontWeight: isPaid ? FontWeight.bold : FontWeight.normal, fontSize: 14))),
              if (isPaid)
                 Text("₹${cust['amount']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green)),
              if (!isPaid)
                 const Text("Pending", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportButton(BuildContext context, IconData icon, String label, String period) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LineReportScreen(lineId: widget.line['id'], period: period)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
