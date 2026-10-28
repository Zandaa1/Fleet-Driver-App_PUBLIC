import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_picker_helper.dart';
import '../main.dart';
import '../models/trip.dart';
import '../services/offline_sync_service.dart';

class FuelReceiptScreen extends StatefulWidget {
  const FuelReceiptScreen({super.key});

  @override
  State<FuelReceiptScreen> createState() => _FuelReceiptScreenState();
}

class _FuelReceiptScreenState extends State<FuelReceiptScreen> {
  int _currentStep = 0;

  final _totalPesosController = TextEditingController();
  final _pricePerLiterController = TextEditingController();
  final _litersController = TextEditingController();
  final _odometerController = TextEditingController();
  final _customStationController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  XFile? _receiptPhoto;
  String _tripId = 'unknown';
  bool _isSubmitting = false;

  String? _selectedStation;
  final List<String> _phStations = [
    'Petron',
    'Shell',
    'Caltex',
    'Phoenix',
    'Seaoil',
    'Cleanfuel',
    'Unioil',
    'Flying V',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _totalPesosController.addListener(_calculateLiters);
    _pricePerLiterController.addListener(_calculateLiters);
  }

  @override
  void dispose() {
    _totalPesosController.dispose();
    _pricePerLiterController.dispose();
    _litersController.dispose();
    _odometerController.dispose();
    _customStationController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateLiters() {
    final total = double.tryParse(_totalPesosController.text);
    final price = double.tryParse(_pricePerLiterController.text);

    if (total != null && price != null && price > 0) {
      final liters = total / price;
      final litersText = liters.toStringAsFixed(2);
      if (_litersController.text != litersText) {
        setState(() {
          _litersController.text = litersText;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _tripId = args;
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
            content: Text('Please provide a photo of the receipt'),
          ),
        );
        return false;
      }
      return true;
    }

    if (_currentStep == 1) {
      final total = double.tryParse(_totalPesosController.text) ?? 0;
      final price = double.tryParse(_pricePerLiterController.text) ?? 0;
      if (total <= 0 || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid total and price')),
        );
        return false;
      }
      return true;
    }

    if (_currentStep == 2) {
      final odometer = int.tryParse(_odometerController.text) ?? 0;
      if (odometer <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid odometer reading')),
        );
        return false;
      }
      if (_selectedStation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a gas station')),
        );
        return false;
      }
      if (_selectedStation == 'Others' &&
          _customStationController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify the station name')),
        );
        return false;
      }
      return true;
    }

    return true;
  }

  Future<void> _submitReceipt() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSubmitting = true);

    try {
      final bytes = await _receiptPhoto!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final brand = _selectedStation == 'Others'
          ? _customStationController.text
          : _selectedStation!;

      final location = '$brand - ${_locationController.text.trim()}';

      final request = AddTripExpenseRequest(
        expenseType: 0, // Fuel
        amount: double.parse(_totalPesosController.text),
        location: location,
        receiptImage: base64Image,
        notes: _notesController.text.trim(),
        liters: double.parse(_litersController.text),
        pricePerLiter: double.parse(_pricePerLiterController.text),
        odometer: int.parse(_odometerController.text),
        station: brand,
      );

      await apiService.addExpense(_tripId, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel receipt saved.'),
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
            final brand = _selectedStation == 'Others'
                ? _customStationController.text
                : _selectedStation!;
            final location = '$brand - ${_locationController.text.trim()}';

            final request = AddTripExpenseRequest(
              expenseType: 0,
              amount: double.parse(_totalPesosController.text),
              location: location,
              receiptImage: base64Image,
              notes: _notesController.text.trim(),
              liters: double.parse(_litersController.text),
              pricePerLiter: double.parse(_pricePerLiterController.text),
              odometer: int.parse(_odometerController.text),
              station: brand,
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
          SnackBar(content: Text('Could not save fuel receipt: $message')),
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
          SnackBar(content: Text('Could not save fuel receipt: $message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Fuel Receipt')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_validateCurrentStep()) {
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            } else {
              _submitReceipt();
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
                        : Text(isLast ? 'SUBMIT RECEIPT' : 'CONTINUE'),
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
            subtitle: const Text('Take a clear photo of your receipt'),
            isActive: _currentStep >= 0,
            state: _receiptPhoto != null
                ? StepState.complete
                : StepState.indexed,
            content: _buildPhotoStep(),
          ),
          Step(
            title: const Text('Pricing & Volume'),
            subtitle: const Text('Enter amounts and calculate liters'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildPricingStep(),
          ),
          Step(
            title: const Text('Trip & Station'),
            subtitle: const Text('Odometer and gas station info'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildLogisticsStep(),
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

  Widget _buildPricingStep() {
    return Column(
      children: [
        TextFormField(
          controller: _totalPesosController,
          decoration: const InputDecoration(
            labelText: 'Total Paid (PHP)',
            prefixIcon: Icon(Icons.payments),
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pricePerLiterController,
          decoration: const InputDecoration(
            labelText: 'Price per Liter (PHP)',
            prefixIcon: Icon(Icons.price_change),
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              const Icon(Icons.local_gas_station),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calculated Volume',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_litersController.text} Liters',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildLogisticsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _odometerController,
          decoration: const InputDecoration(
            labelText: 'Odometer Reading',
            prefixIcon: Icon(Icons.speed),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        const Text(
          'Gas Station Brand',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: _phStations.map((station) {
            final isSelected = _selectedStation == station;
            return ChoiceChip(
              label: Text(station),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedStation = selected ? station : null;
                });
              },
            );
          }).toList(),
        ),
        if (_selectedStation == 'Others') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _customStationController,
            decoration: const InputDecoration(
              labelText: 'Specify Station Name',
              hintText: 'e.g. Total, Filpride',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Station Location / Branch',
            prefixIcon: Icon(Icons.location_on),
            hintText: 'e.g. Quezon City, NLEX Northbound',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Additional Notes / Remarks',
            prefixIcon: Icon(Icons.note),
            hintText: 'Any other details about this purchase',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}
