import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_drawer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'customer/customer_list_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  String? _userName;
  String? _role;
  Map<String, dynamic> _stats = {"collected": 0.0, "goal": 50000.0};
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final name = await _storage.read(key: 'user_name');
    final role = await _storage.read(key: 'user_role');
    final token = await _storage.read(key: 'jwt_token');
    
    if (token != null) {
      final statsData = await _apiService.getAgentStats(token);
      final historyData = await _apiService.getCollectionHistory(token);
      
      if (mounted) {
        setState(() {
          _userName = name;
          _role = role;
          if (statsData['msg'] != 'connection_failed' && statsData['msg'] != 'server_error') {
            _stats = statsData;
          }
          _history = historyData;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _userName = name;
          _role = role;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          drawer: AppDrawer(
            userName: _userName ?? 'User',
            role: _role ?? 'field_agent',
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: AppTheme.secondaryTextColor.withValues(alpha: 0.5), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Search collections...',
                          style: TextStyle(color: AppTheme.secondaryTextColor.withValues(alpha: 0.5), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Performance Card (Like Admin Balance Card)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, Color(0xFFD4FF8B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Opacity(
                                  opacity: 0.1,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'My Total Collection',
                                          style: GoogleFonts.outfit(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Icon(Icons.trending_up_rounded, color: Colors.black, size: 28),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      '₹${_stats['collected']}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildCompactInfo('Goal: ₹${_stats['goal']}', Colors.white, Colors.black),
                                        const SizedBox(width: 12),
                                        _buildCompactInfo(
                                          '${((_stats['collected'] / _stats['goal']) * 100).toStringAsFixed(1)}%', 
                                          Colors.black, 
                                          Colors.white
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.translate('quick_actions'),
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                            ),
                            Icon(Icons.swipe_left_rounded, size: 16, color: AppTheme.secondaryTextColor.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Horizontal Quick Actions (Like Admin)
                      SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            _buildModernActionTile(context, context.translate('collection'), Icons.add_circle_outline_rounded, '/collection_entry', Colors.green),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, "My Stats", Icons.assessment_outlined, '/worker/performance', Colors.cyan),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, 'Customers', Icons.people_outline_rounded, '', Colors.teal, isCustom: true, onTap: () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                            }),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, "History", Icons.history_rounded, '/agent/collections', Colors.blueGrey),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, context.translate('daily_route'), Icons.map_outlined, '/agent/lines', Colors.purple),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, context.translate('qr_scan'), Icons.qr_code_scanner_rounded, '', Colors.orange, isCustom: true, onTap: () {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR Scanner starting...")));
                            }),
                            const SizedBox(width: 16),
                            _buildModernActionTile(context, context.translate('security_hub'), Icons.security_outlined, '/security', Colors.indigo),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.translate('recent_activity'),
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                            ),
                            Text(
                              'Track All',
                              style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      
                      // Premium Recent History (Like Admin)
                      if (_history.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.history_toggle_off_rounded, color: Colors.grey[300], size: 48),
                                const SizedBox(height: 16),
                                Text("No recent collections", style: TextStyle(color: Colors.grey[400])),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._history.whereType<Map>().map((item) {
                          final mapItem = item as Map<String, dynamic>;
                          String status = (mapItem['status'] ?? 'pending').toString().toLowerCase();
                          Color statusColor = status == 'approved' ? Colors.green : (status == 'pending' ? Colors.orange : Colors.red);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  color: statusColor,
                                ),
                              ),
                              title: Text(
                                mapItem['customer_name']?.toString() ?? 'Unknown Customer',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                '${(mapItem['payment_mode'] ?? 'cash').toString().toUpperCase()} • ${status.toUpperCase()}',
                                style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${mapItem['amount'] ?? 0}',
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Recently',
                                    style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _buildCompactInfo(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildModernActionTile(BuildContext context, String title, IconData icon, String route, Color themeColor, {bool isCustom = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: isCustom ? onTap : () => Navigator.pushNamed(context, route).then((_) => _loadAllData()),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: themeColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
