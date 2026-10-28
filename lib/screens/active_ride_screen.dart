import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import '../services/background_service.dart';
import '../services/notification_test_service.dart';
import '../services/offline_sync_service.dart';
import '../main.dart';
import '../models/trip.dart';

class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen>
    with SingleTickerProviderStateMixin {
  bool _isRideActive = false;
  bool _isPaused = false;
  bool _isLoading = true;
  bool _showConnectionError = false;
  ActiveTripDto? _activeTrip;

  StreamSubscription<Position>? _positionSubscription;
  List<StreamSubscription> _serviceSubscriptions = [];
  double? _distanceToDestinationMeters;
  double? _initialDistanceMeters;

  late TabController _tabController;
  int _locationConnectionErrorCount = 0;
  Timer? _syncTimer;
  bool _isManualSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchActiveTrip();

    // Periodic sync attempt every 3 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      offlineSyncService.syncPendingExpenses();
    });

    _serviceSubscriptions = BackgroundService.listenToService(
      onData: (data) {
        if (mounted && data != null) {
          setState(() {
            if (data['distanceMeters'] != null) {
              _distanceToDestinationMeters = (data['distanceMeters'] as num)
                  .toDouble();
            }
          });
        }
      },
      onAutoUnpause: () => _resumeRide(auto: true),
    );
  }

  void _handleTabSelection() {
    // Hide keyboard when moving away from Chat tab (index 1)
    if (_tabController.index != 1) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Future<void> _manualSync() async {
    if (_isManualSyncing) return;
    setState(() => _isManualSyncing = true);
    
    try {
      await offlineSyncService.syncPendingExpenses();
      if (mounted) {
        if (offlineSyncService.pendingCount.value == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All pending items synced successfully!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Some items could not be synced. Check your connection.'), backgroundColor: Colors.orange),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tabController.removeListener(_handleTabSelection);
    _positionSubscription?.cancel();
    for (final sub in _serviceSubscriptions) {
      sub.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final trip = await apiService.getActiveTrip();
      if (mounted) {
        setState(() {
          _activeTrip = trip;
          _isRideActive = true;
          _isPaused = trip.isPaused;
          _isLoading = false;
          _showConnectionError = false;
        });

        // Save trip locally for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_trip_cache', jsonEncode(trip.toJson()));

        final started = await BackgroundService.startService();
        if (started) {
          BackgroundService.sendDestination(
            trip.destinationLatitude,
            trip.destinationLongitude,
            trip.destinationName,
            trip.id,
          );
        }
        _startLocationTracking();
      }
    } catch (e) {
      if (mounted) {
        // Try to load from cache if network fails
        final prefs = await SharedPreferences.getInstance();
        final cachedTrip = prefs.getString('active_trip_cache');
        if (cachedTrip != null) {
          try {
            final trip = ActiveTripDto.fromJson(jsonDecode(cachedTrip));
            setState(() {
              _activeTrip = trip;
              _isRideActive = true;
              _isPaused = trip.isPaused;
              _isLoading = false;
              _showConnectionError = true;
            });
            _startLocationTracking();
            return;
          } catch (_) {}
        }

        setState(() {
          _isLoading = false;
          if (e is DioException &&
              (e.type == DioExceptionType.connectionError ||
                  e.type == DioExceptionType.connectionTimeout)) {
            _showConnectionError = true;
          }
        });
      }
    }
  }

  void _togglePause() async {
    if (_activeTrip == null) return;
    final newPauseState = !_isPaused;

    try {
      await apiService.pauseTrip(_activeTrip!.id, newPauseState);
      setState(() => _isPaused = newPauseState);
      BackgroundService.setPaused(newPauseState);
      NotificationTestService.sendDriverStatusNotification(
        isPaused: newPauseState,
      );
    } catch (e) {
      if (mounted) {
        final message = await apiService.getErrorMessage(
          e is DioException ? e : DioException(requestOptions: RequestOptions(), error: e),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update trip status: $message')),
          );
        }
      }
    }
  }

  void _resumeRide({bool auto = false}) async {
    if (!_isPaused || _activeTrip == null) return;
    try {
      await apiService.pauseTrip(_activeTrip!.id, false);
      setState(() => _isPaused = false);
      BackgroundService.setPaused(false);
      NotificationTestService.sendDriverStatusNotification(isPaused: false);
      if (auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movement detected. Trip resumed automatically.'),
          ),
        );
      }
    } catch (_) {}
  }

  void _triggerSos() async {
    if (_activeTrip == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TRIGGER SOS?'),
        content: const Text(
          'This will alert dispatch and emergency services. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('YES, TRIGGER SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      Position position = await Geolocator.getCurrentPosition();
      await apiService.triggerSos(
        _activeTrip!.id,
        TriggerSosRequest(
          latitude: position.latitude,
          longitude: position.longitude,
          notes: 'SOS triggered by driver from mobile app.',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS Alert Sent! Dispatch has been notified.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = await apiService.getErrorMessage(e is DioException ? e : DioException(requestOptions: RequestOptions(), error: e));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send SOS: $message')));
      }
    }
  }

  Future<void> _startLocationTracking() async {
    if (_activeTrip == null) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 30), // Restart if no data for 30s
          ),
        ).listen(
          (position) {
            if (!mounted) return;

            final dist = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              _activeTrip!.destinationLatitude,
              _activeTrip!.destinationLongitude,
            );

            setState(() {
              _distanceToDestinationMeters = dist;
              _initialDistanceMeters ??= dist;
            });

            if (_isRideActive && !_isPaused) {
              _updateLocation(position);

              BackgroundService.sendLocationUpdate(
                lat: position.latitude,
                lng: position.longitude,
                accuracyMeters: position.accuracy,
                at: DateTime.now(),
              );
            }
          },
          onError: (error) {
            debugPrint('Location Stream Error, restarting in 5s: $error');
            // Restart tracking after a short delay to avoid tight loops
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && _isRideActive) {
                _startLocationTracking();
              }
            });
          },
          cancelOnError: true, // We want to restart from scratch
        );
  }

  Future<void> _updateLocation(Position position) async {
    try {
      await apiService.updateLocation(
        _activeTrip!.id,
        UpdateTripLocationRequest(
          latitude: position.latitude,
          longitude: position.longitude,
          speedKmh: position.speed * 3.6,
        ),
      );
      // Reset counter on success
      _locationConnectionErrorCount = 0;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        if (mounted) setState(() => _showConnectionError = true);
        _locationConnectionErrorCount++;
        if (_locationConnectionErrorCount == 4) {
          NotificationTestService.sendInternetConnectionAlert();
        }
      } else {
        if (mounted) setState(() => _showConnectionError = false);
      }

      final message = await apiService.getErrorMessage(e);
      if (message.contains('Trip is not in Ongoing status')) {
        // This trip has been finished or cancelled on the server side
        if (mounted) {
          _stopTrackingAndNotifyUser();
        }
      }
    } catch (_) {
      // Ignore other location update errors to not disturb the driver
    }
  }

  void _stopTrackingAndNotifyUser() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    setState(() {
      _isRideActive = false;
      _activeTrip = null;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Trip Status Changed'),
        content: const Text(
          'This trip has already been finished by someone else or an error occurred. Please contact your admin for more information.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
            child: const Text('OK, BACK TO DASHBOARD'),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    if (_activeTrip == null) return;
    await MapsLauncher.launchCoordinates(
      _activeTrip!.destinationLatitude,
      _activeTrip!.destinationLongitude,
      _activeTrip!.destinationAddress,
    );
  }

  Future<void> _endRide() async {
    if (_activeTrip == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Arrival'),
        content: Text(
          'Are you sure you have arrived at ${_activeTrip!.destinationName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES, ARRIVED'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await Navigator.pushNamed(
      context,
      '/delivery-checkpoints',
      arguments: _activeTrip!.id,
    );
    if (result == true && mounted) {
      await BackgroundService.stopService();
      await NotificationTestService.cancelLiveUpdateNotification();
      if (!mounted || !context.mounted) return;
      // Go back to dashboard which is already refreshed by DeliveryCheckpointsScreen
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Back to Dashboard?'),
            content: const Text(
              'Your trip is still active. Are you sure you want to go back to the dashboard? Tracking will continue in the background.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('BACK'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('MAIN MENU'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Current Trip'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Trigger the same logic as the system back button
              Navigator.maybePop(context);
            },
          ),
          actions: [
            ValueListenableBuilder<int>(
              valueListenable: offlineSyncService.pendingCount,
              builder: (context, count, _) {
                if (count == 0) return const SizedBox.shrink();
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: _isManualSyncing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.cloud_upload_outlined),
                      tooltip: 'Sync pending expenses',
                      onPressed: _manualSync,
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.local_shipping), text: 'Trip'),
              Tab(icon: Icon(Icons.chat), text: 'Chat'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildTripBody(context, cs, tt), const ChatView()],
        ),
      ),
    );
  }

  Widget _buildTripBody(BuildContext context, ColorScheme cs, TextTheme tt) {
    final isArrived =
        _distanceToDestinationMeters != null &&
        _distanceToDestinationMeters! <= 250;
    final distanceLabel = _distanceToDestinationMeters == null
        ? 'Calculating…'
        : isArrived
        ? "You're here!"
        : _distanceToDestinationMeters! >= 1000
        ? '${(_distanceToDestinationMeters! / 1000).toStringAsFixed(1)} km'
        : '${_distanceToDestinationMeters!.toStringAsFixed(0)} m';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showConnectionError)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.red.shade900, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No internet connection. Syncing will resume automatically.',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isRideActive && _activeTrip != null) ...[
            Card(
              color: cs.primaryContainer,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArrived ? 'ARRIVED' : 'EN ROUTE',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                        if (_isPaused)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PAUSED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _activeTrip!.destinationName,
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onPrimaryContainer,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      _activeTrip!.destinationAddress,
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      distanceLabel.toUpperCase(),
                      style: tt.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_initialDistanceMeters != null &&
                        _distanceToDestinationMeters != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value:
                              (_initialDistanceMeters! -
                                  _distanceToDestinationMeters!) /
                              _initialDistanceMeters!.clamp(
                                1.0,
                                double.infinity,
                              ),
                          minHeight: 12,
                          backgroundColor: cs.onPrimaryContainer.withValues(
                            alpha: 0.1,
                          ),
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.info_outline),
                title: const Text(
                  'Trip Details',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Tap to view more information'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _RouteInfoRow(
                    icon: Icons.local_shipping,
                    label: 'Truck',
                    value: _activeTrip!.truckPlateNumber,
                  ),
                  const Divider(),
                  _RouteInfoRow(
                    icon: Icons.badge,
                    label: 'Trip Ref',
                    value: _activeTrip!.jobId,
                  ),
                  const Divider(),
                  _RouteInfoRow(
                    icon: Icons.location_on,
                    label: 'Pickup',
                    value: _activeTrip!.pickupName,
                  ),
                  if (_activeTrip!.adminInstructions != null) ...[
                    const Divider(),
                    _RouteInfoRow(
                      icon: Icons.campaign,
                      label: 'Dispatcher note',
                      value: _activeTrip!.adminInstructions!,
                    ),
                  ],
                ],
              ),
            ),
            if (_activeTrip!.adminInstructions != null) ...[
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openGoogleMaps,
              icon: const Icon(Icons.map),
              label: const Text('Open Map Navigation'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(68),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _togglePause,
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(_isPaused ? 'Resume Trip' : 'Pause Trip'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(68),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/fuel-receipt',
                      arguments: _activeTrip!.id,
                    ),
                    icon: const Icon(Icons.local_gas_station),
                    label: const Text('Fuel'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/add-toll',
                      arguments: _activeTrip!.id,
                    ),
                    icon: const Icon(Icons.toll),
                    label: const Text('Toll'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/report-incident',
                arguments: _activeTrip!.id,
              ),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report Incident'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                side: const BorderSide(color: Colors.orange, width: 1.5),
                foregroundColor: Colors.orange,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _triggerSos,
              icon: const Icon(Icons.sos, color: Colors.white),
              label: const Text('SOS EMERGENCY'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(68),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _endRide,
              icon: const Icon(Icons.check_circle),
              label: const Text('Start Arrival Steps'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
                textStyle: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ] else ...[
            const Center(
              child: Text('No trip in progress. Go to My Trips to start.'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _RouteInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
