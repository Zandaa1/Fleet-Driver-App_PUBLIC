import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import '../utils/image_picker_helper.dart';
import '../main.dart';
import '../models/trip.dart';

class PreRideScreen extends StatefulWidget {
  const PreRideScreen({super.key});

  @override
  State<PreRideScreen> createState() => _PreRideScreenState();
}

class _PreRideScreenState extends State<PreRideScreen> {
  XFile? _truckExteriorPhoto;
  XFile? _odometerPhoto;
  XFile? _manifestPhoto;
  XFile? _fuelDetailsPhoto;
  bool _isSubmitting = false;

  final _mileageController = TextEditingController(text: '0');
  final _fuelLitersController = TextEditingController(text: '0');

  String? _tripId;
  String? _jobId;
  String? _truckPlateNumber;
  String? _destinationName;
  String? _destinationAddress;
  String? _dispatchOriginTime;
  DateTime? _scheduledDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tripId != null) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args['tripId'] is String) {
        _tripId = args['tripId'] as String;
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
    } else if (args is String) {
      _tripId = args;
    }
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _fuelLitersController.dispose();
    super.dispose();
  }

  bool get _hasValidTripId => _tripId != null && _tripId!.isNotEmpty;

  String get _scheduledLabel {
    if (_scheduledDate == null) {
      return '-';
    }
    return DateFormat('MMM dd, yyyy').format(_scheduledDate!.toLocal());
  }

  int get _completedCount =>
      (_truckExteriorPhoto != null ? 1 : 0) +
      (_odometerPhoto != null ? 1 : 0) +
      (_manifestPhoto != null ? 1 : 0) +
      (_fuelDetailsPhoto != null ? 1 : 0);

  bool get _allCompleted => _completedCount == 4;

  Future<String> _toBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await ImagePickerHelper.showImageSourceDialog(context);
    if (image != null) {
      setState(() {
        if (type == 'truck') {
          _truckExteriorPhoto = image;
        } else if (type == 'odometer') {
          _odometerPhoto = image;
        } else if (type == 'manifest') {
          _manifestPhoto = image;
        } else if (type == 'fuel') {
          _fuelDetailsPhoto = image;
        }
      });
    }
  }

  Future<void> _submitAndStart() async {
    if (!_hasValidTripId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trip details are missing. Please open the trip again.',
          ),
        ),
      );
      return;
    }

    if (!_allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add all 4 required photos.')),
      );
      return;
    }

    final startingMileage = int.tryParse(_mileageController.text);
    if (startingMileage == null || startingMileage < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid starting odometer reading.'),
        ),
      );
      return;
    }

    final fuelLiters = double.tryParse(_fuelLitersController.text);
    if (fuelLiters == null || fuelLiters < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid fuel amount in liters.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final truckBase64 = await _toBase64(_truckExteriorPhoto!);
      final odometerBase64 = await _toBase64(_odometerPhoto!);
      final manifestBase64 = await _toBase64(_manifestPhoto!);
      final fuelBase64 = await _toBase64(_fuelDetailsPhoto!);

      final request = StartTripRequest(
        preRideExteriorImages: [truckBase64],
        startingMileage: startingMileage,
        preRideOdometerImage: odometerBase64,
        preRideManifestImages: [manifestBase64],
        gasolineLiters: fuelLiters.toString(),
        fuelImage: fuelBase64,
      );

      await apiService.startTrip(_tripId!, request);

      // Refresh dashboard in background
      DashboardScreen.dashboardKey.currentState?.refresh();

      if (!mounted) return;

      await Navigator.pushReplacementNamed(
        context,
        '/active-ride',
        arguments: {'autoStart': true, 'tripId': _tripId!},
      );
    } on DioException catch (e) {
      final message = await apiService.getErrorMessage(e);
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start the trip: $message')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final message = await apiService.getErrorMessage(
          e is DioException
              ? e
              : DioException(requestOptions: RequestOptions(), error: e),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start the trip: $message')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Before You Drive')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          _buildFlowStepper(),
          const SizedBox(height: 32),
          _buildPrimaryInfoCard(tt, cs),
          const SizedBox(height: 40),
          _buildSectionHeader(tt, 'VEHICLE METRICS'),
          const SizedBox(height: 20),
          _buildInputFields(),
          const SizedBox(height: 40),
          _buildSectionHeader(tt, 'INSPECTION PHOTOS'),
          const SizedBox(height: 20),
          _ChecklistItem(
            icon: Icons.local_shipping,
            title: 'Truck Exterior',
            subtitle: 'Take a photo of the truck condition',
            isCompleted: _truckExteriorPhoto != null,
            imageFile: _truckExteriorPhoto,
            onTap: () => _pickImage('truck'),
          ),
          _ChecklistItem(
            icon: Icons.speed,
            title: 'Odometer Reading',
            subtitle: 'Take a photo of the starting odometer',
            isCompleted: _odometerPhoto != null,
            imageFile: _odometerPhoto,
            onTap: () => _pickImage('odometer'),
          ),
          _ChecklistItem(
            icon: Icons.description,
            title: 'Manifest Photo',
            subtitle: 'Take a photo of the delivery manifest',
            isCompleted: _manifestPhoto != null,
            imageFile: _manifestPhoto,
            onTap: () => _pickImage('manifest'),
          ),
          _ChecklistItem(
            icon: Icons.local_gas_station,
            title: 'Fuel Details',
            subtitle: 'Take a photo of fuel details or receipt',
            isCompleted: _fuelDetailsPhoto != null,
            imageFile: _fuelDetailsPhoto,
            onTap: () => _pickImage('fuel'),
          ),
          const SizedBox(height: 48),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: _allCompleted
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
              onPressed: (_isSubmitting || !_allCompleted || !_hasValidTripId)
                  ? null
                  : _submitAndStart,
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
                          'START TRIP',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.local_shipping_rounded,
                          size: 28,
                          color: cs.onPrimary,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(TextTheme tt, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: tt.titleMedium?.copyWith(
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
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStepper() {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stepIndicator(1, 'PICKUP', true, false),
          stepIndicator(2, 'START TRIP', false, true),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _mileageController,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: 'Starting Odometer',
                prefixIcon: Icon(Icons.speed, color: cs.primary),
                suffixText: 'KM',
                suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: cs.surface,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fuelLitersController,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: 'Fuel at Start',
                prefixIcon: Icon(Icons.local_gas_station, color: cs.primary),
                suffixText: 'L',
                suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: cs.surface,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final XFile? imageFile;
  final VoidCallback onTap;

  const _ChecklistItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.imageFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted
                ? cs.primaryContainer.withValues(alpha: 0.2)
                : cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompleted ? cs.primary : cs.outlineVariant,
              width: isCompleted ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : icon,
                  color: isCompleted ? Colors.white : cs.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? cs.primary : cs.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imageFile!.path),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(Icons.camera_alt_outlined, color: cs.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
