import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_picker_helper.dart';
import '../main.dart';
import '../models/trip.dart';
import '../services/offline_sync_service.dart';

class AddTollScreen extends StatefulWidget {
  const AddTollScreen({super.key});

  @override
  State<AddTollScreen> createState() => _AddTollScreenState();
}

class _AddTollScreenState extends State<AddTollScreen> {
  int _currentStep = 0;
  final _amountController = TextEditingController();
  final _plazaController = TextEditingController();
  final _customExpresswayController = TextEditingController();
  final _notesController = TextEditingController();

  XFile? _receiptPhoto;
  String _tripId = 'unknown';
  bool _isSubmitting = false;

  String? _selectedExpressway;
  final List<String> _expressways = [
    'NLEX',
    'SLEX',
    'SCTEX',
    'TPLEX',
    'CALAX',
    'CAVITEX',
    'NAIAX',
    'SKYWAY',
    'MCX',
    'STAR Toll',
    'Others',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _tripId = args;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _plazaController.dispose();
    _customExpresswayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePickerHelper.showImageSourceDialog(context);
    if (image != null) {
      setState(() => _receiptPhoto = image);
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_receiptPhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a photo of the toll receipt'),
          ),
        );
        return false;
      }
      return true;
    }

    if (_currentStep == 1) {
      if (_selectedExpressway == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an expressway')),
        );
        return false;
      }
      if (_selectedExpressway == 'Others' &&
          _customExpresswayController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify the expressway name')),
        );
        return false;
      }
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid toll amount')),
        );
        return false;
      }
      return true;
    }

    if (_currentStep == 2) {
      if (_plazaController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the toll plaza or location'),
          ),
        );
        return false;
      }
      return true;
    }

    return true;
  }

  Future<void> _submitToll() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSubmitting = true);

    try {
      final bytes = await _receiptPhoto!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final expressway = _selectedExpressway == 'Others'
          ? _customExpresswayController.text
          : _selectedExpressway!;

      final location = '$expressway - ${_plazaController.text.trim()}';

      final request = AddTripExpenseRequest(
        expenseType: 1, // Toll
        amount: double.parse(_amountController.text),
        location: location,
        receiptImage: base64Image,
        notes: _notesController.text.trim(),
      );

      await apiService.addExpense(_tripId, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toll receipt saved.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          // Save for offline sync
          try {
            final bytes = await _receiptPhoto!.readAsBytes();
            final base64Image = base64Encode(bytes);
            final expressway = _selectedExpressway == 'Others'
                ? _customExpresswayController.text
                : _selectedExpressway!;
            final location = '$expressway - ${_plazaController.text.trim()}';

            final request = AddTripExpenseRequest(
              expenseType: 1, // Toll
              amount: double.parse(_amountController.text),
              location: location,
              receiptImage: base64Image,
              notes: _notesController.text.trim(),
            );

            await offlineSyncService.savePendingExpense(_tripId, request);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Saved offline. Will sync when connection is restored.',
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
              Navigator.pop(context);
            }
            return;
          } catch (_) {}
        }

        setState(() => _isSubmitting = false);
        final message = await apiService.getErrorMessage(e);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save toll receipt: $message')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save toll receipt: $message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Toll Receipt')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_validateCurrentStep()) {
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            } else {
              _submitToll();
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: (_isSubmitting ||
                            (_currentStep == 0 && _receiptPhoto == null))
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
                        : Text(isLast ? 'SUBMIT TOLL' : 'CONTINUE'),
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
        },
        steps: [
          Step(
            title: const Text('Receipt Photo'),
            subtitle: const Text('Capture the toll receipt'),
            isActive: _currentStep >= 0,
            state: _receiptPhoto != null
                ? StepState.complete
                : StepState.indexed,
            content: _buildPhotoStep(),
          ),
          Step(
            title: const Text('Expressway & Amount'),
            subtitle: const Text('Select route and enter cost'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildExpresswayStep(),
          ),
          Step(
            title: const Text('Toll Plaza'),
            subtitle: const Text('Specify the exact location'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildPlazaStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      children: [
        if (_receiptPhoto != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(_receiptPhoto!.path),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.camera_alt),
          label: Text(
            _receiptPhoto != null ? 'Change Photo' : 'Capture Receipt',
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
      ],
    );
  }

  Widget _buildExpresswayStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Expressway',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: _expressways.map((expressway) {
            final isSelected = _selectedExpressway == expressway;
            return ChoiceChip(
              label: Text(expressway),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedExpressway = selected ? expressway : null;
                });
              },
            );
          }).toList(),
        ),
        if (_selectedExpressway == 'Others') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _customExpresswayController,
            decoration: const InputDecoration(
              labelText: 'Specify Expressway',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        TextFormField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: 'Toll Amount (PHP)',
            prefixIcon: Icon(Icons.payments),
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildPlazaStep() {
    return Column(
      children: [
        TextFormField(
          controller: _plazaController,
          decoration: const InputDecoration(
            labelText: 'Toll Plaza / Location',
            prefixIcon: Icon(Icons.edit_road),
            hintText: 'e.g. Balintawak, Ayala, Bocaue',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Additional Notes / Remarks',
            prefixIcon: Icon(Icons.note),
            hintText: 'Any other details about this toll',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_selectedExpressway ?? ""} - PHP ${_amountController.text}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
