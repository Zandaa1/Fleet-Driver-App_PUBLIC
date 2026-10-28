import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pre_ride_screen.dart';
import 'screens/pre_ride_checkpoints_screen.dart';
import 'screens/active_ride_screen.dart';
import 'screens/delivery_checkpoints_screen.dart';
import 'screens/post_ride_screen.dart';
import 'screens/fuel_receipt_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/admin_tools_screen.dart';
import 'screens/add_toll_screen.dart';
import 'screens/report_incident_screen.dart';
import 'screens/permissions_screen.dart';
import 'services/background_service.dart';
import 'services/notification_test_service.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'utils/app_theme.dart';

final apiService = ApiService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline sync service
  await offlineSyncService.initialize();

  // Initialize local notification channels first.
  await NotificationTestService.initialize();

  // Initialize background service
  await BackgroundService.initializeService();

  // Load saved token for persistence
  await apiService.loadSavedToken();

  // Check if mandatory permissions are granted
  bool hasLocation = await Permission.locationAlways.isGranted;
  bool hasNotification = await Permission.notification.isGranted;
  bool hasCamera = await Permission.camera.isGranted;
  
  bool needsPermissions = !hasLocation || !hasNotification || !hasCamera;

  runApp(FleetDriverApp(needsPermissions: needsPermissions));
}

/// Global theme-mode notifier — readable/writable from any screen.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class FleetDriverApp extends StatelessWidget {
  final bool needsPermissions;
  const FleetDriverApp({super.key, required this.needsPermissions});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Fleet Driver App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,

          // Routes
          initialRoute: needsPermissions 
              ? '/permissions' 
              : (apiService.token == null ? '/' : '/dashboard'),
          routes: {
            '/permissions': (context) => const PermissionsScreen(),
            '/': (context) => const LoginScreen(),
            '/dashboard': (context) =>
                DashboardScreen(key: DashboardScreen.dashboardKey),
            '/pre-ride': (context) => const PreRideScreen(),
            '/pre-ride-checkpoints': (context) =>
                const PreRideCheckpointsScreen(),
            '/active-ride': (context) => const ActiveRideScreen(),
            '/delivery-checkpoints': (context) =>
                const DeliveryCheckpointsScreen(),
            '/post-ride': (context) => const PostRideScreen(),
            '/fuel-receipt': (context) => const FuelReceiptScreen(),
            '/chat': (context) => const ChatScreen(),
            '/admin-tools': (context) => const AdminToolsScreen(),
            '/add-toll': (context) => const AddTollScreen(),
            '/report-incident': (context) => const ReportIncidentScreen(),
          },
        );
      },
    );
  }
}
