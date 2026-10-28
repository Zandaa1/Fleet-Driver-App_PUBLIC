import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/enums.dart';
import '../models/trip.dart';
import '../utils/image_picker_helper.dart';

class PreRideCheckpointsScreen extends StatefulWidget {
  const PreRideCheckpointsScreen({super.key});

  @override
  State<PreRideCheckpointsScreen> createState() =>
      _PreRideCheckpointsScreenState();
}

class _PreRideCheckpointsScreenState extends State<PreRideCheckpointsScreen> {
  String? _tripId;
  String? _jobId;
  String? _truckPlateNumber;
  String? _destinationName;
  String? _destinationAddress;
  String? _dispatchOriginTime;
  DateTime? _scheduledDate;

  bool _arrivedDone = false;
  bool _startLoadingDone = false;
  bool _completeLoadingDone = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tripId != null) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final tripId = args['tripId'];
      if (tripId is String && tripId.isNotEmpty) {
        _tripId = tripId;
        _loadPersistedState();
      }

      _jobId = args['jobId'] as String?;
      _truckPlateNumber = args['truckPlateNumber'] as String?;
      _destinationName = args['destinationName'] as String?;
      _destinationAddress = args['destinationAddress'] as String?;
      _dispatchOriginTime = args['dispatchOriginTime'] as String?;
      final rawDate = args['scheduledDate'];
      if (rawDate is String) {
        _scheduledDate = DateTime.tryParse(rawDate);
      }
    } else if (args is String && args.isNotEmpty) {
      _tripId = args;
      _loadPersistedState();
    }
  }

  Future<void> _loadPersistedState() async {
    if (_tripId == null) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _arrivedDone = prefs.getBool('checkpoint_${_tripId}_arrived') ?? false;
      _startLoadingDone =
          prefs.getBool('checkpoint_${_tripId}_start_loading') ?? false;
      _completeLoadingDone =
          prefs.getBool('checkpoint_${_tripId}_complete_loading') ?? false;
    });
  }

  Future<void> _savePersistedState(TripCheckpointType type) async {
    if (_tripId == null) return;
    final prefs = await SharedPreferences.getInstance();
    String key = '';
    if (type == TripCheckpointType.arrived) {
      key = 'checkpoint_${_tripId}_arrived';
    }
    if (type == TripCheckpointType.startLoading) {
      key = 'checkpoint_${_tripId}_start_loading';
    }
    if (type == TripCheckpointType.completeLoading) {
      key = 'checkpoint_${_tripId}_complete_loading';
    }
    if (key.isNotEmpty) await prefs.setBool(key, true);
  }

  bool get _hasValidTripId => _tripId != null && _tripId!.isNotEmpty;

  int _checkpointApiType(TripCheckpointType type) {
    switch (type) {
      case TripCheckpointType.arrived:
        return 0;
      case TripCheckpointType.startLoading:
        return 1;
      case TripCheckpointType.completeLoading:
        return 2;
      case TripCheckpointType.other:
        return 3;
    }
  }

  String get _scheduledLabel {
    if (_scheduledDate == null) {
      return '-';
    }
    return DateFormat('MMM dd, yyyy').format(_scheduledDate!.toLocal());
  }

  Future<String?> _pickCheckpointImageBase64() async {
    final XFile? image = await ImagePickerHelper.showImageSourceDialog(context);
    if (image == null) {
      return null;
    }

    final confirmed = await _confirmCheckpointPhoto(image);
    if (confirmed != true) {
      return null;
    }

    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<bool?> _confirmCheckpointPhoto(XFile image) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this photo?'),
        content: SizedBox(
          width: 300, // Explicit width for IntrinsicWidth parent
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(image.path), height: 220, fit: BoxFit.cover),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retake'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCheckpoint(TripCheckpointType type) async {
    if (!_hasValidTripId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Trip details are missing. Please open the trip again.',
            ),
          ),
        );
      }
      return;
    }

    final image = await _pickCheckpointImageBase64();
    if (image == null || image.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please take a photo before continuing.'),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await apiService.submitCheckpoint(
        _tripId!,
        SubmitCheckpointRequest(
          checkpointType: _checkpointApiType(type),
          image: image,
          notes: 'Operational checkpoint update',
        ),
      );

      await _savePersistedState(type);

      setState(() {
        if (type == TripCheckpointType.arrived) {
          _arrivedDone = true;
        }
        if (type == TripCheckpointType.startLoading) {
          _startLoadingDone = true;
        }
        if (type == TripCheckpointType.completeLoading) {
          _completeLoadingDone = true;
        }
      });
    } on DioException catch (e) {
      if (mounted) {
        final message = await apiService.getErrorMessage(e);
        if (!mounted) return;
        if (message.contains('already been submitted') ||
            message.contains('already exists')) {
          // Notify user and mark as done locally
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This step was already submitted earlier. Moving to next step.',
              ),
              backgroundColor: Colors.blue,
            ),
          );

          await _savePersistedState(type);

          setState(() {
            if (type == TripCheckpointType.arrived) _arrivedDone = true;
            if (type == TripCheckpointType.startLoading) {
              _startLoadingDone = true;
            }
            if (type == TripCheckpointType.completeLoading) {
              _completeLoadingDone = true;
            }
          });
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } catch (e) {
      if (mounted) {
        final message = await apiService.getErrorMessage(
          e is DioException
              ? e
              : DioException(requestOptions: RequestOptions(), error: e),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save this step: $message')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _goToStartTripSetup() async {
    if (!_hasValidTripId || !_completeLoadingDone) {
      return;
    }

    if (!mounted) return;

    await Navigator.pushReplacementNamed(
      context,
      '/pre-ride',
      arguments: {
        'tripId': _tripId!,
        'jobId': _jobId,
        'truckPlateNumber': _truckPlateNumber,
        'destinationName': _destinationName,
        'destinationAddress': _destinationAddress,
        'dispatchOriginTime': _dispatchOriginTime,
        'scheduledDate': _scheduledDate?.toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Before You Start')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          _buildFlowStepper(isStep1Active: true),
          const SizedBox(height: 32),
          _buildPrimaryInfoCard(tt, cs),
          const SizedBox(height: 40),
          _buildStepsHeader(tt),
          const SizedBox(height: 20),
          // Vertical Timeline Steps
          _WorkflowStep(
            number: 1,
            label: 'Arrived at Pickup',
            isDone: _arrivedDone,
            isCurrent: !_arrivedDone,
            isLast: false,
            enabled: !_isSubmitting,
            onTap: () => _submitCheckpoint(TripCheckpointType.arrived),
          ),
          _WorkflowStep(
            number: 2,
            label: 'Loading Started',
            isDone: _startLoadingDone,
            isCurrent: _arrivedDone && !_startLoadingDone,
            isLast: false,
            enabled: _arrivedDone && !_isSubmitting,
            onTap: () => _submitCheckpoint(TripCheckpointType.startLoading),
          ),
          _WorkflowStep(
            number: 3,
            label: 'Loading Finished',
            isDone: _completeLoadingDone,
            isCurrent: _startLoadingDone && !_completeLoadingDone,
            isLast: true,
            enabled: _startLoadingDone && !_isSubmitting,
            onTap: () => _submitCheckpoint(TripCheckpointType.completeLoading),
          ),
          const SizedBox(height: 48),
          // Final Action Button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _completeLoadingDone ? 1.0 : 0.5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: _completeLoadingDone
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: FilledButton(
                onPressed:
                    (_isSubmitting || !_completeLoadingDone || !_hasValidTripId)
                    ? null
                    : _goToStartTripSetup,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(84),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'PROCEED TO TRIP SETUP',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.rocket_launch_rounded,
                            size: 28,
                            color: cs.onPrimary,
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStepsHeader(TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        'PICKUP STEPS',
        style: tt.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildPrimaryInfoCard(TextTheme tt, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _destinationName?.toUpperCase() ?? 'DESTINATION',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _destinationAddress ?? 'No address provided',
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    _buildGridItem(
                      cs,
                      Icons.local_shipping,
                      'Truck',
                      _truckPlateNumber ?? '-',
                    ),
                    _buildGridItem(
                      cs,
                      Icons.access_time_filled,
                      'Pickup',
                      _dispatchOriginTime ?? '-',
                    ),
                    _buildGridItem(
                      cs,
                      Icons.calendar_month,
                      'Scheduled',
                      _scheduledLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ExpansionTile(
            title: Text(
              'View Reference Details',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            expandedAlignment: Alignment.centerLeft,
            children: [
              _detailRow('Trip Reference No', _tripId ?? '-'),
              _detailRow('Job Reference No', _jobId ?? '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    ColorScheme cs,
    IconData icon,
    String label,
    String value,
  ) {
    final isTruck = label.toUpperCase() == 'TRUCK';

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: cs.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          if (isTruck)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black87, width: 1.5),
              ),
              child: Text(
                value.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStepper({required bool isStep1Active}) {
    final cs = Theme.of(context).colorScheme;

    Widget stepIndicator(int number, String label, bool done, bool active) {
      return Expanded(
        child: Column(
          children: [
            Row(
              children: [
                if (number > 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done || active ? cs.primary : cs.outlineVariant,
                    ),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? cs.primary
                        : active
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    border: active && !done
                        ? Border.all(color: cs.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Text(
                            '$number',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: done || active
                                  ? Colors.white
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                if (number < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done ? cs.primary : cs.outlineVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: done || active ? FontWeight.w900 : FontWeight.w600,
                color: done || active ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final step1Done = _completeLoadingDone;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stepIndicator(1, 'PICKUP', step1Done, isStep1Active),
          stepIndicator(2, 'START TRIP', false, false),
        ],
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  final int number;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  final bool enabled;
  final VoidCallback onTap;

  const _WorkflowStep({
    required this.number,
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDone
                      ? Colors.green
                      : (isCurrent ? cs.primary : cs.surfaceContainerHighest),
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: cs.primary, width: 2)
                      : null,
                ),
                child: Icon(
                  isDone
                      ? Icons.check
                      : (isCurrent ? Icons.camera_alt : Icons.lock_outline),
                  color: isDone || isCurrent
                      ? Colors.white
                      : cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    color: isDone ? Colors.green : cs.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // Task Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: InkWell(
                onTap: (isDone || !enabled) ? null : onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? cs.primaryContainer.withValues(alpha: 0.3)
                        : (isDone
                              ? cs.surfaceContainerLow
                              : cs.surfaceContainerLowest),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCurrent ? cs.primary : cs.outlineVariant,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: tt.titleLarge?.copyWith(
                                fontWeight: isCurrent
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isCurrent ? cs.primary : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isDone
                                  ? 'Checkpoint completed'
                                  : (isCurrent
                                        ? 'Tap to capture proof'
                                        : 'Waiting for previous steps'),
                              style: tt.bodyMedium?.copyWith(
                                color: isCurrent
                                    ? cs.primary.withValues(alpha: 0.7)
                                    : cs.onSurfaceVariant,
                                fontWeight: isCurrent ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
