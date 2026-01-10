import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/localizations.dart';
import '../utils/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/customer/customer_list_screen.dart';

class AppDrawer extends StatelessWidget {
  final String userName;
  final String role;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = role == 'admin';
    final ApiService apiService = ApiService();

    return Drawer(
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          // Profile Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isAdmin ? 'Administrator' : 'Field Agent',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more_rounded, color: AppTheme.secondaryTextColor, size: 20),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Colors.black12, height: 1),
          ),
          const SizedBox(height: 16),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: context.translate('home'),
                  isActive: true,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: context.translate('my_profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.security_rounded,
                  label: context.translate('security_hub'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/security');
                  },
                ),
                if (isAdmin) ...[
                  _buildDrawerItem(
                    context,
                    icon: Icons.check_circle_outline_rounded,
                    label: context.translate('loan_approvals'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/loan_approvals');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.content_paste_search_rounded,
                    label: context.translate('collection_ledger'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/collection_ledger');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.fact_check_rounded,
                    label: context.translate('collection_review'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/review');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outline_rounded,
                    label: context.translate('user_management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/user_management');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.contacts_outlined,
                    label: 'Customer Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/customers');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.route_outlined,
                    label: context.translate('line_management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/lines');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.psychology_outlined,
                    label: context.translate('risk_predictions'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/risk_prediction');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    label: context.translate('performance_analytics'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/analytics');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.account_balance_rounded,
                    label: context.translate('financial_analytics'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/financial_stats');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.shield_outlined,
                    label: context.translate('security_compliance'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/security');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.assignment_outlined,
                    label: context.translate('audit_logs'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/audit_logs');
                    },
                  ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.settings_suggest_rounded,
                      label: context.translate('system_configuration'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/admin/master_settings');
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.storage_rounded,
                      label: 'Database Viewer',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/admin/db_viewer');
                      },
                    ),
                ] else ...[
                  _buildDrawerItem(
                    context,
                    icon: Icons.assessment_outlined,
                    label: 'My AI Performance',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/worker/performance');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_rounded,
                    label: context.translate('collection_history'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/agent/collections');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outline_rounded,
                    label: 'Customer Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.route_outlined,
                    label: context.translate('daily_route'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/agent/lines');
                    },
                  ),
                ],
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: context.translate('settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
              ],
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildDrawerItem(
              context,
              icon: Icons.logout_rounded,
              label: context.translate('logout'),
              color: AppTheme.errorColor,
              onTap: () async {
                await apiService.clearAuth();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          icon, 
          color: isActive 
            ? Colors.black 
            : (color ?? AppTheme.secondaryTextColor)
        ),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
            color: isActive 
              ? Colors.black 
              : (color ?? AppTheme.textColor),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
