import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'background_service.dart';

class NotificationTestService {
  static const String _channelId = 'trip_assignment_important_v2';
  static const String _channelName = 'Trip Assignment Alerts';
  static const String _channelDescription =
      'Important notifications when a new trip is assigned.';
  static const int _testTripNotificationId = 770001;
  static const String _trackingChannelName = 'Ride Tracking Alerts';
  static const String _trackingChannelDescription =
      'Foreground ride tracking notifications and service status.';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const Duration _minLiveUpdateInterval = Duration(seconds: 20);
  static const double _minDistanceDeltaMeters = 25;
  static const int _progressMax = 1000;

  static DateTime? _lastLiveUpdateAt;
  static double? _lastLiveDistanceMeters;
  static bool? _lastLiveArrivedState;
  static DateTime? _lastIndeterminateUpdateAt;
  static String? _lastIndeterminateContent;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        BackgroundService.trackingNotificationChannelId,
        _trackingChannelName,
        description: _trackingChannelDescription,
        importance: Importance
            .low, // Lower importance so it doesn't pop up or make noise
        playSound: false,
        enableVibration: false,
      ),
    );

    _initialized = true;
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
  }

  static NotificationDetails _tripAssignedDetails({
    required String expandedText,
  }) {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.transport,
      ticker: 'New trip assignment',
      styleInformation: BigTextStyleInformation(
        expandedText,
        contentTitle: 'Trip Ready for Dispatch',
        summaryText: 'Open app to review and accept',
      ),
    );

    return NotificationDetails(android: androidDetails);
  }

  static NotificationDetails _trackingDetails({
    required String subText,
    required bool indeterminate,
    required int progress,
  }) {
    final androidDetails = AndroidNotificationDetails(
      BackgroundService.trackingNotificationChannelId,
      _trackingChannelName,
      channelDescription: _trackingChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.service,
      showWhen: false,
      onlyAlertOnce: true,
      additionalFlags: Int32List.fromList(<int>[32]),
      subText: subText,
      showProgress: true,
      maxProgress: _progressMax,
      progress: progress,
      indeterminate: indeterminate,
    );

    return NotificationDetails(android: androidDetails);
  }

  static Future<void> sendTripAssignedNotification({
    required DateTime tripDate,
    required String destination,
    String? truckNumber,
    String? tripCode,
    String? eta,
    bool testMode = false,
  }) async {
    await initialize();

    if (kIsWeb) {
      return;
    }

    final dateLabel = DateFormat('MMM dd, yyyy').format(tripDate);
    final dayLabel = DateFormat('EEEE').format(tripDate);
    final tripLabel = (tripCode == null || tripCode.trim().isEmpty)
        ? 'N/A'
        : tripCode.trim();
    final truckLabel = (truckNumber == null || truckNumber.trim().isEmpty)
        ? 'Unassigned'
        : truckNumber.trim();
    final etaLabel = (eta == null || eta.trim().isEmpty)
        ? 'Pending from dispatch'
        : eta.trim();

    final body = StringBuffer()
      ..writeln('Destination: $destination')
      ..writeln('Trip date: $dayLabel, $dateLabel')
      ..writeln('Truck: $truckLabel')
      ..writeln('Trip code: $tripLabel')
      ..write('ETA: $etaLabel');

    final notificationId = testMode
        ? _testTripNotificationId
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final title = testMode ? 'Test Trip Assignment' : 'New Trip Assignment';

    await _notificationsPlugin.show(
      notificationId,
      title,
      'Destination: $destination',
      _tripAssignedDetails(expandedText: body.toString()),
    );
  }

  /// The initial distance captured at ride start, used to calculate progress.
  static double? _initialDistance;

  static void _resetLiveUpdateState() {
    _initialDistance = null;
    _lastLiveUpdateAt = null;
    _lastLiveDistanceMeters = null;
    _lastLiveArrivedState = null;
    _lastIndeterminateUpdateAt = null;
    _lastIndeterminateContent = null;
  }

  /// Fires the ride notification as a live update with a progress bar.
  /// Called once when the ride starts, and then on each GPS update.
  static Future<void> sendRideStartedNotification({
    required String destination,
  }) async {
    await initialize();
    if (kIsWeb) return;

    _resetLiveUpdateState();

    await _notificationsPlugin.show(
      BackgroundService.trackingNotificationId,
      'Active Job - GPS Tracking',
      'Calculating route...',
      _trackingDetails(
        subText: 'Arriving to $destination',
        indeterminate: true,
        progress: 0,
      ),
    );
  }

  /// Updates the live notification with the current distance progress.
  static Future<void> sendDriverStatusNotification({
    required bool isPaused,
  }) async {
    final status = isPaused ? 'PAUSED' : 'DRIVING / ACTIVE';
    final message = isPaused
        ? 'IMPORTANT! Your ride is now paused. Remember to resume when you continue.'
        : 'Your ride is now active. Safe travels!';

    await _notificationsPlugin.show(
      99, // Status ID
      'Ride Status: $status',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ride_updates',
          'Ride Updates',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> sendPausedReminderNotification() async {
    await initialize();
    if (kIsWeb) return;

    await _notificationsPlugin.show(
      100, // Reminder ID
      'Trip Still Paused',
      'Don\'t forget to unpause your trip to continue tracking your progress!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'paused_reminders',
          'Paused Reminders',
          channelDescription: 'Reminders to unpause your trip',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> sendInternetConnectionAlert() async {
    await initialize();
    if (kIsWeb) return;

    await _notificationsPlugin.show(
      101, // Connection Alert ID
      'Connection Issue Detected',
      'Please check your internet connection in a safe location.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'connection_alerts',
          'Connection Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> sendLiveUpdateNotification({
    required double distanceMeters,
    required String destination,
    double? currentLat,
    double? currentLng,
  }) async {
    await initialize();
    if (kIsWeb) return;

    _initialDistance ??= distanceMeters;
    if (_initialDistance! < 1) {
      _initialDistance = distanceMeters > 0 ? distanceMeters : 1;
    }

    final now = DateTime.now();
    final distanceStr = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${distanceMeters.toStringAsFixed(0)} m';

    double progress = (_initialDistance! - distanceMeters) / _initialDistance!;
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;

    final isArrived = distanceMeters <= 250;
    final elapsed = _lastLiveUpdateAt == null
        ? _minLiveUpdateInterval
        : now.difference(_lastLiveUpdateAt!);
    final distanceDelta = _lastLiveDistanceMeters == null
        ? _minDistanceDeltaMeters
        : (distanceMeters - _lastLiveDistanceMeters!).abs();
    final stateChanged = _lastLiveArrivedState != isArrived;
    final shouldEmit =
        stateChanged ||
        elapsed >= _minLiveUpdateInterval ||
        distanceDelta >= _minDistanceDeltaMeters;

    if (!shouldEmit) {
      return;
    }

    final subText = isArrived
        ? 'Arrived at $destination'
        : 'Arriving to $destination';
    final locationSuffix = (currentLat == null || currentLng == null)
        ? ''
        : ' • ${currentLat.toStringAsFixed(4)}, ${currentLng.toStringAsFixed(4)}';
    final progressValue = (progress * _progressMax).toInt();

    await _notificationsPlugin.show(
      BackgroundService.trackingNotificationId,
      'Active Job - GPS Tracking',
      isArrived
          ? 'You can now complete the job.$locationSuffix'
          : '$distanceStr remaining$locationSuffix',
      _trackingDetails(
        subText: subText,
        indeterminate: false,
        progress: progressValue,
      ),
    );

    _lastLiveUpdateAt = now;
    _lastLiveDistanceMeters = distanceMeters;
    _lastLiveArrivedState = isArrived;
    _lastIndeterminateContent = null;
    _lastIndeterminateUpdateAt = null;
  }

  /// Updates the live notification when GPS is waiting or distance is unknown.
  static Future<void> sendIndeterminateLiveUpdateNotification({
    required String content,
    required String destination,
  }) async {
    await initialize();
    if (kIsWeb) return;

    final now = DateTime.now();
    final elapsed = _lastIndeterminateUpdateAt == null
        ? _minLiveUpdateInterval
        : now.difference(_lastIndeterminateUpdateAt!);
    final isDifferentContent = _lastIndeterminateContent != content;
    if (!isDifferentContent && elapsed < _minLiveUpdateInterval) {
      return;
    }

    await _notificationsPlugin.show(
      BackgroundService.trackingNotificationId,
      'Active Job - GPS Tracking',
      content,
      _trackingDetails(
        subText: 'Arriving to $destination',
        indeterminate: true,
        progress: 0,
      ),
    );

    _lastIndeterminateUpdateAt = now;
    _lastIndeterminateContent = content;
    _lastLiveUpdateAt = null;
    _lastLiveDistanceMeters = null;
    _lastLiveArrivedState = null;
  }

  /// Cancels the ride notification (call when ride ends).
  static Future<void> cancelRideNotification() async {
    if (kIsWeb) return;
    _resetLiveUpdateState();
    await _notificationsPlugin.cancel(BackgroundService.trackingNotificationId);
  }

  /// Cancels the live update notification (alias, same ID).
  static Future<void> cancelLiveUpdateNotification() async {
    await cancelRideNotification();
  }
}
