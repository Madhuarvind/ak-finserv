import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _biometricsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Security Hub",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Authentication",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Manage how you access your account",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 32),
            
            // Biometric Toggle Card
            _buildToggleCard(
              "Biometric Login",
              "Face or Fingerprint unlock",
              Icons.fingerprint,
              _biometricsEnabled,
              (val) => setState(() => _biometricsEnabled = val),
              const Color(0xFFEFF6FF),
              const Color(0xFF3B82F6),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              "Account Protection",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Security layers for your profile",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            

            
            // Device Management Card
            _buildActionCard(
              "Change Login PIN",
              "Last changed 30 days ago",
              Icons.password_rounded,
              const Color(0xFFF5F3FF),
              const Color(0xFF8B5CF6),
              () => _showChangePinDialog(context)
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              "Device Management",
              "2 active sessions",
              Icons.devices,
              const Color(0xFFECFDF5),
              const Color(0xFF10B981),
              () => _showDeviceManagement(context)
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Change PIN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Old PIN", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New PIN", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Confirm PIN", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (newPinCtrl.text != confirmPinCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PINs do not match")));
                return;
              }
              // Implement API call here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN updated successfully")));
            },
            child: const Text("UPDATE"),
          ),
        ],
      ),
    );
  }

  void _showDeviceManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Active Sessions", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDeviceTile("This Device", "Windows 11 • Online", Icons.laptop_windows, true),
            _buildDeviceTile("Mobile Device", "Android 13 • Last active: 2h ago", Icons.smartphone, false),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context),
                child: const Text("Logout from all devices"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(String title, String subtitle, IconData icon, bool isCurrent) {
    return ListTile(
      leading: Icon(icon, color: isCurrent ? Colors.green : Colors.grey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: isCurrent ? const Chip(label: Text("Current", style: TextStyle(fontSize: 10)), backgroundColor: Color(0xFFF1FCE4)) : null,
    );
  }

  Widget _buildToggleCard(
    String title, 
    String subtitle, 
    IconData icon, 
    bool value, 
    ValueChanged<bool> onChanged,
    Color iconBg,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.all(const Color(0xFFB4F23E)),
            activeTrackColor: const Color(0xFFB4F23E).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title, 
    String subtitle, 
    IconData icon, 
    Color iconBg, 
    Color iconColor,
    VoidCallback onTap
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black, size: 20),
          ],
        ),
      ),
    );
  }
}
