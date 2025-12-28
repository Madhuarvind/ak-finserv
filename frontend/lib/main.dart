import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import 'services/language_service.dart';
import 'screens/auth/worker_login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/add_agent_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/face_registration_screen.dart';
import 'screens/admin/worker_qr_screen.dart';
import 'screens/admin/audit_logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/worker_dashboard.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    cameras = [];
    print("Cameras not initialized: $e");
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
          theme: AppTheme.darkTheme,
          locale: languageProvider.currentLocale,
          initialRoute: '/',
          routes: {
        '/': (context) => const WorkerLoginScreen(),
        '/pin_login': (context) => const WorkerLoginScreen(),
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/dashboard': (context) => const AdminDashboard(),
        '/admin/face_register': (context) {
           final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
           return FaceRegistrationScreen(
             userId: args['user_id'],
             userName: args['name'],
             qrToken: args['qr_token'],
           );
        },
        '/admin/worker_qr': (context) {
           final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
           return WorkerQrScreen(
             userId: args['user_id'],
             name: args['name'],
             qrToken: args['qr_token'],
           );
        },
        '/admin/add_agent': (context) => const AddAgentScreen(),
        '/admin/audit_logs': (context) => const AuditLogsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/home': (context) => const WorkerDashboard(),
      },
     );
    },
   );
  }
}
