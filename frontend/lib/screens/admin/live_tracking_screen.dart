import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _agents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    setState(() => _isLoading = true);
    final token = await _apiService.getToken();
    if (token != null) {
      final data = await _apiService.getFieldAgentsLocation(token);
      if (mounted) {
        setState(() {
          _agents = data;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openMap(double? lat, double? lng, String name) async {
    if (lat == null || lng == null) return;
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open Google Maps")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Live Field Tracking", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _fetchLocations, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _agents.isEmpty 
          ? const Center(child: Text("No agents found"))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _agents.length,
              itemBuilder: (context, index) {
                final agent = _agents[index];
                final status = agent['status'] ?? 'off_duty';
                final isOnDuty = status == 'on_duty';
                final lastUpdate = agent['last_update'] != null 
                    ? DateFormat('hh:mm a').format(DateTime.parse(agent['last_update']).toLocal())
                    : 'Never';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isOnDuty ? Colors.green[50] : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_pin_circle_rounded, 
                              color: isOnDuty ? Colors.green : Colors.grey,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(agent['name'] ?? 'Agent', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(agent['mobile'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOnDuty ? const Color(0xFFF1FCE4) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isOnDuty ? "ONLINE" : "OFFLINE",
                              style: TextStyle(
                                color: isOnDuty ? Colors.green[800] : Colors.grey[800],
                                fontSize: 10,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniInfo("Last Update", lastUpdate),
                          _buildMiniInfo("Activity", (agent['activity'] ?? 'idle').toString().toUpperCase()),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: agent['latitude'] != null
                                      ? () => _openMap(agent['latitude'], agent['longitude'], agent['name'])
                                      : null,
                                  icon: const Icon(Icons.map_rounded),
                                  label: Text(agent['latitude'] != null ? "VIEW ON MAP" : "GPS NOT READY"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo[900],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                                if (agent['latitude'] == null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      "Waiting for active sync...",
                                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
