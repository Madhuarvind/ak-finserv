import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import 'create_loan_screen.dart';
import 'loan_detail_screen.dart';

class LoanManagementScreen extends StatefulWidget {
  const LoanManagementScreen({super.key});

  @override
  State<LoanManagementScreen> createState() => _LoanManagementScreenState();
}

class _LoanManagementScreenState extends State<LoanManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  List<dynamic> _loans = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _fetchLoans();
  }

  Future<void> _fetchLoans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final loans = await _apiService.getAllLoans(token);
        if (mounted) {
          setState(() {
            _loans = loans;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredLoans {
    List<dynamic> list = _loans;
    
    // Status Filter
    switch (_tabController.index) {
      case 1: // Drafts
        list = list.where((l) => l['status'] == 'created').toList();
        break;
      case 2: // Active
        list = list.where((l) => l['status'] == 'active' || l['status'] == 'approved').toList();
        break;
      case 3: // Overdue
        list = list.where((l) => l['status'] == 'defaulted' || l['status'] == 'overdue').toList();
        break;
      case 4: // Closed
        list = list.where((l) => l['status'] == 'closed').toList();
        break;
    }

    // Search Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((l) {
        final name = (l['customer_name'] ?? '').toString().toLowerCase();
        final id = (l['loan_id'] ?? '').toString().toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Loan Portfolio", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search customer or loan ID...",
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: "All"),
                  Tab(text: "Drafts"),
                  Tab(text: "Active"),
                  Tab(text: "Overdue"),
                  Tab(text: "Closed"),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateLoanScreen()),
          );
          if (result == true) _fetchLoans();
        },
        label: Text("New Loan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _errorMessage.isNotEmpty
                  ? Center(child: Text("Error: $_errorMessage", style: const TextStyle(color: Colors.white)))
                  : RefreshIndicator(
                      onRefresh: _fetchLoans,
                      color: AppTheme.primaryColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _filteredLoans.length,
                        itemBuilder: (context, index) {
                          final loan = _filteredLoans[index];
                          return _buildLoanCard(loan);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildLoanCard(dynamic loan) {
    Color statusColor = Colors.grey;
    if (loan['status'] == 'active' || loan['status'] == 'approved') statusColor = Colors.greenAccent;
    if (loan['status'] == 'created') statusColor = Colors.orangeAccent;
    if (loan['status'] == 'closed') statusColor = Colors.blueAccent;
    if (loan['status'] == 'defaulted' || loan['status'] == 'overdue') statusColor = Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LoanDetailScreen(loanId: loan['id'])),
          );
          if (result == true) _fetchLoans();
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loan['loan_id'] ?? 'N/A', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3))
                    ),
                    child: Text(loan['status'].toString().toUpperCase(), 
                      style: GoogleFonts.outfit(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(loan['customer_name'] ?? 'Unknown Customer', 
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                     child: _infoCol("Principal", "₹${loan['principal_amount']}"),
                   ),
                   Expanded(
                     child: _infoCol("Tenure", "${loan['tenure']} ${loan['tenure_unit']}"),
                   ),
                   Expanded(
                     child: _infoCol("Interest", "${loan['interest_rate']}%"),
                   ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white70)),
      ],
    );
  }
}
