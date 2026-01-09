import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/add_customer_dialog.dart';
import 'customer_detail_screen.dart';
import 'dart:async';

class AdminCustomerListScreen extends StatefulWidget {
  const AdminCustomerListScreen({super.key});

  @override
  State<AdminCustomerListScreen> createState() => _AdminCustomerListScreenState();
}

class _AdminCustomerListScreenState extends State<AdminCustomerListScreen> {
  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _customers = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _customers = [];
    }

    setState(() => _isLoading = true);
    
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final result = await _apiService.getAllCustomers(
        page: _page,
        search: _searchController.text,
        token: token,
      );
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _customers = result['customers'];
          } else {
            _customers.addAll(result['customers']);
          }
          _totalPages = result['pages'] ?? 1;
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {

      _debounce!.cancel();

    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadCustomers(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('All Customers', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by Name, Mobile, ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isLoading && _customers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? Center(child: Text('No customers found', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _customers.length + (_page < _totalPages ? 1 : 0),
                        itemBuilder: (context, index) {
                           if (index == _customers.length) {
                             // Load more
                             _page++;
                             _loadCustomers();
                             return const Padding(
                               padding: EdgeInsets.all(8.0),
                               child: Center(child: CircularProgressIndicator()),
                             );
                           }
                           
                           final customer = _customers[index];


                           return Card(
                             margin: const EdgeInsets.only(bottom: 12),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             child: ListTile(
                               onTap: () async {
                                 await Navigator.push(
                                   context,
                                   MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer['id'])),
                                 );
                                 _loadCustomers(refresh: true);
                               },
                               leading: CircleAvatar(
                                 backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                 child: Text(customer['name'][0].toUpperCase(), style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                               ),
                               title: Text(customer['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                               subtitle: Text("${customer['customer_id'] ?? 'Pending'} • ${customer['mobile']}"),
                               trailing: Chip(
                                 label: Text(customer['status'] ?? 'Active', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                 backgroundColor: customer['status'] == 'active' ? Colors.green : Colors.grey,
                                 padding: EdgeInsets.zero,
                               ),
                             ),
                           );
                        },
                      ),
          ),
        ],
      ),
       floatingActionButton: FloatingActionButton.extended(
         onPressed: () async {
           final result = await showDialog(
             context: context,
             builder: (context) => const AddCustomerDialog(),
           );
           if (result == true && mounted) {
             _loadCustomers(refresh: true);
           }
         },
         backgroundColor: AppTheme.primaryColor,
         icon: const Icon(Icons.person_add, color: Colors.white),
         label: Text('Add Customer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
       ),
    );
  }
}
