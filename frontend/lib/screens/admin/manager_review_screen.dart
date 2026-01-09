import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class ManagerReviewScreen extends StatefulWidget {
  const ManagerReviewScreen({super.key});

  @override
  State<ManagerReviewScreen> createState() => _ManagerReviewScreenState();
}

class _ManagerReviewScreenState extends State<ManagerReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  List<dynamic> _pending = [];
  List<dynamic> _history = [];
  Map<String, dynamic> _summary = {"total": 0.0, "count": 0, "cash": 0.0, "upi": 0.0};
  bool _isLoading = true;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        // Fetch Pending (always current)
        final pendingResult = await _apiService.getPendingCollections(token);
        
        // Fetch History based on selected range
        final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
        
        final reportData = await _apiService.getDailyReport(
          token, 
          startDate: start.toIso8601String().split('.').first,
          endDate: end.toIso8601String().split('.').first
        );

        if (mounted) {
          setState(() {
            _pending = pendingResult;
            _history = reportData['report'] ?? [];
            _summary = reportData['summary'] ?? _summary;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching data: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.updateCollectionStatus(id, status, token);
      if (mounted) {
        if (result.containsKey('msg') && (result['msg'] == 'collection_updated_successfully' || result['status'] == status)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Collection $status successfully!'),
              backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            ),
          );
          _fetchAllData();
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['msg'] ?? 'Update failed'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(context.translate('collection_review'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _selectDateRange,
            tooltip: "Filter by Date Range",
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: "Pending (${_pending.length})"),
            Tab(text: "All History"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                _buildSummaryBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
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

  Widget _buildSummaryBanner() {
    final rangeText = _startDate.day == _endDate.day && _startDate.month == _endDate.month && _startDate.year == _endDate.year
        ? "Today"
        : "${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}";

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(rangeText, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              InkWell(
                onTap: _selectDateRange,
                child: const Text("Change", style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem("Total Value", "₹${_summary['total']}", Colors.green),
              _summaryItem("Count", "${_summary['count']}", Colors.blue),
              _summaryItem("Cash/UPI", "₹${_summary['cash']}/₹${_summary['upi']}", Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) return _buildEmptyState("No pending collections", Icons.check_circle_outline_rounded);
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _pending.length,
      itemBuilder: (context, index) => _buildCollectionCard(_pending[index], true),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) return _buildEmptyState("No record found for today", Icons.history_rounded);
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _history.length,
      itemBuilder: (context, index) => _buildCollectionCard(_history[index], false),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(msg, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> c, bool isActionable) {
    final dateStr = c['time'] ?? c['created_at'] ?? DateTime.now().toIso8601String();
    final date = DateTime.parse(dateStr).toLocal();
    final formattedDate = DateFormat('hh:mm a').format(date);
    final status = c['status']?.toString().toUpperCase() ?? 'PENDING';
    
    Color statusColor = Colors.orange;
    if (status == 'APPROVED') statusColor = Colors.green;
    if (status == 'REJECTED') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['customer_name'] ?? 'Loan #${c['loan_id']}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      '₹ ${c['amount']}',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c['mode']?.toString().toUpperCase() ?? 'CASH',
                      style: const TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Agent: ${c['agent_name'] ?? c['agent']}', style: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12)),
                const Spacer(),
                const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(formattedDate, style: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12)),
              ],
            ),
            if (isActionable) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(c['id'], 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('REJECT'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(c['id'], 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('APPROVE'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
