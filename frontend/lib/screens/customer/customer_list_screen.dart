import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/theme.dart';
import '../../services/local_db_service.dart';
import '../../services/api_service.dart';
import '../../widgets/add_customer_dialog.dart'; // Fixed relative import


class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _localDb = LocalDbService();
  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    
    // 1. Load Local (Instant)
    var localCustomers = await _localDb.getAllLocalCustomers();
    if (mounted) {
      setState(() => _customers = localCustomers);
    }
    
    // 2. Fetch Online (Update)
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        // We use the same 'getCustomers' which hits /collection/customers or create a new one.
        // Assuming getCustomers returns a list of backend customer objects.
        // We'll wrap them to match the local map structure or unify them.
        final onlineCustomers = await _apiService.getCustomers(token);
        
        if (onlineCustomers.isNotEmpty && mounted) {
           // Map backend format to local format for UI consistency
           final mappedOnline = onlineCustomers.map((c) => {
             'id': -1, // No local ID
             'name': c['name'],
             'mobile_number': c['mobile_number'],
             'area': c['area'] ?? 'Unknown',
             'customer_id': c['customer_id'],
             'server_id': c['id'],
             'is_synced': 1
           }).toList().cast<Map<String, dynamic>>();

           // Merge: Prefer online, but keep local-only (unsynced) ones
           // Simple strategy: Show Online + Unsynced Local
           final unsyncedLocal = localCustomers.where((c) => c['is_synced'] == 0 || c['is_synced'] == false).toList();
           
           setState(() {
             _customers = [...unsyncedLocal, ...mappedOnline];
             _isLoading = false;
           });
           return;
        }
      }
    } catch (e) {
      debugPrint("Error fetching online customers: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncCustomers() async {
    setState(() => _isSyncing = true);
    
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No auth token found'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Get pending customers from local DB
      final pendingCustomers = await _localDb.getPendingCustomers();
      
      debugPrint('=== FRONTEND SYNC DEBUG ===');
      debugPrint('Pending customers count: ${pendingCustomers.length}');
      
      if (pendingCustomers.isEmpty) {
        if (mounted) {
          // If nothing to sync up, maybe try to sync down (refresh list)
          _loadCustomers();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('List refreshed!'), backgroundColor: Colors.green),
          );
        }
        return;
      }

      debugPrint('Calling sync API...');
      
      // Call sync API
      final result = await _apiService.syncCustomers(pendingCustomers, token);
      
      if (result != null && result['synced'] != null) {
        // Update sync status for each customer
        final synced = result['synced'] as Map<String, dynamic>;
        
        for (var entry in synced.entries) {
          final localId = int.tryParse(entry.key);
          final syncData = entry.value as Map<String, dynamic>;
          final status = syncData['status'];
          
          if (localId != null && (status == 'created' || status == 'duplicate')) {
            await _localDb.updateCustomerSyncStatus(
              localId,
              syncData['server_id'],
              syncData['customer_id'],
            );
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synced ${synced.length} customer(s) successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadCustomers(); // Reload to show updated status
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync failed. Please try again.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('My Customers', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: _isSyncing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : Icon(Icons.sync, color: AppTheme.primaryColor),
            onPressed: _isSyncing ? null : _syncCustomers,
            tooltip: 'Sync Now',
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _customers.isEmpty 
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                // is_synced might be 1 (int) or true (bool) or just present
                final isSynced = customer['is_synced'] == 1 || customer['is_synced'] == true;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSynced ? Colors.green[100] : Colors.orange[100],
                      child: Icon(
                        Icons.person,
                        color: isSynced ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(customer['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "${customer['area'] ?? 'No Area'} • ${customer['mobile_number'] ?? ''}\n${isSynced ? (customer['customer_id'] ?? '') : 'Pending Sync'}",
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: isSynced 
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : const Icon(Icons.cloud_upload, color: Colors.orange, size: 20),
                    onTap: () {
                      // Navigate to detail
                      // Requires server_id for online fetch
                      final serverId = customer['server_id'];
                      if (serverId != null) {
                         Navigator.pushNamed(
                          context, 
                          '/admin/customer_detail', 
                          arguments: serverId
                        );
                      } else {
                         // Fallback for local-only? Currently detail screen expects ID.
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sync required to view full profile"))
                        );
                      }
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => const AddCustomerDialog(),
          );
          if (result == true) {
            _loadCustomers();
          }
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No customers found',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Tap + to add a new customer', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
           TextButton.icon(
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh List"),
          )
        ],
      ),
    );
  }
}
