import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import 'services/language_service.dart';
import 'screens/auth/worker_login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/worker_qr_screen.dart';
import 'screens/admin/audit_logs_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/user_detail_screen.dart';
import 'screens/auth/face_verification_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin/master_settings_screen.dart';
import 'screens/admin/risk_prediction_screen.dart';
import 'screens/admin/security_compliance_screen.dart';
import 'screens/worker_dashboard.dart';
import 'screens/profile_screen.dart';
import 'screens/security_settings_screen.dart';
// import 'screens/face_enrollment_screen.dart'; // Removed
import 'screens/admin/admin_customer_list_screen.dart'; // Added import for AdminCustomerListScreen
import 'screens/admin/face_registration_screen.dart'; // Added import for FaceRegistrationScreen
import 'screens/collection_entry_screen.dart';
import 'screens/admin/manager_review_screen.dart';
import 'screens/admin/financial_analytics_screen.dart';
import 'screens/admin/performance_analytics_screen.dart';
import 'package:camera/camera.dart';
import 'screens/admin/manage_lines_screen.dart';
import 'screens/admin/line_customers_screen.dart';
import 'screens/agent_lines_screen.dart';
import 'screens/admin/loan_approval_screen.dart';
import 'screens/admin/customer_detail_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/collection_ledger_screen.dart';
import 'screens/agent/agent_performance_screen.dart';
import 'screens/agent/agent_collection_history_screen.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    cameras = [];
    debugPrint("Cameras not initialized: $e");
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const VasoolDriveApp(),
    ),
  );
}

class VasoolDriveApp extends StatelessWidget {
  const VasoolDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'Vasool Drive',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          locale: languageProvider.currentLocale,
          initialRoute: '/',
          routes: {
        '/': (context) => const WorkerLoginScreen(),
        '/pin_login': (context) => const WorkerLoginScreen(),
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/dashboard': (context) => const AdminDashboard(),
        '/admin/face_register': (context) {
           final args = ModalRoute.of(context)?.settings.arguments;
           if (args is Map<String, dynamic>) {
             return FaceRegistrationScreen(
               userId: args['user_id'],
               userName: args['name'],
               qrToken: args['qr_token'],
             );
           }
           return const Scaffold(body: Center(child: Text('Error: Missing arguments details')));
        },
        '/admin/worker_qr': (context) {
           final args = ModalRoute.of(context)?.settings.arguments;
           if (args is Map<String, dynamic>) {
             return WorkerQrScreen(
               userId: args['user_id'],
               name: args['name'],
               qrToken: args['qr_token'],
             );
           }
           return const Scaffold(body: Center(child: Text('Error: Missing worker details')));
        },
        '/admin/audit_logs': (context) => const AuditLogsScreen(),
        '/admin/user_management': (context) => const UserManagementScreen(),
        '/admin/user_detail': (context) {
           final args = ModalRoute.of(context)?.settings.arguments;
           if (args is Map<String, dynamic>) {
             return UserDetailScreen(userId: args['user_id']);
           }
           return const Scaffold(body: Center(child: Text('Error: Missing user ID')));
        },
        '/settings': (context) => const SettingsScreen(),
        '/home': (context) => const WorkerDashboard(),
        '/profile': (context) => const ProfileScreen(),
        '/security': (context) => const SecuritySettingsScreen(),
        // '/enroll_face': (context) => const FaceEnrollmentScreen(), // Removed invalid route
        '/collection_entry': (context) => const CollectionEntryScreen(),
        '/admin/review': (context) => const ManagerReviewScreen(),
        '/admin/financial_stats': (context) => const FinancialAnalyticsScreen(),
        '/admin/analytics': (context) => const PerformanceAnalyticsScreen(),
        '/admin/lines': (context) => const ManageLinesScreen(),
        '/admin/line_customers': (context) {
           final line = ModalRoute.of(context)?.settings.arguments;
           if (line is Map<String, dynamic>) {
             return LineCustomersScreen(line: line);
           }
           return const Scaffold(body: Center(child: Text('Error: Missing line details')));
        },
        '/agent/lines': (context) => const AgentLinesScreen(),
        '/admin/customers': (context) => const AdminCustomerListScreen(),
        '/admin/loan_approvals': (context) => const LoanApprovalScreen(),
        '/admin/pending_collections': (context) => const ManagerReviewScreen(),
        '/admin/reports': (context) => ReportsScreen(), 
        '/admin/collection_ledger': (context) => const CollectionLedgerScreen(),
        '/admin/master_settings': (context) => const MasterSettingsScreen(),
        '/admin/risk_prediction': (context) => const RiskPredictionScreen(),
        '/admin/security': (context) => const SecurityComplianceScreen(),
        '/worker/performance': (context) => const AgentPerformanceScreen(),
        '/agent/collections': (context) => const AgentCollectionHistoryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/admin/customer_detail') {
           final customerId = settings.arguments;
           if (customerId is int) {
             return MaterialPageRoute(builder: (context) => CustomerDetailScreen(customerId: customerId));
           }
           return MaterialPageRoute(builder: (context) => const Scaffold(body: Center(child: Text('Error: Missing customer ID'))));
        }
        if (settings.name == '/verify_face') {
           final userName = settings.arguments;
           if (userName is String) {
             return MaterialPageRoute(builder: (context) => FaceVerificationScreen(userName: userName));
           }
           return MaterialPageRoute(builder: (context) => const Scaffold(body: Center(child: Text('Error: Missing worker name'))));
        }
        return null; // Let the default routes handle other paths
      },
     );
    },
   );
  }
}
