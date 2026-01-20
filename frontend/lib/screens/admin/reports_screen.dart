import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../line_report_screen.dart';

import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  
  // Daily Report State
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _dailyData;
  bool _isLoadingDaily = false;
  bool _isDownloadingTally = false;

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

  Future<void> _downloadTallyXml() async {
    setState(() => _isDownloadingTally = true);
    final token = await _storage.read(key: 'jwt_token');
    
    if (token != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final xmlContent = await _apiService.downloadTallyDaybook(token, date: dateStr);
      
      if (mounted) {
        setState(() => _isDownloadingTally = false);
        
        if (xmlContent != null) {
          if (kIsWeb) {
            // Web Download
            final bytes = utf8.encode(xmlContent);
            final blob = html.Blob([bytes]);
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute("download", "Tally_Daybook_$dateStr.xml")
              ..click();
            html.Url.revokeObjectUrl(url);
          } else {
            // Mobile/Desktop Show Data
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Tally XML Downloaded (Check device storage logic needed for mobile)")),
            );
            // In a real mobile app, use path_provider to write to Documents
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Failed to download Tally XML")),
          );
        }
      }
    }
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Reports & Analytics", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.white24,
          indicatorColor: AppTheme.primaryColor,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
          isScrollable: true,
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
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, dd MMM yyyy').format(_selectedDate), 
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              Row(
                children: [
                   _isDownloadingTally 
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2))
                   : TextButton.icon(
                      onPressed: _downloadTallyXml, 
                      icon: const Icon(Icons.file_download, color: AppTheme.primaryColor, size: 20),
                      label: Text("TALLY XML", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                   ),
                   const SizedBox(width: 10),
                   ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context, 
                        initialDate: _selectedDate, 
                        firstDate: DateTime(2020), 
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppTheme.primaryColor,
                              onPrimary: Colors.black,
                              surface: Color(0xFF1E293B),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _fetchDailyReport();
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text("DATE", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        if (_dailyData != null && _dailyData!['summary'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildSummaryCard("TOTAL", "₹${_dailyData!['summary']['total']}", Colors.blueAccent),
                  const SizedBox(width: 12),
                  _buildSummaryCard("CASH", "₹${_dailyData!['summary']['cash']}", Colors.greenAccent),
                  const SizedBox(width: 12),
                  _buildSummaryCard("UPI", "₹${_dailyData!['summary']['upi']}", Colors.purpleAccent),
                ],
              ),
            ),
        const SizedBox(height: 20),
        if (_dailyData != null && _dailyData!['summary'] != null)
           SizedBox(
             height: 180,
             child: PieChart(
               PieChartData(
                 sectionsSpace: 4,
                 centerSpaceRadius: 30,
                 sections: [
                   PieChartSectionData(
                     color: Colors.greenAccent.withValues(alpha: 0.8),
                     value: (_dailyData!['summary']['cash'] as num).toDouble(),
                     title: 'CASH',
                     radius: 40,
                     titleStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                   ),
                   PieChartSectionData(
                     color: Colors.purpleAccent.withValues(alpha: 0.8),
                     value: (_dailyData!['summary']['upi'] as num).toDouble(),
                     title: 'UPI',
                     radius: 40,
                     titleStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: (_dailyData!['report'] as List).length,
                    itemBuilder: (ctx, i) {
                      final item = _dailyData!['report'][i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, size: 20, color: Colors.white54),
                          ),
                          title: Text("${item['customer_name']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                          subtitle: Text(
                            "${item['mode'].toString().toUpperCase()} • By ${item['agent_name']}",
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("₹${item['amount']}", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.primaryColor, fontSize: 16)),
                              Text(
                                DateFormat('hh:mm a').format(DateTime.parse(item['time']).toLocal()),
                                style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
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
           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
           itemCount: _outstandingList.length,
           itemBuilder: (ctx, i) {
             final item = _outstandingList[i];
             return Container(
               margin: const EdgeInsets.only(bottom: 12),
               decoration: BoxDecoration(
                 color: Colors.white.withValues(alpha: 0.05),
                 borderRadius: BorderRadius.circular(24),
                 border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
               ),
               child: ListTile(
                 title: Text(item['customer_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                 subtitle: Text("Loan #${item['loan_id']} • ${item['area']}", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
                 trailing: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Text("PENDING", style: GoogleFonts.outfit(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                     Text("₹${item['pending']}", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 18)),
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
           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
           itemCount: _overdueList.length,
           itemBuilder: (ctx, i) {
             final item = _overdueList[i];
             return Container(
               margin: const EdgeInsets.only(bottom: 12),
               decoration: BoxDecoration(
                 color: Colors.red.withValues(alpha: 0.05),
                 borderRadius: BorderRadius.circular(24),
                 border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
               ),
               child: ListTile(
                 leading: Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                   child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                 ),
                 title: Text(item['customer_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                 subtitle: Text(
                   "${item['missed_emis']} Missed EMIs\nSince ${item['oldest_due_date']}",
                   style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                 ),
                 trailing: Text("₹${item['total_overdue']}", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.redAccent)),
               ),
             );
           },
       );
  }

   Widget _buildAgentsTab() {
     return _isLoadingAgents
       ? const Center(child: CircularProgressIndicator())
       : ListView.builder(
           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
           itemCount: _agentList.length,
           itemBuilder: (ctx, i) {
             final item = _agentList[i];
             return Container(
               margin: const EdgeInsets.only(bottom: 12),
               decoration: BoxDecoration(
                 color: Colors.white.withValues(alpha: 0.05),
                 borderRadius: BorderRadius.circular(24),
                 border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
               ),
               child: ListTile(
                 leading: Container(
                   width: 48,
                   height: 48,
                   decoration: BoxDecoration(
                     color: AppTheme.primaryColor.withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(16),
                   ),
                   child: Center(
                     child: Text(item['name'][0].toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                   ),
                 ),
                 title: Text(item['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                 subtitle: Text("${item['assigned_customers']} Assigned Customers", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
                 trailing: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Text("COLLECTED", style: GoogleFonts.outfit(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                     Text("₹${item['collected']}", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.greenAccent)),
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
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AI REMINDERS", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                      Text("${_remindersList.length} DUES TOMORROW", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _remindersList.isEmpty ? null : _sendBulkReminders,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, 
                    foregroundColor: Colors.black, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text("BLAST ALL", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _remindersList.length,
                    itemBuilder: (ctx, i) {
                      final item = _remindersList[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: ListTile(
                          onTap: () => _launchWhatsApp(item['mobile'] ?? '', item['amount'], item['customer_name']),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.chat_rounded, color: Colors.greenAccent, size: 24),
                          ),
                          title: Text(item['customer_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                          subtitle: Text("₹${item['amount']} • ${item['area']}", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _linesList.length,
            itemBuilder: (ctx, i) {
              final line = _linesList[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.route_rounded, color: AppTheme.primaryColor, size: 24),
                  ),
                  title: Text(line['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  subtitle: Text(line['area'] ?? '', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                  onTap: () {
                    // Navigate to existing Detail Report Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LineReportScreen(
                          lineId: line['id'],
                          period: 'daily',
                          lineName: line['name'],
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(title, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Text(value, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
