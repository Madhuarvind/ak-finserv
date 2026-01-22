import 'dart:async';
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
import 'common/qr_scan_screen.dart';
import 'package:geolocator/geolocator.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _userName;
  String? _role;
  Map<String, dynamic> _stats = {"collected": 0.0, "goal": 50000.0};
  List<dynamic> _history = [];
  bool _isLoading = true;
  Timer? _trackingTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startTrackingTimer();
    // Immediate sync on load to enable "View on Map" for Admin quickly
    _syncLocation();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  void _startTrackingTimer() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final now = DateTime.now();
      
      // -- SESSION LOGIC --
      // Morning: 06:00 to 15:00 (3pm)
      // Evening: 16:00 to 23:00 (11pm)
      bool isInMorningSession = now.hour >= 6 && now.hour < 15;
      bool isInEveningSession = now.hour >= 16 && now.hour < 23;
      
      final name = await _storage.read(key: 'user_name');
      String? dutyStatus = await _storage.read(key: 'duty_status_$name');
      
      // Auto-logic: If in session, we FORCE sync even if they didn't manually toggle.
      // If NOT in session, only sync if they explicitly stayed on_duty.
      if (isInMorningSession || isInEveningSession || dutyStatus == 'on_duty') {
        _syncLocation();
      }
    });
  }

  Future<void> _syncLocation() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    try {
      // Check for permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      // Use LocationAccuracy.high for "Proper Location" accuracy
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, 
          timeLimit: Duration(seconds: 15)
        )
      );
      
      await _apiService.updateWorkerTracking(
        token: token,
        latitude: pos.latitude,
        longitude: pos.longitude,
        activity: 'live_tracking',
      );
    } catch (e) {
      debugPrint("Location sync failed: $e");
    }
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
          key: _scaffoldKey,
          extendBodyBehindAppBar: true,
          drawer: AppDrawer(
            userName: _userName ?? 'User',
            role: _role ?? 'field_agent',
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: InkWell(
              onTap: () {}, 
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.translate('search_collections'),
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  color: AppTheme.primaryColor,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Premium Performance Hub (Dark Premium Aesthetic)
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  // Decorative Accent
                                  Positioned(
                                    right: -40,
                                    top: -40,
                                    child: Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            AppTheme.primaryColor.withValues(alpha: 0.15),
                                            AppTheme.primaryColor.withValues(alpha: 0),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(28.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context.translate('my_total_collection'),
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '₹${_stats['collected']}',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 38,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    letterSpacing: -1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                                              ),
                                              child: const Icon(Icons.flash_on_rounded, color: AppTheme.primaryColor, size: 28),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildCompactInfo(
                                                '${context.translate('goal')}: ₹${_stats['goal']}', 
                                                Colors.white.withValues(alpha: 0.05), 
                                                Colors.white.withValues(alpha: 0.9)
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor,
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  )
                                                ]
                                              ),
                                              child: Text(
                                                '${((_stats['collected'] / _stats['goal']) * 100).toStringAsFixed(1)}%', 
                                                style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                                              ),
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
                                Expanded(
                                  child: Text(
                                    context.translate('quick_actions'),
                                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.swipe_left_rounded, size: 16, color: Colors.white54),
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
                                _buildModernActionTile(context, context.translate('my_stats'), Icons.assessment_outlined, '/worker/performance', Colors.cyan),
                                const SizedBox(width: 16),
                                _buildModernActionTile(context, context.translate('users'), Icons.people_outline_rounded, '', Colors.teal, isCustom: true, onTap: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                                }),
                                const SizedBox(width: 16),
                                _buildModernActionTile(context, context.translate('collection_history'), Icons.history_rounded, '/agent/collections', Colors.blueGrey),
                                const SizedBox(width: 16),
                                _buildModernActionTile(context, context.translate('daily_route'), Icons.map_outlined, '/agent/lines', Colors.purple),
                                const SizedBox(width: 16),
                                _buildModernActionTile(context, context.translate('qr_scan'), Icons.qr_code_scanner_rounded, '', Colors.orange, isCustom: true, onTap: () async {
                                   final result = await Navigator.push(
                                     context,
                                     MaterialPageRoute(builder: (context) => const QRScanScreen()),
                                   );
                                   if (result != null) {
                                      if (!context.mounted) return;
                                      
                                       final resStr = result.toString().trim();
                                       // Detect Digital Passbook (Unified ID or UUID)
                                       final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
                                       
                                       if (uuidRegex.hasMatch(resStr) || resStr.startsWith('CUST-')) {
                                          Navigator.pushNamed(context, '/public/passbook', arguments: resStr);
                                          return;
                                       }
                                      
                                       // Show processing for regular customer QR
                                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Identifying Customer...")));
                                       
                                       final customerData = await _apiService.getCustomerByQr(resStr);
                                      
                                      if (!context.mounted) return;
                                      
                                       if (customerData['msg'] == 'not_found' || customerData['id'] == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Customer not found!"), backgroundColor: Colors.red));
                                       } else if (customerData['id'] != null) {
                                         // Navigate to Collection Entry for this customer
                                         Navigator.pushNamed(
                                           context, 
                                           '/collection_entry',
                                           arguments: {
                                             'customer_id': customerData['id'],
                                             'customer_name': customerData['name'],
                                             'customer_uid': customerData['customer_id']
                                           }
                                         );
                                      } else {
                                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error reading QR"), backgroundColor: Colors.red));
                                      }
                                   }
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
                                Expanded(
                                  child: Text(
                                    context.translate('recent_activity'),
                                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.translate('track_all'),
                                  style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13), // Reduced fontSize slightly
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
                                    Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 48),
                                    const SizedBox(height: 16),
                                    Text(context.translate('no_recent_collections'), style: GoogleFonts.outfit(color: Colors.white38)),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._history.whereType<Map>().map((item) {
                              final mapItem = item as Map<String, dynamic>;
                              String status = (mapItem['status'] ?? 'pending').toString().toLowerCase();
                              Color statusColor = status == 'approved' ? Colors.greenAccent : (status == 'pending' ? Colors.orangeAccent : Colors.redAccent);
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_outlined,
                                      color: statusColor,
                                    ),
                                  ),
                                  title: Text(
                                    mapItem['customer_name']?.toString() ?? 'Unknown Customer',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '${(mapItem['payment_mode'] ?? 'cash').toString().toUpperCase()} • ${status.toUpperCase()}',
                                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${mapItem['amount'] ?? 0}',
                                        style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        context.translate('recently'),
                                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
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
        border: Border.all(color: text.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(color: text, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final collected = double.tryParse(_stats['today_collected']?.toString() ?? _stats['collected']?.toString() ?? '0') ?? 0;
    final goal = double.tryParse(_stats['goal']?.toString() ?? '50000') ?? 50000;
    final progress = (goal > 0 ? (collected / goal) : 0.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "My Today's Collection", // Changed Title
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.flash_on_rounded, color: AppTheme.primaryColor),
              )
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "₹${collected.toStringAsFixed(0)}",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionTile(BuildContext context, String title, IconData icon, String route, Color themeColor, {bool isCustom = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: isCustom ? onTap : () => Navigator.pushNamed(context, route).then((_) => _loadAllData()),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white),
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
