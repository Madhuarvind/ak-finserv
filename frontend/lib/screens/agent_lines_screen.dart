import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

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
                        title: Text(line['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final token = await widget.storage.read(key: 'jwt_token');
    if (token != null) {
      // 1. Fetch all customers in this line
      final custs = await widget.apiService.getLineCustomers(widget.line['id'], token);
      
      // 2. Fetch today's collections to see who already paid
      final history = await widget.apiService.getCollectionHistory(token);
      
      final today = DateTime.now();
      final collectedIds = history.where((c) {
        final dateStr = c['time'] ?? c['created_at'];
        if (dateStr == null) return false;
        final date = DateTime.parse(dateStr).toLocal();
        return date.year == today.year && date.month == today.month && date.day == today.day && c['status'] != 'rejected';
      }).map((c) => c['customer_id'] ?? c['customer']).toSet();

      if (mounted) {
        setState(() {
          _collectedCustomers = custs.where((c) => collectedIds.contains(c['id'])).toList();
          _pendingCustomers = custs.where((c) => !collectedIds.contains(c['id'])).toList();
          _isLoading = false;
        });
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
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.line['name'], style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                    _isLoading 
                      ? const Text("Loading...", style: TextStyle(fontSize: 12, color: Colors.grey))
                      : Text(
                          "${_collectedCustomers.length} / ${_pendingCustomers.length + _collectedCustomers.length} Collected Today",
                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                  child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ),
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
            title: Text(cust['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(cust['area'] ?? 'No Area', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: isPending 
                ? const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor)
                : const Icon(Icons.check_circle, color: Colors.green),
            onTap: isPending ? () {
              Navigator.pop(context); // Close sheet
              Navigator.pushNamed(context, '/collection_entry', arguments: cust);
            } : null,
          ),
        );
      },
    );
  }
}
