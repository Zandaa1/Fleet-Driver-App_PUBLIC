import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

import '../main.dart';
import '../models/trip.dart';
import '../utils/image_picker_helper.dart';

class DeliveryCheckpointsScreen extends StatefulWidget {
  const DeliveryCheckpointsScreen({super.key});

  @override
  State<DeliveryCheckpointsScreen> createState() =>
      _DeliveryCheckpointsScreenState();
}

class _DeliveryCheckpointsScreenState extends State<DeliveryCheckpointsScreen> {
  String? _tripId;
  int _currentStep = 0;
  final Map<int, XFile?> _stepImages = {};
  final List<bool> _stepsCompleted = [false, false, false];
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tripId == null) {
      _tripId = _extractTripId();
      if (_tripId != null) {
        _loadPersistedState();
      }
    }
  }

  Future<void> _loadPersistedState() async {
    if (_tripId == null) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stepsCompleted[0] = prefs.getBool('arrival_${_tripId}_step_0') ?? false;
      _stepsCompleted[1] = prefs.getBool('arrival_${_tripId}_step_1') ?? false;
      _stepsCompleted[2] = prefs.getBool('arrival_${_tripId}_step_2') ?? false;

      // Automatically move to the first incomplete step
      if (_stepsCompleted[2]) {
        _currentStep = 2;
      } else if (_stepsCompleted[1]) {
        _currentStep = 2;
      } else if (_stepsCompleted[0]) {
        _currentStep = 1;
      }
    });
  }

  Future<void> _savePersistedState(int stepIndex) async {
    if (_tripId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('arrival_${_tripId}_step_$stepIndex', true);
  }

  String? _extractTripId() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) return args;
    if (args is Map && args['tripId'] is String) {
      return args['tripId'] as String;
    }
    return null;
  }

  Future<void> _pickImageForStep(int index) async {
    final XFile? image = await ImagePickerHelper.showImageSourceDialog(context);
    if (image != null) {
      setState(() => _stepImages[index] = image);
    }
  }

  Future<void> _submitCurrentStep() async {
    final image = _stepImages[_currentStep];
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // checkpointType mapping: Step 0->3, 1->4, 2->5
      final type = _currentStep + 3;

      await apiService.submitCheckpoint(
        _tripId!,
        SubmitCheckpointRequest(
          checkpointType: type,
          image: base64Image,
          notes: 'Arrival step ${_currentStep + 1}',
        ),
      );

      await _savePersistedState(_currentStep);

      setState(() {
        _stepsCompleted[_currentStep] = true;
        _isSubmitting = false;
        if (_currentStep < 2) _currentStep++;
      });
    } on DioException catch (e) {
      final message = await apiService.getErrorMessage(e);
      if (message.contains('already been submitted') ||
          message.contains('already exists')) {
        await _savePersistedState(_currentStep);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Step already submitted earlier, continuing...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() {
          _stepsCompleted[_currentStep] = true;
          _isSubmitting = false;
          if (_currentStep < 2) _currentStep++;
        });
      } else {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        final message = await apiService.getErrorMessage(
          e is DioException ? e : DioException(requestOptions: RequestOptions(), error: e),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $message')),
          );
        }
      }
    }
  }

  Future<void> _openPostRide() async {
    if (_tripId == null) return;
    final result = await Navigator.pushNamed(
      context,
      '/post-ride',
      arguments: _tripId!,
    );
    if (result == true && mounted) {
      Future.microtask(() {
        DashboardScreen.dashboardKey.currentState?.refresh();
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arrival Steps')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (step) {
          if (_stepsCompleted[step] || step <= _currentStep) {
            setState(() => _currentStep = step);
          }
        },
        onStepContinue: () {
          if (_stepsCompleted[_currentStep]) {
            if (_currentStep < 2) setState(() => _currentStep++);
            return;
          }
          _submitCurrentStep();
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: _buildStepperControls,
        steps: [
          _buildStep(
            0,
            'Arrived at Drop-off',
            'Take a photo of the truck at the destination',
          ),
          _buildStep(
            1,
            'Unloading Started',
            'Take a photo showing unloading has begun',
          ),
          _buildStep(
            2,
            'Unloading Finished',
            'Take a photo showing the empty truck/manifest',
          ),
        ],
      ),
    );
  }

  Step _buildStep(int index, String title, String subtitle) {
    final image = _stepImages[index];
    return Step(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      isActive: _currentStep >= index,
      state: _stepsCompleted[index] ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(image.path),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : () => _pickImageForStep(index),
            icon: const Icon(Icons.camera_alt),
            label: Text(image != null ? 'Change Photo' : 'Capture Photo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperControls(BuildContext context, ControlsDetails details) {
    final isLast = _currentStep == 2;
    final isStepDone = _stepsCompleted[_currentStep];

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          if (!isStepDone)
            Expanded(
              child: FilledButton(
                onPressed: (_isSubmitting || _stepImages[_currentStep] == null)
                    ? null
                    : details.onStepContinue,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SUBMIT STEP'),
              ),
            )
          else if (isLast)
            Expanded(
              child: FilledButton.icon(
                onPressed: _openPostRide,
                icon: const Icon(Icons.check_circle),
                label: const Text('FINISH TRIP'),
              ),
            )
          else
            Expanded(
              child: FilledButton(
                onPressed: details.onStepContinue,
                child: const Text('NEXT STEP'),
              ),
            ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : details.onStepCancel,
              child: const Text('BACK'),
            ),
          ],
        ],
      ),
    );
  }
}
