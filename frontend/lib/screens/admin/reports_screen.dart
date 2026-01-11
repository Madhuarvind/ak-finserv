import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../line_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  // Daily Report State
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _dailyData;
  bool _isLoadingDaily = false;

  // Outstanding State
  List<dynamic> _outstandingList = [];
  bool _isLoadingOutstanding = false;

  // Overdue State
  List<dynamic> _overdueList = [];
  bool _isLoadingOverdue = false;

  // Agent State
  List<dynamic> _agentList = [];
  bool _isLoadingAgents = false;

  // Reminders State
  List<dynamic> _remindersList = [];
  bool _isLoadingReminders = false;

  // Line-Wise State
  List<dynamic> _linesList = [];
  bool _isLoadingLines = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchDailyReport();
    _tabController.addListener(() {
      if (_tabController.index == 1 && _outstandingList.isEmpty) _fetchOutstanding();
      if (_tabController.index == 2 && _overdueList.isEmpty) _fetchOverdue();
      if (_tabController.index == 3 && _agentList.isEmpty) _fetchAgents();
      if (_tabController.index == 4 && _remindersList.isEmpty) _fetchReminders();
      if (_tabController.index == 5 && _linesList.isEmpty) _fetchLines();
    });
  }

  Future<void> _fetchReminders() async {
    if (!mounted) return;
    setState(() => _isLoadingReminders = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final list = await _apiService.getDueTomorrowReminders(token);
      if (mounted) setState(() { _remindersList = list; _isLoadingReminders = false; });
    }
  }

  Future<void> _sendBulkReminders() async {
    final token = await _storage.read(key: 'jwt_token');
    if (!mounted) return;
    if (token != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      
      final res = await _apiService.sendBulkReminders(token);
      
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI Blast: ${res['msg'] ?? 'Reminders sent'} via ${res['provider']}"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String mobile, dynamic amount, String customerName) async {
    // Standardize mobile for India (+91) if not already present
    String phone = mobile.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = "91$phone";
    
    final message = "Vanakkam $customerName, this is a reminder for your Vasool payment of ₹$amount due tomorrow. Please keep it ready. Thank you!";
    final url = "whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        // Fallback to web link if app not found
        final webUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Cannot open WhatsApp. $e")),
        );
      }
    }
  }

  Future<void> _fetchDailyReport() async {
    setState(() => _isLoadingDaily = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      // Fetch for single day: start=end=date
      final data = await _apiService.getDailyReport(token, startDate: "${dateStr}T00:00:00", endDate: "${dateStr}T23:59:59");
      if (mounted) {
        setState(() {
          _dailyData = data;
          _isLoadingDaily = false;
        });
      }
    }
  }

  Future<void> _fetchOutstanding() async {
    setState(() => _isLoadingOutstanding = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final list = await _apiService.getOutstandingReport(token);
      if (mounted) setState(() { _outstandingList = list; _isLoadingOutstanding = false; });
    }
  }

  Future<void> _fetchOverdue() async {
    setState(() => _isLoadingOverdue = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final list = await _apiService.getOverdueReport(token);
      if (mounted) setState(() { _overdueList = list; _isLoadingOverdue = false; });
    }
  }

  Future<void> _fetchAgents() async {
    setState(() => _isLoadingAgents = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final list = await _apiService.getAgentPerformanceList(token);
      if (mounted) setState(() { _agentList = list; _isLoadingAgents = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reports & Analytics", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: "Daily"),
            Tab(text: "Outstanding"),
            Tab(text: "Risk"),
            Tab(text: "Agents"),
            Tab(text: "AI Reminders"),
            Tab(text: "Line-Wise"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyTab(),
          _buildOutstandingTab(),
          _buildOverdueTab(),
          _buildAgentsTab(),
          _buildRemindersTab(),
          _buildLineWiseTab(),
        ],
      ),
    );
  }

  Widget _buildDailyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('EEE, dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) {
                     setState(() => _selectedDate = picked);
                     _fetchDailyReport();
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: const Text("Change Date"),
              )
            ],
          ),
        ),
        if (_dailyData != null && _dailyData!['summary'] != null)
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: Row(
               children: [
                 _buildSummaryCard("Total", "₹${_dailyData!['summary']['total']}", Colors.blue),
                 const SizedBox(width: 8),
                 _buildSummaryCard("Cash", "₹${_dailyData!['summary']['cash']}", Colors.green),
                 const SizedBox(width: 8),
                 _buildSummaryCard("UPI", "₹${_dailyData!['summary']['upi']}", Colors.purple),
               ],
             ),
             ),
        const SizedBox(height: 20),
        if (_dailyData != null && _dailyData!['summary'] != null)
           SizedBox(
             height: 200,
             child: PieChart(
               PieChartData(
                 sectionsSpace: 0,
                 centerSpaceRadius: 40,
                 sections: [
                   PieChartSectionData(
                     color: Colors.green,
                     value: (_dailyData!['summary']['cash'] as num).toDouble(),
                     title: 'Cash',
                     radius: 50,
                     titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                   ),
                   PieChartSectionData(
                     color: Colors.purple,
                     value: (_dailyData!['summary']['upi'] as num).toDouble(),
                     title: 'UPI',
                     radius: 50,
                     titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                   ),
                 ],
               ),
             ),
           ),
        const SizedBox(height: 10),
        Expanded(
          child: _isLoadingDaily 
            ? const Center(child: CircularProgressIndicator())
            : (_dailyData == null || _dailyData!['report'] == null || (_dailyData!['report'] as List).isEmpty)
                ? const Center(child: Text("No collections found"))
                : ListView.builder(
                    itemCount: (_dailyData!['report'] as List).length,
                    itemBuilder: (ctx, i) {
                      final item = _dailyData!['report'][i];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.receipt_long, size: 16)),
                        title: Text("₹${item['amount']} - ${item['customer_name']}"),
                        subtitle: Text("${item['mode'].toString().toUpperCase()} • By ${item['agent_name']}"),
                        trailing: Text(DateFormat('hh:mm a').format(DateTime.parse(item['time']).toLocal())),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildOutstandingTab() {
    return _isLoadingOutstanding 
       ? const Center(child: CircularProgressIndicator())
       : ListView.builder(
           itemCount: _outstandingList.length,
           itemBuilder: (ctx, i) {
             final item = _outstandingList[i];
             return Card(
               margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               child: ListTile(
                 title: Text(item['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                 subtitle: Text("Loan #${item['loan_id']} • ${item['area']}"),
                 trailing: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Text("Pending", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                     Text("₹${item['pending']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                   ],
                 ),
               ),
             );
           },
       );
  }

  Widget _buildOverdueTab() {
     return _isLoadingOverdue
       ? const Center(child: CircularProgressIndicator())
       : ListView.builder(
           itemCount: _overdueList.length,
           itemBuilder: (ctx, i) {
             final item = _overdueList[i];
             return Card(
               color: Colors.red.shade50,
               margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               child: ListTile(
                 leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                 title: Text(item['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                 subtitle: Text("${item['missed_emis']} Missed EMIs\nSince ${item['oldest_due_date']}"),
                 trailing: Text("₹${item['total_overdue']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               ),
             );
           },
       );
  }

   Widget _buildAgentsTab() {
     return _isLoadingAgents
       ? const Center(child: CircularProgressIndicator())
       : ListView.builder(
           itemCount: _agentList.length,
           itemBuilder: (ctx, i) {
             final item = _agentList[i];
             return Card(
               margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               child: ListTile(
                 leading: CircleAvatar(child: Text(item['name'][0])),
                 title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                 subtitle: Text("${item['assigned_customers']} Assigned Customers"),
                 trailing: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     const Text("Collected", style: TextStyle(fontSize: 10, color: Colors.grey)),
                     Text("₹${item['collected']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                   ],
                 ),
               ),
             );
           },
       );
  }

  Widget _buildRemindersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.indigo[900]!, Colors.indigo[600]!]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AI Reminders", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("${_remindersList.length} customers due tomorrow", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _remindersList.isEmpty ? null : _sendBulkReminders,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("Blast All", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoadingReminders
            ? const Center(child: CircularProgressIndicator())
            : _remindersList.isEmpty
                ? const Center(child: Text("No upcoming payments found for tomorrow"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _remindersList.length,
                    itemBuilder: (ctx, i) {
                      final item = _remindersList[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                        ),
                        child: ListTile(
                          onTap: () => _launchWhatsApp(item['mobile'] ?? '', item['amount'], item['customer_name']),
                          leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: Icon(Icons.send_rounded, color: Colors.green, size: 20)),
                          title: Text(item['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("₹${item['amount']} • ${item['area']}"),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildLineWiseTab() {
    return _isLoadingLines
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _linesList.length,
            itemBuilder: (ctx, i) {
              final line = _linesList[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.route, color: AppTheme.primaryColor),
                  ),
                  title: Text(line['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(line['area'] ?? ''),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // Navigate to existing Detail Report Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LineReportScreen(
                          lineId: line['id'],
                          period: 'daily',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchLines() async {
    if (!mounted) return;
    setState(() => _isLoadingLines = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final list = await _apiService.getAllLines(token);
        if (mounted) setState(() { _linesList = list; _isLoadingLines = false; });
      } catch (e) {
        if (mounted) setState(() => _isLoadingLines = false);
      }
    }
  }
}
