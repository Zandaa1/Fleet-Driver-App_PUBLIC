import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show themeModeNotifier, apiService;
import '../models/trip.dart';
import '../services/api_service.dart';
import '../services/notification_test_service.dart';
import '../services/offline_sync_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static final GlobalKey<DashboardScreenState> dashboardKey =
      GlobalKey<DashboardScreenState>();

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _showUpcoming = true;
  bool _showPast = false;
  bool _showConnectionError = false;
  late Future<CrewDashboardDto> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();

    // Request notification permissions in the UI layer where Activity context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationTestService.requestPermission();
    });
  }

  void refresh() {
    _refreshDashboard();
  }

  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
    // Also try to sync any pending offline items
    offlineSyncService.syncPendingExpenses();
  }

  Future<CrewDashboardDto> _loadDashboardData() async {
    try {
      final data = await apiService.getDashboard();
      
      // Cache the data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dashboard_cache', jsonEncode(data.toJson()));
      
      if (mounted) {
        setState(() => _showConnectionError = false);
      }
      return data;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('dashboard_cache');
      
      if (cached != null) {
        try {
          final data = CrewDashboardDto.fromJson(jsonDecode(cached));
          if (mounted) {
            setState(() => _showConnectionError = true);
          }
          return data;
        } catch (_) {}
      }
      
      rethrow;
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await apiService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false, // Prevent back button from popping the dashboard
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Optional: show exit confirmation if needed, but for now just block it
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'My Trips',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          centerTitle: false,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            if (!kReleaseMode)
              ValueListenableBuilder<bool>(
                valueListenable: ApiService.offlineUiTestModeNotifier,
                builder: (context, enabled, _) {
                  if (!enabled) {
                    return const SizedBox.shrink();
                  }

                  return const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Center(
                      child: Chip(
                        avatar: Icon(Icons.science_outlined, size: 16),
                        label: Text('UI TEST'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  );
                },
              ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, mode, _) {
                final isDark =
                    mode == ThemeMode.dark ||
                    (mode == ThemeMode.system &&
                        MediaQuery.platformBrightnessOf(context) ==
                            Brightness.dark);
                return IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  ),
                  tooltip: isDark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: () {
                    themeModeNotifier.value = isDark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  },
                );
              },
            ),
            TextButton.icon(
              onPressed: () => _showLogoutConfirmation(context),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Logout'),
              style: TextButton.styleFrom(foregroundColor: cs.error),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<CrewDashboardDto>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final is401 = apiService.isUnauthorized(snapshot.error);

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        is401 ? Icons.lock_clock_outlined : Icons.error_outline,
                        size: 64,
                        color: cs.error,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        is401
                            ? 'Your session has expired'
                            : 'We could not load your trips right now.',
                        textAlign: TextAlign.center,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (is401)
                        Text(
                          'Please log out and log in again to continue.',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (is401)
                        FilledButton.icon(
                          onPressed: () async {
                            await apiService.logout();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/');
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('LOGOUT AND RE-LOGIN'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(200, 56),
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _refreshDashboard,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(160, 48),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => _refreshDashboard(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showConnectionError)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: Colors.red.shade100,
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off,
                              color: Colors.red.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Currently showing a saved copy of your trips, connect to internet.',
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
                    if (!kReleaseMode)
                      ValueListenableBuilder<bool>(
                        valueListenable: ApiService.offlineUiTestModeNotifier,
                        builder: (context, enabled, _) {
                          if (!enabled) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade700),
                            ),
                            child: const Text(
                              'Demo mode is on. You are viewing sample trip data.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: tt.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.crewName,
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Ongoing Trip
                          if (data.ongoingTrip != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.navigation_rounded,
                                  color: cs.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Current Trip',
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _RideCard(trip: data.ongoingTrip!, isCurrent: true),
                            const SizedBox(height: 24),
                          ] else ...[
                            Card(
                              elevation: 0,
                              color: cs.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No active trip at the moment.',
                                        style: tt.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Upcoming Trips
                          _SectionHeader(
                            title: 'Next Trips',
                            count: data.upcomingTrips.length,
                            isExpanded: _showUpcoming,
                            onToggle: () =>
                                setState(() => _showUpcoming = !_showUpcoming),
                          ),
                          if (_showUpcoming) ...[
                            const SizedBox(height: 16),
                            if (data.upcomingTrips.isEmpty)
                              _EmptySectionCard(
                                message: 'No upcoming trips right now',
                              )
                            else
                              ...data.upcomingTrips.map(
                                (t) => _RideCard(trip: t, isCurrent: false),
                              ),
                          ],
                          const SizedBox(height: 16),

                          // Past Trips
                          _SectionHeader(
                            title: 'Past Trips',
                            count: data.tripHistory.length,
                            isExpanded: _showPast,
                            onToggle: () =>
                                setState(() => _showPast = !_showPast),
                          ),
                          if (_showPast) ...[
                            const SizedBox(height: 16),
                            if (data.tripHistory.isEmpty)
                              _EmptySectionCard(
                                message: 'No completed trips yet',
                              )
                            else
                              ...data.tripHistory.map(
                                (t) => _RideCard(trip: t, isCurrent: false),
                              ),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/chat'),
          label: const Text('Chat'),
          icon: const Icon(Icons.chat_rounded),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  final String message;

  const _EmptySectionCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.event_note_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatefulWidget {
  final CrewTripDto trip;
  final bool isCurrent;

  const _RideCard({required this.trip, required this.isCurrent});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    if (widget.isCurrent) {
      _blinkController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = widget.trip.status.toLowerCase();
    final isActionable =
        widget.isCurrent || status == 'upcoming' || status == 'scheduled';

    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        return FadeTransition(
          opacity: widget.isCurrent
              ? Tween<double>(begin: 0.6, end: 1.0).animate(_blinkController)
              : const AlwaysStoppedAnimation(1.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: widget.isCurrent
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(
                            alpha: 0.2 + (_blinkController.value * 0.2),
                          ),
                          blurRadius: 8 + (_blinkController.value * 8),
                          spreadRadius: _blinkController.value * 2,
                        ),
                      ]
                    : null,
              ),
              child: Card(
                elevation: widget.isCurrent ? 2 : 0,
                color: widget.isCurrent
                    ? cs.surfaceContainerHigh
                    : cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: widget.isCurrent
                        ? cs.primary.withValues(
                            alpha: 0.5 + (_blinkController.value * 0.5),
                          )
                        : cs.outlineVariant,
                    width: widget.isCurrent ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );
      },
      child: InkWell(
        onTap: isActionable
            ? () {
                if (widget.isCurrent) {
                  Navigator.pushNamed(
                    context,
                    '/active-ride',
                    arguments: {'tripId': widget.trip.id},
                  );
                } else {
                  if (status == 'upcoming' || status == 'scheduled') {
                    Navigator.pushNamed(
                      context,
                      '/pre-ride-checkpoints',
                      arguments: {
                        'tripId': widget.trip.id,
                        'jobId': widget.trip.jobId,
                        'truckPlateNumber': widget.trip.truckPlateNumber,
                        'destinationName': widget.trip.destinationName,
                        'destinationAddress': widget.trip.destinationAddress,
                        'dispatchOriginTime': widget.trip.dispatchOriginTime,
                        'scheduledDate': widget.trip.scheduledDate
                            .toIso8601String(),
                      },
                    );
                  }
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.primary.withValues(
                            alpha: _blinkController.value,
                          ),
                        ),
                      ),
                      child: Text(
                        'ON THE WAY',
                        style: tt.bodyLarge?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black87, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_shipping_rounded,
                          size: 14,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.trip.truckPlateNumber.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.black87,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.outline, width: 3),
                        ),
                      ),
                      Container(width: 2, height: 40, color: cs.outlineVariant),
                      Icon(
                        Icons.location_on,
                        color: widget.isCurrent
                            ? cs.error
                            : cs.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pickup Point', style: tt.bodySmall),
                        Row(
                          children: [
                            Text(
                              widget.trip.dispatchOriginTime,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                DateFormat(
                                  isActionable ? 'MMM dd' : 'MMM dd, yyyy',
                                ).format(widget.trip.scheduledDate),
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Drop-off Point', style: tt.bodySmall),
                        Text(
                          widget.trip.destinationName,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.trip.destinationAddress,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.isCurrent)
                Divider(color: cs.outlineVariant.withValues(alpha: 0.6)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.trip.jobId,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (widget.isCurrent)
                    Row(
                      children: [
                        Text(
                          'Open Trip',
                          style: tt.labelLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                      ],
                    )
                  else if (isActionable)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Final attempt to fix compiler sync
