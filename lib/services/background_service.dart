import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'mock_backend_service.dart';
import 'notification_test_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static const String trackingNotificationChannelId =
      'fleet_driver_tracking_alerts_v1';
  static const int trackingNotificationId = 888;
  static const MethodChannel _nativeNotificationsChannel = MethodChannel(
    'fleet_driver/native_notifications',
  );
  static bool _nativeNotificationsAvailable = true;

  static Future<void> _invokeNativeNotification(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!_nativeNotificationsAvailable) {
      return;
    }
    try {
      await _nativeNotificationsChannel.invokeMethod(method, arguments);
    } on MissingPluginException catch (e) {
      _nativeNotificationsAvailable = false;
      debugPrint(
        'Native notifications unavailable in this isolate: ${e.message}',
      );
    } on PlatformException catch (e) {
      debugPrint('Native notification call failed ($method): ${e.message}');
    }
  }

  static double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static Future<void> _setForegroundInfo(
    dynamic androidService, {
    required String content,
  }) async {
    try {
      await androidService.setForegroundNotificationInfo(
        title: 'Active Job - GPS Tracking',
        content: content,
      );
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        notificationChannelId: trackingNotificationChannelId,
        initialNotificationTitle: 'Active Job — GPS Active',
        initialNotificationContent:
            'Tracking is running. Do not turn off the app for tracking purposes.',
        foregroundServiceNotificationId: trackingNotificationId,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> startService() async {
    try {
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        return await service.startService();
      }
      return true;
    } catch (e) {
      debugPrint('Error starting service: $e');
      return false;
    }
  }

  /// Send destination coordinates and name to the running background service.
  static void sendDestination(
    double destLat,
    double destLng,
    String destName,
    String tripId,
  ) {
    final service = FlutterBackgroundService();
    service.invoke('setDestination', {
      'destLat': destLat,
      'destLng': destLng,
      'destName': destName,
      'tripId': tripId,
    });
  }

  /// Update pause state in background service for auto-unpause logic.
  static void setPaused(bool isPaused) {
    final service = FlutterBackgroundService();
    service.invoke('setPaused', {'isPaused': isPaused});
  }

  /// Send latest foreground location to background service for notification updates.
  static void sendLocationUpdate({
    required double lat,
    required double lng,
    double? accuracyMeters,
    DateTime? at,
  }) {
    final service = FlutterBackgroundService();
    service.invoke('locationUpdate', {
      'lat': lat,
      'lng': lng,
      'accuracy': accuracyMeters,
      'at': (at ?? DateTime.now()).toIso8601String(),
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> stopService() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (isRunning) {
      await _invokeNativeNotification('clearTrackingProgress');
      service.invoke('stop');
      return true;
    }
    return false;
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final isAndroidService = service.runtimeType.toString().contains('Android');
    final dynamic androidService = isAndroidService ? service as dynamic : null;

    // Destination coords and name — updated via 'setDestination' invoke from UI.
    double? destLat;
    double? destLng;
    String destName = 'destination';
    double? initialDistanceMeters;
    double? currentLat;
    double? currentLng;
    double? currentAccuracy;
    DateTime? currentAt;

    // Auto-unpause logic state
    bool isPaused = false;
    double? pauseLat;
    double? pauseLng;
    Timer? pausedReminderTimer;

    Future<void> pushTrackingUpdate() async {
      double? distMeters;
      if (currentLat != null &&
          currentLng != null &&
          destLat != null &&
          destLng != null) {
        distMeters = _distanceMeters(
          currentLat!,
          currentLng!,
          destLat!,
          destLng!,
        );
      }

      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      String notifContent;
      if (currentLat == null || currentLng == null) {
        notifContent = 'Waiting for GPS signal…  •  $timeStr';
      } else {
        final coordStr =
            'Lat ${currentLat!.toStringAsFixed(4)}, Lng ${currentLng!.toStringAsFixed(4)}';
        if (distMeters != null) {
          final distStr = distMeters >= 1000
              ? '${(distMeters / 1000).toStringAsFixed(1)} km remaining'
              : '${distMeters.toStringAsFixed(0)} m remaining';
          notifContent = isPaused
              ? 'PAUSED • $distStr'
              : '$distStr  •  $coordStr  •  $timeStr';
        } else {
          notifContent = isPaused
              ? 'PAUSED • $coordStr'
              : '$coordStr  •  Updated $timeStr';
        }
      }

      if (isAndroidService) {
        if (distMeters != null) {
          initialDistanceMeters ??= distMeters > 1 ? distMeters : 1;
          var progress =
              ((initialDistanceMeters! - distMeters) / initialDistanceMeters!) *
              100;
          if (progress < 0) progress = 0;
          if (progress > 100) progress = 100;

          final progressContent = isPaused
              ? 'Ride is currently paused. Move 300m to auto-resume.'
              : (distMeters <= 250
                    ? 'You can now complete the job. ${currentLat!.toStringAsFixed(4)}, ${currentLng!.toStringAsFixed(4)} Dont forget to submit Post-Ride Images.'
                    : (distMeters >= 1000
                          ? '${(distMeters / 1000).toStringAsFixed(1)} km remaining • ${currentLat!.toStringAsFixed(4)}, ${currentLng!.toStringAsFixed(4)}'
                          : '${distMeters.toStringAsFixed(0)} m remaining • ${currentLat!.toStringAsFixed(4)}, ${currentLng!.toStringAsFixed(4)}'));

          // Use the reliable notification service instead of the broken custom native channel
          await NotificationTestService.sendLiveUpdateNotification(
            distanceMeters: distMeters,
            destination: destName,
            currentLat: currentLat,
            currentLng: currentLng,
          );

          await _setForegroundInfo(androidService, content: progressContent);
        } else {
          await NotificationTestService.sendIndeterminateLiveUpdateNotification(
            content: notifContent,
            destination: destName,
          );
          await _setForegroundInfo(androidService, content: notifContent);
        }
      }

      service.invoke('update', {
        'current_date': DateTime.now().toIso8601String(),
        'status': 'tracking',
        'isPaused': isPaused,
        'lat': ?currentLat,
        'lng': ?currentLng,
        'accuracy': ?currentAccuracy,
        if (currentAt != null) 'locationAt': currentAt!.toIso8601String(),
        'distanceMeters': distMeters,
      });
    }

    // Only android-specific setup
    if (isAndroidService) {
      // Immediately set as foreground - this creates the initial ongoing notification
      try {
        await androidService.setAsForegroundService();
        await _setForegroundInfo(
          androidService,
          content: 'Tracking is running. Preparing route...',
        );
        debugPrint('Service set as foreground successfully');
      } catch (e) {
        debugPrint('Error setting foreground: $e');
      }

      service.on('setAsForeground').listen((event) async {
        await androidService.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        // Prevent setting as background - keep it foreground always
        androidService.setAsForegroundService();
      });
    }

    // Accept destination coords sent from the UI when the ride starts.
    service.on('setDestination').listen((event) {
      if (event != null) {
        destLat = (event['destLat'] as num?)?.toDouble();
        destLng = (event['destLng'] as num?)?.toDouble();
        destName = (event['destName'] as String?) ?? 'destination';
        initialDistanceMeters = null;
        if (isAndroidService) {
          _setForegroundInfo(
            androidService,
            content: 'Tracking route to $destName...',
          );
        }
        debugPrint('Destination set: $destLat, $destLng ($destName)');
        unawaited(pushTrackingUpdate());
      }
    });

    service.on('setPaused').listen((event) {
      if (event != null) {
        isPaused = event['isPaused'] as bool;
        pausedReminderTimer?.cancel();

        if (isPaused) {
          pauseLat = currentLat;
          pauseLng = currentLng;
          debugPrint('Ride paused at: $pauseLat, $pauseLng');

          // Start 10-minute reminder
          pausedReminderTimer = Timer.periodic(const Duration(minutes: 10), (_) {
            NotificationTestService.sendPausedReminderNotification();
          });
        } else {
          pauseLat = null;
          pauseLng = null;
          debugPrint('Ride resumed');
        }
        unawaited(pushTrackingUpdate());
      }
    });

    service.on('locationUpdate').listen((event) async {
      if (event == null) {
        return;
      }
      final lat = (event['lat'] as num?)?.toDouble();
      final lng = (event['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return;
      }

      currentLat = lat;
      currentLng = lng;
      currentAccuracy = (event['accuracy'] as num?)?.toDouble();
      final atRaw = event['at'] as String?;
      currentAt = DateTime.tryParse(atRaw ?? '') ?? DateTime.now();

      // Check for auto-unpause
      if (isPaused && pauseLat != null && pauseLng != null) {
        final movedDistance = _distanceMeters(pauseLat!, pauseLng!, lat, lng);
        if (movedDistance >= 300) {
          debugPrint(
            'Driver moved ${movedDistance.toStringAsFixed(1)}m. Auto-unpausing.',
          );
          isPaused = false;
          pauseLat = null;
          pauseLng = null;
          pausedReminderTimer?.cancel();
          service.invoke('autoUnpause');
        }
      }

      await MockBackendService.initialize();
      await MockBackendService.addLocationPing(
        LocationPing(
          lat: lat,
          lng: lng,
          accuracyMeters: currentAccuracy,
          at: currentAt!,
        ),
      );

      await pushTrackingUpdate();
    });

    Timer? heartbeatTimer;
    service.on('stop').listen((event) {
      pausedReminderTimer?.cancel();
      heartbeatTimer?.cancel();
      service.stopSelf();
    });

    // Keep foreground-service state healthy and emit periodic heartbeat updates.
    heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (isAndroidService) {
        try {
          bool isForeground = await androidService.isForegroundService();
          if (!isForeground) {
            await androidService.setAsForegroundService();
            debugPrint('Restored foreground service status');
          }
        } catch (e) {
          debugPrint('Error in service loop: $e');
        }
      }
      await pushTrackingUpdate();
    });
  }

  @pragma('vm:entry-point')
  static List<StreamSubscription> listenToService({
    required Function(Map<String, dynamic>?) onData,
    Function()? onAutoUnpause,
  }) {
    final service = FlutterBackgroundService();
    final sub1 = service.on('update').listen((event) {
      onData(event);
    });
    final sub2 = service.on('autoUnpause').listen((event) {
      if (onAutoUnpause != null) {
        onAutoUnpause();
      }
    });
    return [sub1, sub2];
  }
}
