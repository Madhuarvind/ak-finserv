import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vasool_drive/widgets/add_customer_dialog.dart';
import 'customer_detail_screen.dart';
import '../line_report_screen.dart';

class LineCustomersScreen extends StatefulWidget {
  final Map<String, dynamic> line;
  const LineCustomersScreen({super.key, required this.line});

  @override
  State<LineCustomersScreen> createState() => _LineCustomersScreenState();
}

class _LineCustomersScreenState extends State<LineCustomersScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  List<dynamic> _lineCustomers = [];
  List<dynamic> _allCustomers = [];
  bool _isLoading = true;
  List<dynamic> _pendingCustomers = [];
  List<dynamic> _collectedCustomers = [];
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
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final lineCusts = await _apiService.getLineCustomers(widget.line['id'], token);
        final allCusts = await _apiService.getCustomers(token);
        final history = await _apiService.getCollectionHistory(token);

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

        setState(() {
          _lineCustomers = lineCusts;
          _collectedCustomers = _lineCustomers.where((c) => collectedIdMap.containsKey(c['id'])).map((c) {
             final coll = collectedIdMap[c['id']];
             return {...c as Map<String, dynamic>, 'amount': coll['amount'], 'mode': coll['payment_mode']};
          }).toList();
          _pendingCustomers = _lineCustomers.where((c) => !collectedIdMap.containsKey(c['id'])).toList();
          
          _totalCollected = collected;
          _totalCash = cash;
          _totalUpi = upi;

          // Filter out customers already in the line
          final existingIds = _lineCustomers.map((lc) => lc['id']).toSet();
          _allCustomers = allCusts.where((c) => !existingIds.contains(c['id'])).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    }
  }

  Future<void> _addCustomer() async {
    String searchQuery = '';
    
    return showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final filtered = _allCustomers.where((c) => 
            c['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
            c['mobile_number'].contains(searchQuery)
          ).toList();

          return AlertDialog(
            title: Text(AppLocalizations.of(dialogContext).translate('add_customer')),
            content: SizedBox(
              width: double.maxFinite,
              height: 400, // Fixed height for core content stability
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(dialogContext).translate('search_users'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) => setDialogState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(AppLocalizations.of(dialogContext).translate('no_customers_found')),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await showDialog(
                                      context: dialogContext,
                                      builder: (subDialogContext) => const AddCustomerDialog(),
                                    );
                                    if (result == true) {
                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                      _fetchData();
                                    }
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: Text(AppLocalizations.of(dialogContext).translate('create_customer')),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (itemContext, index) {
                              final cust = filtered[index];
                              return ListTile(
                                dense: true,
                                title: Text(cust['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(cust['mobile'] ?? cust['mobile_number'] ?? 'No Mobile'),
                                trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                onTap: () async {
                                  try {
                                    final token = await _storage.read(key: 'jwt_token');
                                    if (token != null) {
                                      await _apiService.addCustomerToLine(widget.line['id'], cust['id'], token);
                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                      _fetchData();
                                    }
                                    } catch (e) {
                                      if (!dialogContext.mounted) return;
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(content: Text('Error adding customer: $e')),
                                      );
                                    }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(dialogContext).translate('cancel')),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _updateOrder() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final order = _lineCustomers.map<int>((c) => c['id'] as int).toList();
        await _apiService.reorderLineCustomers(widget.line['id'], order, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('reorder_success'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.line['name'],
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              AppLocalizations.of(context).translate('manage_customers'),
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                   const TabBar(
                     labelColor: Colors.blue,
                     unselectedLabelColor: Colors.grey,
                     tabs: [
                       Tab(text: "CUSTOMERS"),
                       Tab(text: "REPORT"),
                     ],
                   ),
                   Expanded(
                     child: TabBarView(
                       children: [
                         _lineCustomers.isEmpty
                             ? Center(
                                 child: Column(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                     const SizedBox(height: 16),
                                     Text(
                                       AppLocalizations.of(context).translate('no_customers_found'),
                                       style: GoogleFonts.poppins(color: Colors.grey),
                                     ),
                                     const SizedBox(height: 16),
                                     ElevatedButton(
                                       onPressed: _addCustomer,
                                       child: Text(AppLocalizations.of(context).translate('add_customer')),
                                     ),
                                   ],
                                 ),
                               )
                             : ReorderableListView(
                                 padding: const EdgeInsets.all(16),
                                 onReorder: (oldIndex, newIndex) {
                                   setState(() {
                                     if (oldIndex < newIndex) {
                                       newIndex -= 1;
                                     }
                                     final item = _lineCustomers.removeAt(oldIndex);
                                     _lineCustomers.insert(newIndex, item);
                                   });
                                   _updateOrder();
                                 },
                                 children: _lineCustomers.map((cust) {
                                   return Container(
                                     key: ValueKey(cust['id']),
                                     margin: const EdgeInsets.only(bottom: 12),
                                     decoration: BoxDecoration(
                                       color: Colors.white,
                                       borderRadius: BorderRadius.circular(32),
                                       border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                                     ),
                                     child: ListTile(
                                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                       leading: CircleAvatar(
                                         backgroundColor: const Color(0xFFAEEA44), // Lime Green
                                         foregroundColor: Colors.black,
                                         radius: 20,
                                         child: Text(
                                           (_lineCustomers.indexOf(cust) + 1).toString(),
                                           style: const TextStyle(fontWeight: FontWeight.bold),
                                         ),
                                       ),
                                       title: Text(cust['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                       subtitle: Text('${cust['mobile']} • ${cust['area']}', style: GoogleFonts.outfit(color: Colors.black54)),
                                       trailing: const Icon(Icons.drag_handle, color: Colors.black54),
                                       onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CustomerDetailScreen(customerId: cust['id']),
                                            ),
                                          );
                                       },
                                     ),
                                   );
                                 }).toList(),
                               ),
                         Padding(
                           padding: const EdgeInsets.all(16.0),
                           child: _buildReportTab(),
                         ),
                       ],
                     ),
                   ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add),
      ),
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
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
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
              _buildReportActions(),
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

  Widget _buildReportActions() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _navigateToReport('daily'), 
          icon: const Icon(Icons.today_rounded, color: Colors.blue)
        ),
        IconButton(
          onPressed: () => _navigateToReport('weekly'), 
          icon: const Icon(Icons.date_range_rounded, color: Colors.orange)
        ),
        IconButton(
          onPressed: () => _navigateToReport('daily'), 
          icon: const Icon(Icons.print_rounded, color: Colors.black54)
        ),
      ],
    );
  }

  void _navigateToReport(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LineReportScreen(
          lineId: widget.line['id'],
          period: type,
        ),
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> cust, bool isPaid) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDetailScreen(customerId: cust['id']),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPaid ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cust['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(cust['area'] ?? 'No Area', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              if (isPaid)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${cust['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text("${cust['mode']}".toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                )
              else
                const Text("PENDING", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
        ),
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
}
