import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionGuard {
  static Future<bool> ensureActiveRideReady(BuildContext context) async {
    // Notifications (Android 13+)
    if (Platform.isAndroid) {
      final notif = await Permission.notification.status;
      if (!notif.isGranted) {
        if (!context.mounted) return false;
        final ok = await _confirmDialog(
          context,
          title: 'Allow notifications',
          message:
              'We need notifications to show the ongoing GPS tracking status during active rides.',
          confirmText: 'Allow',
        );
        if (!ok) return false;
        final res = await Permission.notification.request();
        if (!res.isGranted) {
          if (!context.mounted) return false;
          await _settingsDialog(
            context,
            title: 'Notifications blocked',
            message:
                'Please enable notifications in Settings so the tracking notification can stay visible.',
          );
          return false;
        }
      }
    }

    // Location services enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      final ok = await _confirmDialog(
        context,
        title: 'Turn on location (GPS)',
        message:
            'GPS must be turned on to track your ride and update the live notification.',
        confirmText: 'Open settings',
      );
      if (!ok) return false;
      await Geolocator.openLocationSettings();
      return false; // user must re-try after enabling
    }

    // Location permission (foreground)
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      if (!context.mounted) return false;
      final ok = await _confirmDialog(
        context,
        title: 'Allow location access',
        message:
            'We need location access to track your ride and send updates while the ride is active.',
        confirmText: 'Allow',
      );
      if (!ok) return false;
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      return false;
    }

    // Background location for ride tracking
    if (Platform.isAndroid) {
      // On Android, geolocator uses ACCESS_BACKGROUND_LOCATION; permission_handler can prompt settings.
      final bg = await Permission.locationAlways.status;
      if (!bg.isGranted) {
        if (!context.mounted) return false;
        final ok = await _confirmDialog(
          context,
          title: 'Allow background location',
          message:
              'To keep GPS tracking active during a ride (even when the app is minimized), allow background location.',
          confirmText: 'Allow',
        );
        if (!ok) return false;
        final res = await Permission.locationAlways.request();
        if (!res.isGranted) {
          if (!context.mounted) return false;
          await _settingsDialog(
            context,
            title: 'Background location blocked',
            message:
                'Enable “Allow all the time” in Settings so ride tracking continues in the background.',
          );
          return false;
        }
      }
    }

    return true;
  }

  static Future<bool> ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (!context.mounted) return false;
    final ok = await _confirmDialog(
      context,
      title: 'Camera access',
      message: 'We need camera access to take photos for trip documentation.',
      confirmText: 'Allow',
    );
    if (!ok) return false;

    final res = await Permission.camera.request();
    if (res.isGranted) return true;

    if (res.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _settingsDialog(
        context,
        title: 'Camera blocked',
        message: 'Please enable camera access in Settings.',
      );
    }
    return false;
  }

  static Future<bool> ensurePhotoLibraryPermission(BuildContext context) async {
    final androidVersion = await _getAndroidVersion();
    Permission permission = Platform.isAndroid && (androidVersion >= 33)
        ? Permission.photos
        : Permission.photos;

    if (Platform.isAndroid && (androidVersion < 33)) {
      permission = Permission.storage;
    }

    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    if (!context.mounted) return false;
    final ok = await _confirmDialog(
      context,
      title: 'Photo library access',
      message: 'We need access to your photos to upload trip documentation.',
      confirmText: 'Allow',
    );
    if (!ok) return false;

    final res = await permission.request();
    return res.isGranted || res.isLimited;
  }

  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (_) {
      return 33; // Fallback
    }
  }

  static Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  static Future<void> _settingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
