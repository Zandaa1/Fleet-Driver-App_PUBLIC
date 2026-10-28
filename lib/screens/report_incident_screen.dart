import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import '../models/trip.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String _mainCategory = 'Abnormality';
  String? _selectedSubType;
  bool _isSubmitting = false;
  String _tripId = 'unknown';

  final Map<String, List<String>> _incidentTree = {
    'Abnormality': [
      'Heavy Traffic',
      'Road Closure/Diversion',
      'Bad Weather',
      'Vehicle Minor Issue',
      'Police Checkpoint',
      'Other Delay',
    ],
    'Emergency': [
      'Accident',
      'Vehicle Breakdown',
      'Medical Emergency',
      'Safety Threat / Panic',
      'Severe Traffic / Road Blockage',
      'Other Emergency',
    ],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _tripId = args;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _notesRequired {
    if (_selectedSubType == null) return false;
    return _selectedSubType!.contains('Other');
  }

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate() || _selectedSubType == null) {
      if (_selectedSubType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an incident type')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {}

      // Mapping: Abnormality -> 0, Emergency -> 1
      final categoryInt = _mainCategory == 'Emergency' ? 1 : 0;

      final request = ReportIncidentRequest(
        category: categoryInt,
        incidentType: _selectedSubType!,
        notes: _notesController.text.trim(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      await apiService.reportIncident(_tripId, request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident report sent to dispatch.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final message = await apiService.getErrorMessage(e is DioException ? e : DioException(requestOptions: RequestOptions(), error: e));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send report: $message')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subTypes = _incidentTree[_mainCategory]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            const Text(
              'Select Severity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _SeverityToggle(
                  label: 'Abnormality',
                  icon: Icons.info_outline,
                  color: Colors.orange,
                  isSelected: _mainCategory == 'Abnormality',
                  onTap: () => setState(() {
                    _mainCategory = 'Abnormality';
                    _selectedSubType = null;
                  }),
                ),
                const SizedBox(width: 12),
                _SeverityToggle(
                  label: 'Emergency',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red,
                  isSelected: _mainCategory == 'Emergency',
                  onTap: () => setState(() {
                    _mainCategory = 'Emergency';
                    _selectedSubType = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Type of $_mainCategory',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: subTypes.map((type) {
                final isSelected = _selectedSubType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: _mainCategory == 'Emergency'
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    setState(() => _selectedSubType = selected ? type : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _notesRequired
                    ? 'Details (Required)'
                    : 'Details / Notes (Optional)',
                hintText: 'Provide more context for dispatch...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.notes),
              ),
              validator: (v) {
                if (_notesRequired && (v == null || v.trim().isEmpty)) {
                  return 'Notes are required for this incident type';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitIncident,
                style: FilledButton.styleFrom(
                  backgroundColor: _mainCategory == 'Emergency'
                      ? Colors.red
                      : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting
                      ? 'SENDING REPORT...'
                      : 'SUBMIT ${_mainCategory.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
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

class _SeverityToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SeverityToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
