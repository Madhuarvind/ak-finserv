import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  
  String _selectedTable = 'Users';
  final List<String> _tables = [
    'Users', 
    'Customers', 
    'Loans', 
    'Lines', 
    'Collections',
    'DailySettlement',
    'CustomerVersion',
    'CustomerNote',
    'CustomerDocument',
    'SystemSetting'
  ];
  List<dynamic> _data = [];
  bool _isLoading = false;
  List<String> _columns = [];

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
        List<dynamic> result = [];
        switch (_selectedTable) {
          case 'Users':
            result = await _apiService.getUsers(token);
            break;
          case 'Customers':
            result = await _apiService.getCustomers(token);
            break;
          case 'Loans':
            result = await _apiService.getLoans(token: token); // Fetch all
            break;
          case 'Lines':
            result = await _apiService.getAllLines(token);
            break;
          case 'Collections':
             // History might be large, but it's what we have. 
             // Or getCollectionHistory which usually returns recent. 
             // Ideally we need a full dump but let's use what we have.
            result = await _apiService.getCollectionHistory(token);
            break;
          case 'DailySettlement':
            result = await _apiService.getDailySettlements(token);
            break;
            // For others, we might need new endpoints if they don't exist
            // Assuming for now we skip or add generic getter later
          default:
             // If no specific endpoint, clear
            result = [];
            break;
        }
        
        setState(() {
          _data = result;
          if (_data.isNotEmpty) {
            _columns = _data[0].keys.toList();
             // Simple suppression of complex objects if necessary, or just toString them
          } else {
            _columns = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Database Viewer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text("Select Table: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTable,
                        isExpanded: true,
                        items: _tables.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: GoogleFonts.outfit()),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedTable = newValue;
                            });
                            _fetchData();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _data.isEmpty 
                  ? Center(child: Text("No records found in $_selectedTable"))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                          columns: _columns.map((col) => DataColumn(
                            label: Text(
                              col.toUpperCase().replaceAll('_', ' '), 
                              style: const TextStyle(fontWeight: FontWeight.bold)
                            )
                          )).toList(),
                          rows: _data.map((row) {
                            return DataRow(
                              cells: _columns.map((col) {
                                var val = row[col] ?? '-';
                                return DataCell(Text(val.toString()));
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
