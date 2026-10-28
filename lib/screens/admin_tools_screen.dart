import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/background_service.dart';
import '../services/mock_backend_service.dart';
import '../services/notification_test_service.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  static const MethodChannel _deviceInfoChannel = MethodChannel(
    'fleet_driver/device_info',
  );

  bool _serviceEnabled = false;
  LocationPermission? _permission;
  Position? _currentPosition;
  String? _error;
  bool _isStreaming = false;
  bool _isStreamingLiveUpdate = false;
  bool _isMockActiveRideNotificationRunning = false;
  Map<String, Object?> _activeRideState = const <String, Object?>{};
  StreamSubscription<Position>? _positionSubscription;
  String? _deviceId;
  String? _deviceModel;
  bool _isOfflineModeTestEnabled = false;
  bool _isOfflineUiTestModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _isOfflineModeTestEnabled = ApiService.offlineTestModeEnabled;
    _isOfflineUiTestModeEnabled = ApiService.offlineUiTestModeEnabled;
    _refreshStatus();
    _refreshActiveRideState();
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    if (!mounted) {
      return;
    }

    setState(() {
      _serviceEnabled = serviceEnabled;
      _permission = permission;
    });
  }

  Future<void> _refreshActiveRideState() async {
    final activeRide = await MockBackendService.getActiveRide();
    if (!mounted) {
      return;
    }
    setState(() {
      _activeRideState = activeRide;
      _isMockActiveRideNotificationRunning = activeRide['isActive'] == true;
    });
  }

  Future<void> _loadDeviceInfo() async {
    final deviceId = await apiService.getDeviceId();
    final deviceInfo = DeviceInfoPlugin();
    String? deviceModel;

    try {
      if (kIsWeb) {
        deviceModel = 'Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
      } else {
        final info = await deviceInfo.deviceInfo;
        deviceModel = info.data['model']?.toString();
      }
    } catch (_) {
      deviceModel = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _deviceId = deviceId;
      _deviceModel = deviceModel;
    });
  }

  Future<void> _showDeviceIdSpoofingDialog() async {
    final controller = TextEditingController(text: ApiService.spoofedDeviceId);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spoof Device ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a custom Device ID to override the hardware ID. Leave empty to reset to default.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Spoofed Device ID',
                hintText: 'e.g. CUSTOM-DEVICE-001',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newId = result.isEmpty ? null : result;
      await ApiService.setSpoofedDeviceId(newId);
      await _loadDeviceInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newId == null
                  ? 'Device ID spoofing reset to hardware ID'
                  : 'Device ID spoofed to: $newId',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showDeviceMismatchDialog() async {
    final deviceId = _deviceId ?? 'Unknown';
    final deviceModel = _deviceModel ?? 'Unknown';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Mismatch Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This account is locked to a different device. Please contact the admin to update the registered device.',
            ),
            const SizedBox(height: 12),
            Text('Device model: $deviceModel'),
            const SizedBox(height: 4),
            Text('Device ID: $deviceId'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Contact Admin'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission() async {
    final permission = await Geolocator.requestPermission();

    if (!mounted) {
      return;
    }

    setState(() {
      _permission = permission;
      _error = null;
    });
  }

  Future<void> _getCurrentPosition() async {
    setState(() {
      _error = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _serviceEnabled = false;
        _error = 'Location services are disabled.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _permission = permission;
        _error = 'Location permission is not granted.';
      });
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _serviceEnabled = true;
      _permission = permission;
      _currentPosition = position;
    });
  }

  Future<void> _startStreaming() async {
    setState(() {
      _error = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _serviceEnabled = false;
        _error = 'Location services are disabled.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _permission = permission;
        _error = 'Location permission is not granted.';
      });
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (position) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentPosition = position;
            });
            if (_isStreamingLiveUpdate ||
                _isMockActiveRideNotificationRunning) {
              final destination = _isMockActiveRideNotificationRunning
                  ? 'Demo Warehouse'
                  : 'Demo Destination';
              final destinationLat = _isMockActiveRideNotificationRunning
                  ? 0.001
                  : 0.001;
              final destinationLng = _isMockActiveRideNotificationRunning
                  ? 0.001
                  : 0.001;
              final routeDistance = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                destinationLat,
                destinationLng,
              );
              NotificationTestService.sendLiveUpdateNotification(
                distanceMeters: routeDistance,
                destination: destination,
                currentLat: position.latitude,
                currentLng: position.longitude,
              );
            }
            if (_isMockActiveRideNotificationRunning) {
              BackgroundService.sendLocationUpdate(
                lat: position.latitude,
                lng: position.longitude,
                accuracyMeters: position.accuracy,
                at: DateTime.now(),
              );
              unawaited(
                MockBackendService.setActiveRide(
                  isActive: true,
                  updatedBy: 'admin_tools_mock',
                  tripId: 'mock-admin-ride',
                  destinationName: 'Demo Warehouse',
                  destinationLat: 0.001,
                  destinationLng: 0.001,
                ),
              );
              unawaited(
                MockBackendService.addLocationPing(
                  LocationPing(
                    lat: position.latitude,
                    lng: position.longitude,
                    accuracyMeters: position.accuracy,
                    at: DateTime.now(),
                  ),
                ),
              );
              unawaited(_refreshActiveRideState());
            }
          },
          onError: (error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _error = error.toString();
            });
          },
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _serviceEnabled = true;
      _permission = permission;
      _isStreaming = true;
    });
  }

  Future<void> _stopStreaming() async {
    await _positionSubscription?.cancel();
    await NotificationTestService.cancelLiveUpdateNotification();

    if (!mounted) {
      return;
    }

    setState(() {
      _isStreaming = false;
      _isStreamingLiveUpdate = false;
    });
  }

  Future<void> _startLiveUpdateTest() async {
    setState(() {
      _isStreamingLiveUpdate = true;
    });
    if (!_isStreaming) {
      await _startStreaming();
    }
  }

  Future<void> _stopLiveUpdateTest() async {
    setState(() {
      _isStreamingLiveUpdate = false;
    });
    await NotificationTestService.cancelLiveUpdateNotification();
    if (_isStreaming) {
      await _stopStreaming();
    }
  }

  Future<void> _sendTestTripNotification() async {
    final testTripDate = DateTime.now().add(const Duration(days: 1));
    const testDestination = 'Demo Warehouse';

    await NotificationTestService.sendTripAssignedNotification(
      tripDate: testTripDate,
      destination: testDestination,
      truckNumber: 'TRK-2025',
      tripCode: 'TEST-TRIP-001',
      eta: '12:00 PM',
      testMode: true,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Improved test trip notification sent')),
    );
  }

  Future<void> _showDeviceInfoDialog() async {
    final deviceInfo = DeviceInfoPlugin();
    String details = '';
    Map<String, dynamic> data = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final ssaid = await _getNativeAndroidId();

        data = {
          'REAL UNIQUE ANDROID ID (SSAID)': ssaid ?? 'Unavailable',
          'Fingerprint (Hardware Unique)': androidInfo.fingerprint,
          'Manufacturer': androidInfo.manufacturer,
          'Model': androidInfo.model,
          'Build ID (What you saw before)': androidInfo.id,
        };
        // Adding everything for debugging
        data.addAll({
          'Manufacturer': androidInfo.manufacturer,
          'Brand': androidInfo.brand,
          'Device': androidInfo.device,
          'Hardware': androidInfo.hardware,
          'Board': androidInfo.board,
          'Bootloader': androidInfo.bootloader,
          'Display': androidInfo.display,
          'Fingerprint': androidInfo.fingerprint,
          'Host': androidInfo.host,
          'Product': androidInfo.product,
          'Tags': androidInfo.tags,
          'Type': androidInfo.type,
          'Base OS': androidInfo.version.baseOS,
          'SDK Int': androidInfo.version.sdkInt,
          'Release': androidInfo.version.release,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        data = {
          'Name': iosInfo.name,
          'System Name': iosInfo.systemName,
          'System Version': iosInfo.systemVersion,
          'Model': iosInfo.model,
          'Localized Model': iosInfo.localizedModel,
          'Identifier For Vendor': iosInfo.identifierForVendor,
          'Is Physical Device': iosInfo.isPhysicalDevice,
        };
      } else {
        final info = await deviceInfo.deviceInfo;
        data = info.data;
      }

      details = data.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    } catch (e) {
      details = 'Error fetching device info: $e';
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Information'),
        content: SingleChildScrollView(
          child: SelectableText(
            details,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<String?> _getNativeAndroidId() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final value = await _deviceInfoChannel.invokeMethod<String>(
        'getAndroidId',
      );
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _startMockActiveRideNotification() async {
    const destinationLat = 0.001;
    const destinationLng = 0.001;
    const destinationName = 'Demo Warehouse';

    final started = await BackgroundService.startService();
    if (!started) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start active ride mock notification'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    BackgroundService.sendDestination(
      destinationLat,
      destinationLng,
      destinationName,
      'admin-test',
    );
    await NotificationTestService.sendRideStartedNotification(
      destination: destinationName,
    );
    await MockBackendService.setActiveRide(
      isActive: true,
      updatedBy: 'admin_tools_mock',
      tripId: 'mock-admin-ride',
      destinationName: destinationName,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isMockActiveRideNotificationRunning = true;
    });
    await _startStreaming();
    await _refreshActiveRideState();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Active ride mock notification started (tracking to Demo Warehouse)',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _stopMockActiveRideNotification() async {
    final stopped = await BackgroundService.stopService();
    await NotificationTestService.cancelLiveUpdateNotification();
    await MockBackendService.setActiveRide(
      isActive: false,
      updatedBy: 'admin_tools_mock',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isMockActiveRideNotificationRunning = false;
    });
    await _refreshActiveRideState();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stopped
              ? 'Active ride mock notification stopped'
              : 'No active ride mock notification was running',
        ),
      ),
    );
  }

  void _toggleOfflineModeTest(bool enabled) {
    ApiService.setOfflineTestModeEnabled(enabled);
    if (!enabled && _isOfflineUiTestModeEnabled) {
      ApiService.setOfflineUiTestModeEnabled(false);
    }
    setState(() {
      _isOfflineModeTestEnabled = enabled;
      if (!enabled) {
        _isOfflineUiTestModeEnabled = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Offline mode test enabled: API requests will fail as offline.'
              : 'Offline mode test disabled: API requests will use real network.',
        ),
      ),
    );
  }

  void _toggleOfflineUiTestMode(bool enabled) {
    if (!_isOfflineModeTestEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable Offline Mode Test first before UI-only mode.'),
        ),
      );
      return;
    }

    ApiService.setOfflineUiTestModeEnabled(enabled);
    setState(() {
      _isOfflineUiTestModeEnabled = enabled;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Offline UI test enabled: fake data active and login auth bypassed.'
              : 'Offline UI test disabled: Offline mode will block API requests.',
        ),
      ),
    );
  }

  String _activeRideSummary() {
    if (_activeRideState.isEmpty || _activeRideState['isActive'] != true) {
      return 'No active ride in mock backend';
    }

    final destination =
        (_activeRideState['destinationName'] as String?) ??
        'Unknown destination';
    final lat = (_activeRideState['lastLat'] as num?)?.toDouble();
    final lng = (_activeRideState['lastLng'] as num?)?.toDouble();
    final updatedAtRaw = _activeRideState['lastUpdatedAt'] as String?;
    final updatedAt = updatedAtRaw == null
        ? null
        : DateTime.tryParse(updatedAtRaw);
    final updatedBy = (_activeRideState['updatedBy'] as String?) ?? 'unknown';

    final locationText = (lat == null || lng == null)
        ? 'Last location: waiting for first GPS ping'
        : 'Last location: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    final timeText = updatedAt == null
        ? 'Updated: --'
        : 'Updated: ${DateFormat('hh:mm:ss a').format(updatedAt.toLocal())}';

    return 'Active mock ride → $destination\n$locationText\n$timeText\nSource: $updatedBy';
  }

  String _permissionLabel(LocationPermission? permission) {
    switch (permission) {
      case LocationPermission.always:
        return 'Always';
      case LocationPermission.whileInUse:
        return 'While in use';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Denied forever';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine';
      default:
        return 'Unknown';
    }
  }

  String _positionLabel(Position? position) {
    if (position == null) {
      return 'No location yet';
    }

    return 'Lat ${position.latitude.toStringAsFixed(6)}, '
        'Lng ${position.longitude.toStringAsFixed(6)}\n'
        'Accuracy ${position.accuracy.toStringAsFixed(1)} m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final permissionLabel = _permissionLabel(_permission);
    final positionLabel = _positionLabel(_currentPosition);
    final isDeniedForever = _permission == LocationPermission.deniedForever;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'GPS Test Console',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Admin only: use this screen to verify geolocator behavior.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: SwitchListTile(
                title: const Text('Offline Mode Test'),
                subtitle: const Text(
                  'Force API calls to behave like there is no internet connection.',
                ),
                value: _isOfflineModeTestEnabled,
                onChanged: _toggleOfflineModeTest,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                title: const Text('Offline UI Test Only'),
                subtitle: const Text(
                  'Use fake UI data and bypass login while allowing requests to proceed.',
                ),
                value: _isOfflineUiTestModeEnabled,
                onChanged: _isOfflineModeTestEnabled
                    ? _toggleOfflineUiTestMode
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Service enabled: ${_serviceEnabled ? 'Yes' : 'No'}'),
                    const SizedBox(height: 8),
                    Text('Permission: $permissionLabel'),
                    const SizedBox(height: 12),
                    Text('Last position: $positionLabel'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Effective Device ID: ${_deviceId ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (ApiService.spoofedDeviceId != null)
                                Text(
                                  ' (Spoofed)',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.security),
              label: const Text('Request Permission'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _getCurrentPosition,
              icon: const Icon(Icons.my_location),
              label: const Text('Get Current Position'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isStreaming ? null : _startStreaming,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Live Updates'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isStreaming ? _stopStreaming : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Live Updates'),
            ),
            const SizedBox(height: 12),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Extra Button Tests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'This simulates the device mismatch error that occurs when a driver tries to log in on a different device than the one registered to their account.',
            ),
            OutlinedButton.icon(
              onPressed: _showDeviceMismatchDialog,
              icon: const Icon(Icons.phonelink_erase),
              label: const Text('Simulate Device Mismatch'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showDeviceIdSpoofingDialog,
              icon: const Icon(Icons.vpn_key_rounded),
              label: const Text('Spoof Device ID'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sendTestTripNotification,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Send Test Trip Notification'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showDeviceInfoDialog,
              icon: const Icon(Icons.perm_device_information),
              label: const Text('Get Full Device Info (Android ID)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isStreamingLiveUpdate ? null : _startLiveUpdateTest,
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Start Demo Route Live Update Test'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isStreamingLiveUpdate ? _stopLiveUpdateTest : null,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop Live Update Test'),
            ),
            const SizedBox(height: 12),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Active Ride Notification Mock',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Mimics the active ride foreground tracking notification status/location flow.',
            ),
            const SizedBox(height: 8),
            Text(
              _activeRideSummary(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isMockActiveRideNotificationRunning
                  ? null
                  : _startMockActiveRideNotification,
              icon: const Icon(Icons.local_shipping_rounded),
              label: const Text('Start Active Ride Mock Notification'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isMockActiveRideNotificationRunning
                  ? _stopMockActiveRideNotification
                  : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop Active Ride Mock Notification'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _refreshActiveRideState,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Active Ride Mock State'),
            ),

            if (isDeniedForever) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: Geolocator.openAppSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open App Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
