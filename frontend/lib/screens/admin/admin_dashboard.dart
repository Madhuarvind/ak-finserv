import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final token = await _apiService.getToken();
    if (token != null) {
      final result = await _apiService.getUsers(token);
      if (result is List) {
        setState(() {
          _users = result;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['msg'] ?? context.translate('failure'))),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Vasool Drive',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.security_rounded),
                onPressed: () => Navigator.pushNamed(context, '/admin/audit_logs'),
                tooltip: context.translate('audit_logs'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                tooltip: context.translate('settings'),
              ),
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : Column(
                children: [
                  // Premium Summary Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Portfolio Value',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹12,45,690', // Static for now, can be linked to API later
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.trending_up_rounded, size: 16, color: AppTheme.primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+12.5%',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'vs last month',
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Users List Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.translate('dashboard'),
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                          onPressed: _fetchUsers,
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        bool isBound = user['has_device_bound'] ?? false;
                        bool isLocked = user['is_locked'] ?? false;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF1E1E1E), width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: user['role'] == 'admin' 
                                  ? Colors.purple.withOpacity(0.1) 
                                  : AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                user['role'] == 'admin' ? Icons.shield_rounded : Icons.person_rounded,
                                color: user['role'] == 'admin' ? Colors.purple : AppTheme.primaryColor,
                              ),
                            ),
                            title: Text(
                              user['name'] ?? user['mobile_number'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${user['area'] ?? context.translate('no_area')} • ${user['mobile_number']}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isBound) 
                                  const Icon(Icons.phonelink_lock_rounded, color: AppTheme.primaryColor, size: 20),
                                if (isLocked)
                                  const Icon(Icons.lock_outline_rounded, color: AppTheme.errorColor, size: 20),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.white30),
                                  onPressed: () => _handleResetDevice(user['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.black,
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/admin/add_agent');
              if (result == true) {
                _fetchUsers();
              }
            },
            label: Text(context.translate('add_worker'), style: const TextStyle(fontWeight: FontWeight.w900)),
            icon: const Icon(Icons.person_add_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  Future<void> _handleResetDevice(int userId) async {
    final token = await _apiService.getToken();
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('reset_confirm_title')),
        content: Text(context.translate('reset_confirm_content')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(context.translate('save'), style: const TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _apiService.resetDevice(userId, token);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['msg'] ?? context.translate('success'))),
      );
      _fetchUsers();
    }
  }
}
