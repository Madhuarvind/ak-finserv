import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class CashSettlementScreen extends StatefulWidget {
  final bool isTab;
  const CashSettlementScreen({super.key, this.isTab = false});

  @override
  State<CashSettlementScreen> createState() => _CashSettlementScreenState();
}

class _CashSettlementScreenState extends State<CashSettlementScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  List<dynamic> _agents = [];
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchHistory();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final data = await _apiService.getDailySettlements(token);
        setState(() {
          _agents = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final history = await _apiService.getSettlementHistory(token);
        setState(() {
          _history = history;
        });
      }
    } catch (e) {
      debugPrint("Fetch History Error: $e");
    }
  }

  void _openSettlementDialog(Map<String, dynamic> agent) {
    final physicalCtrl = TextEditingController(text: (agent['physical_cash'] ?? 0).toString());
    final expensesCtrl = TextEditingController(text: (agent['expenses'] ?? 0).toString());
    final notesCtrl = TextEditingController(text: agent['notes'] ?? '');
    
    // Auto-fill physical with system if pending (convenience)
    if (agent['status'] == 'pending' && physicalCtrl.text == "0") {
       // physicalCtrl.text = agent['system_cash'].toString();
       physicalCtrl.text = ""; // Force them to type it? Or 0. Let's keep empty/0 to force count.
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double physical = double.tryParse(physicalCtrl.text) ?? 0;
          double expense = double.tryParse(expensesCtrl.text) ?? 0;
          double system = (agent['system_cash'] as num).toDouble();
          double diff = (physical + expense) - system;
          
          Color diffColor = Colors.green;
          if (diff < 0) diffColor = Colors.red;
          if (diff > 0) diffColor = Colors.blue;

          return AlertDialog(
            title: Text("Settle: ${agent['agent_name']}"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text("System Total (Cash):"),
                         Text("₹$system", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 16),
                   TextField(
                     controller: physicalCtrl,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: "Physical Cash Received", border: OutlineInputBorder()),
                     onChanged: (v) => setDialogState(() {}),
                   ),
                   const SizedBox(height: 12),
                   TextField(
                     controller: expensesCtrl,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: "Expenses (Snacks/Petrol)", border: OutlineInputBorder()),
                     onChanged: (v) => setDialogState(() {}),
                   ),
                   const SizedBox(height: 12),
                   TextField(
                     controller: notesCtrl,
                     decoration: const InputDecoration(labelText: "Notes", border: OutlineInputBorder()),
                   ),
                   const SizedBox(height: 20),
                   const Divider(),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text("Difference:", style: TextStyle(fontWeight: FontWeight.bold)),
                       Text(
                         "₹${diff.toStringAsFixed(2)}", 
                         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: diffColor)
                       ),
                     ],
                   ),
                   if (diff != 0)
                     Padding(
                       padding: const EdgeInsets.only(top: 4.0),
                       child: Text(
                         diff < 0 ? "Shortage of ₹${diff.abs().toStringAsFixed(2)}" : "Excess of ₹${diff.abs().toStringAsFixed(2)}",
                         style: TextStyle(color: diffColor, fontSize: 12),
                       ),
                     )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
              ElevatedButton(
                onPressed: () async {
                   final token = await _storage.read(key: 'jwt_token');
                   if (token != null) {
                     await _apiService.verifySettlement({
                       'agent_id': agent['agent_id'],
                       'physical_cash': physical,
                       'expenses': expense,
                       'notes': notesCtrl.text
                     }, token);
                     if (context.mounted) Navigator.pop(context);
                     _fetchData();
                   }
                },
                child: const Text("VERIFY & SAVE"),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTab) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: "Pending / Today"),
                  Tab(text: "History"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPendingList(),
                  _buildHistoryList(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Daily Cash Settlement', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          elevation: 0,
          bottom: TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
               Tab(text: "Pending / Today"),
               Tab(text: "History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
             _buildPendingList(),
             _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_agents.isEmpty) return const Center(child: Text("No active agents found"));
    final pendingAgents = _agents; // For now all agents for today are shown here
    
    if (pendingAgents.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade200),
             const SizedBox(height: 16),
             Text("All Settled!", style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey)),
           ],
         ),
       );
    }

    return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingAgents.length,
            itemBuilder: (ctx, i) {
              final agent = pendingAgents[i];
              final bool isVerified = agent['status'] == 'verified';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () => _openSettlementDialog(agent),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(child: Text(agent['agent_name'][0].toUpperCase())),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(agent['agent_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (isVerified)
                                      const Text("Verified", style: TextStyle(color: Colors.green, fontSize: 12))
                                    else
                                      const Text("Pending", style: TextStyle(color: Colors.orange, fontSize: 12))
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("System: ₹${agent['system_cash']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (isVerified)
                                  Text("Diff: ₹${agent['difference']}", 
                                    style: TextStyle(
                                      color: (agent['difference'] as num) < 0 ? Colors.red : Colors.green, 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                              ],
                            )
                          ],
                        ),
                        if (isVerified) ...[
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Handover: ₹${agent['physical_cash']}", style: const TextStyle(fontSize: 12)),
                              Text("Exp: ₹${agent['expenses']}", style: const TextStyle(fontSize: 12)),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            const Text("No past settlements found"),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final item = _history[i];
        final diff = (item['difference'] as num).toDouble();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['agent_name'] ?? 'Agent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(item['date'] ?? '', style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: diff == 0 ? Colors.green.shade50 : (diff < 0 ? Colors.red.shade50 : Colors.blue.shade50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "₹$diff",
                      style: TextStyle(
                        color: diff == 0 ? Colors.green : (diff < 0 ? Colors.red : Colors.blue),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildHistItem("System", "₹${item['system_cash']}"),
                   _buildHistItem("Physical", "₹${item['physical_cash']}"),
                   _buildHistItem("Expenses", "₹${item['expenses']}"),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
