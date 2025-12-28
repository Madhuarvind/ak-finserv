import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final token = await _apiService.getToken();
    if (token != null) {
      final result = await _apiService.getAuditLogs(token);
      setState(() {
        _logs = result;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'success') return Colors.green;
    if (status.startsWith('failed')) return Colors.red;
    return Colors.orange;
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'success': return context.translate('success');
      case 'failed_wrong_pin': return context.translate('invalid_pin');
      case 'failed_device_mismatch': return context.translate('device_bound'); // Using existing keys where appropriate
      case 'failed': return context.translate('failure');
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.translate('audit_logs'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetchLogs,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _logs.isEmpty
                  ? Center(
                      child: Text(
                        context.translate('no_logs'),
                        style: const TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final DateTime time = DateTime.parse(log['time']);
                        final String formattedTime = DateFormat('dd MMM • hh:mm a').format(time.toLocal());
                        final bool isSuccess = log['status'] == 'success';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSuccess ? const Color(0xFF1E1E1E) : AppTheme.errorColor.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            isThreeLine: true,
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _getStatusColor(log['status']).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSuccess ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                                color: _getStatusColor(log['status']),
                                size: 24,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    log['user_name'] ?? 'Unknown User',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  _getStatusLabel(log['status']).toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(log['status']), 
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.white24),
                                    const SizedBox(width: 4),
                                    Text(
                                      log['mobile'],
                                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.fingerprint_rounded, size: 14, color: Colors.white24),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        log['device'],
                                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
