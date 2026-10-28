import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_picker_helper.dart';
import '../main.dart';
import '../models/trip.dart';

class PostRideScreen extends StatefulWidget {
  const PostRideScreen({super.key});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  XFile? _truckExteriorPhoto;
  XFile? _odometerPhoto;
  XFile? _manifestPhoto;
  bool _locationConfirmed = false;
  bool _isSubmitting = false;

  final _odometerController = TextEditingController(text: '0');
  String? _tripId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  void dispose() {
    _odometerController.dispose();
    super.dispose();
  }

  int get _completedCount =>
      (_truckExteriorPhoto != null ? 1 : 0) +
      (_odometerPhoto != null ? 1 : 0) +
      (_manifestPhoto != null ? 1 : 0) +
      (_locationConfirmed ? 1 : 0);

  bool get _allCompleted =>
      _truckExteriorPhoto != null &&
      _odometerPhoto != null &&
      _manifestPhoto != null &&
      _locationConfirmed;

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
        }
      });
    }
  }

  Future<void> _handleComplete() async {
    if (!_allCompleted || _tripId == null) return;

    final endingMileage = int.tryParse(_odometerController.text);
    if (endingMileage == null || endingMileage < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid odometer reading')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = CompleteTripRequest(
        endingMileage: endingMileage,
        postRideExteriorImages: [await _toBase64(_truckExteriorPhoto!)],
        postRideOdometerImages: [await _toBase64(_odometerPhoto!)],
        postRideManifestImages: [await _toBase64(_manifestPhoto!)],
      );

      await apiService.completeTrip(_tripId!, request);
      if (mounted) Navigator.pop(context, true);
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
        ).showSnackBar(SnackBar(content: Text('Could not finish trip: $message')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Completion Check'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(color: cs.surfaceContainerLow),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_turned_in_rounded,
                        color: cs.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'FINAL VERIFICATION',
                        style: tt.labelLarge?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Almost Done!',
                    style: tt.headlineMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please complete the mandatory photo proofs and metrics before submitting.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _completedCount / 4,
                      minHeight: 12,
                      backgroundColor: cs.onPrimaryContainer.withValues(
                        alpha: 0.1,
                      ),
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_completedCount of 4 steps completed',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Odometer Input Section
            Text(
              'ODOMETER READING',
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _odometerController,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Ending Mileage',
                        hintText: 'Enter Odometer in KM',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.speed,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                        suffixText: 'KM',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Mandatory Photos Section
            Text(
              'MANDATORY PHOTO PROOFS',
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _ChecklistItem(
              icon: Icons.local_shipping_rounded,
              title: 'Truck Exterior',
              subtitle: 'Clear photo of the truck condition',
              isCompleted: _truckExteriorPhoto != null,
              imageFile: _truckExteriorPhoto,
              onTap: () => _pickImage('truck'),
            ),
            _ChecklistItem(
              icon: Icons.speed_rounded,
              title: 'Ending Odometer',
              subtitle: 'Legible photo of the dashboard',
              isCompleted: _odometerPhoto != null,
              imageFile: _odometerPhoto,
              onTap: () => _pickImage('odometer'),
            ),
            _ChecklistItem(
              icon: Icons.receipt_long_rounded,
              title: 'Signed Manifest',
              subtitle: 'Ensure all signatures are visible',
              isCompleted: _manifestPhoto != null,
              imageFile: _manifestPhoto,
              onTap: () => _pickImage('manifest'),
            ),

            const SizedBox(height: 24),

            // Location Confirmation
            InkWell(
              onTap: () => setState(() => _locationConfirmed = true),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _locationConfirmed
                      ? cs.primary.withValues(alpha: 0.1)
                      : cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _locationConfirmed ? cs.primary : cs.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _locationConfirmed
                          ? Icons.check_circle
                          : Icons.location_on_outlined,
                      color: _locationConfirmed
                          ? cs.primary
                          : cs.onSurfaceVariant,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm Arrival Location',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: _locationConfirmed
                                  ? cs.primary
                                  : cs.onSurface,
                            ),
                          ),
                          Text(
                            'Verify that you are at the correct drop-off point',
                            style: tt.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!_locationConfirmed)
                      Icon(
                        Icons.touch_app_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton(
                onPressed: (_isSubmitting || !_allCompleted)
                    ? null
                    : _handleComplete,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: _allCompleted
                      ? cs.primary
                      : cs.surfaceContainerHighest,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'FINISH TRIP & SUBMIT',
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCompleted ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  color: isCompleted ? cs.onPrimary : cs.onSurfaceVariant,
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
                        fontWeight: FontWeight.w900,
                        color: isCompleted ? cs.primary : cs.onSurface,
                      ),
                    ),
                    Text(subtitle, style: tt.bodySmall),
                  ],
                ),
              ),
              if (imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imageFile!.path),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
              else ...[
                Icon(Icons.add_a_photo_rounded, color: cs.primary, size: 24),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
