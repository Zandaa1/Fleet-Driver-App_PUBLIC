import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _cameraGranted = false;
  bool _batteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final location = await Permission.locationAlways.isGranted;
    final notification = await Permission.notification.isGranted;
    final camera = await Permission.camera.isGranted;

    // Battery optimization check is Android-only
    bool battery = true;
    if (Platform.isAndroid) {
      battery = await Permission.ignoreBatteryOptimizations.isGranted;
    }

    if (mounted) {
      setState(() {
        _locationGranted = location;
        _notificationGranted = notification;
        _cameraGranted = camera;
        _batteryOptimizationIgnored = battery;
      });
    }
  }

  bool get _allMandatoryGranted =>
      _locationGranted && _notificationGranted && _cameraGranted;

  Future<void> _showSettingsDialog(String title) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title Permission Required'),
        content: Text(
          'You have denied this permission twice. Android will not ask again. Please enable it in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRequest(Permission permission, String title) async {
    final status = await permission.status;
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(title);
      return;
    }

    final result = await permission.request();
    if (result.isPermanentlyDenied) {
      await _showSettingsDialog(title);
    }
    _checkPermissions();
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onGrant,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isGranted
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Icon(icon, color: isGranted ? Colors.green : Colors.orange),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(onPressed: onGrant, child: const Text('Grant')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Permissions Required',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'To provide reliable tracking and trip management, we need the following permissions:',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionItem(
                      icon: Icons.location_on,
                      title: 'Location (Always)',
                      description:
                          'Needed to track your trip and calculate earnings even when the app is in the background.',
                      isGranted: _locationGranted,
                      onGrant: () async {
                        final status = await Permission.locationAlways.status;
                        if (status.isPermanentlyDenied) {
                          await _showSettingsDialog('Location');
                          return;
                        }
                        await Permission.locationWhenInUse.request();
                        final result = await Permission.locationAlways.request();
                        if (result.isPermanentlyDenied) {
                          await _showSettingsDialog('Location');
                        }
                        _checkPermissions();
                      },
                    ),
                    _buildPermissionItem(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      description:
                          'Stay updated on new trip assignments and important ride alerts.',
                      isGranted: _notificationGranted,
                      onGrant: () => _handleRequest(Permission.notification, 'Notifications'),
                    ),
                    _buildPermissionItem(
                      icon: Icons.camera_alt,
                      title: 'Camera',
                      description:
                          'Required for capturing fuel receipts and reporting incidents.',
                      isGranted: _cameraGranted,
                      onGrant: () => _handleRequest(Permission.camera, 'Camera'),
                    ),
                    if (Platform.isAndroid)
                      _buildPermissionItem(
                        icon: Icons.battery_saver,
                        title: 'Battery Optimization',
                        description:
                            'Disable optimization to prevent the system from stopping GPS tracking during long trips.',
                        isGranted: _batteryOptimizationIgnored,
                        onGrant: () => _handleRequest(Permission.ignoreBatteryOptimizations, 'Battery'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _allMandatoryGranted
                      ? () => Navigator.pushReplacementNamed(context, '/')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allMandatoryGranted
                        ? theme.primaryColor
                        : Colors.grey.shade300,
                    foregroundColor: _allMandatoryGranted
                        ? Colors.white
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue to Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
