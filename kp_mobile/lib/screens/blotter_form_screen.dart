import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/party_field.dart';

class BlotterFormScreen extends StatefulWidget {
  const BlotterFormScreen({super.key});

  @override
  State<BlotterFormScreen> createState() => _BlotterFormScreenState();
}

class _BlotterFormScreenState extends State<BlotterFormScreen> {
  // These lists must match BlotterController.php in Laravel.
  static const _incidentTypes = [
    'Physical Injury',
    'Theft',
    'Property Damage',
    'Threat',
    'Harassment',
    'Domestic Dispute',
    'Public Disturbance',
    'Noise Complaint',
    'Boundary Dispute',
    'Traffic Incident',
    'Lost and Found',
    'Other',
  ];
  static const _locations = [
    'Bliss',
    'Kalikasan',
    'Masipag',
    'Mesias',
    'Pag-asa',
    'San Miguel',
    'Outside Paraiso',
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _incidentBarangay = TextEditingController();
  final _incidentCity = TextEditingController();

  String? _type;
  String? _location;
  DateTime? _incidentAt;
  PartyValue? _respondent;
  PartyValue? _witness;
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _incidentBarangay.dispose();
    _incidentCity.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Format Laravel expects: 2026-10-07 14:30:00
  String _forApi(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}:00';

  String _forDisplay(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.year}-${_two(d.month)}-${_two(d.day)}   $hour:${_two(d.minute)} $ampm';
  }

  Future<void> _pickIncidentTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_incidentAt ?? now),
    );
    if (time == null) return;

    var picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isAfter(now)) picked = now; // an incident can't be in the future
    setState(() => _incidentAt = picked);
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save(); // fills _respondent and _witness

    if (_incidentAt == null) {
      _msg('Please choose when the incident happened.');
      return;
    }

    setState(() => _loading = true);
    try {
      final blotter = await ApiService.createBlotter({
        'blotter_title': _title.text.trim(),
        'blotter_details': _details.text.trim(),
        'incident_type': _type,
        'incident_at': _forApi(_incidentAt!),
        'incident_location': _location,
        if (_location == 'Outside Paraiso') ...{
          'incident_barangay': _incidentBarangay.text.trim(),
          'incident_city': _incidentCity.text.trim(),
        },
        'respondents': [_respondent!.toApi()],
        if (_witness != null) 'witnesses': [_witness!.toApi()],
      });

      if (!mounted) return;
      final blotterId = blotter['id'];
      if (blotterId is! int) {
        throw const FormatException(
          'The report was submitted, but its ID was not returned.',
        );
      }
      Navigator.of(context).pop(blotterId);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 16);
    const cardGap = SizedBox(height: 20);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Report an incident'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ScreenHeader(
                icon: Icons.edit_note,
                title: 'Incident report',
                subtitle:
                    'Sent to the barangay for review. '
                    'It is not yet a formal KP complaint.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      title: 'What happened',
                      icon: Icons.report_outlined,
                      children: [
                        TextFormField(
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: fieldDecoration(
                            'Short title',
                            icon: Icons.title,
                          ),
                          validator: _required,
                        ),
                        gap,
                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          isExpanded: true,
                          decoration: fieldDecoration(
                            'Type of incident',
                            icon: Icons.category_outlined,
                          ),
                          items: _incidentTypes
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _type = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        gap,
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickIncidentTime,
                          child: InputDecorator(
                            decoration: fieldDecoration(
                              'When did it happen?',
                              icon: Icons.event_outlined,
                              suffix: const Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              _incidentAt == null
                                  ? 'Tap to choose date and time'
                                  : _forDisplay(_incidentAt!),
                            ),
                          ),
                        ),
                        gap,
                        DropdownButtonFormField<String>(
                          initialValue: _location,
                          isExpanded: true,
                          decoration: fieldDecoration(
                            'Where did it happen?',
                            icon: Icons.place_outlined,
                          ),
                          items: _locations
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _location = v),
                        ),
                        if (_location == 'Outside Paraiso') ...[
                          gap,
                          TextFormField(
                            controller: _incidentBarangay,
                            textCapitalization: TextCapitalization.words,
                            decoration: fieldDecoration(
                              'Incident barangay',
                              icon: Icons.location_city_outlined,
                            ),
                            validator: _required,
                          ),
                          gap,
                          TextFormField(
                            controller: _incidentCity,
                            textCapitalization: TextCapitalization.words,
                            decoration: fieldDecoration(
                              'Incident city / municipality',
                              icon: Icons.location_city_outlined,
                            ),
                            validator: _required,
                          ),
                        ],
                        gap,
                        TextFormField(
                          controller: _details,
                          minLines: 5,
                          maxLines: 10,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: fieldDecoration(
                            'Describe what happened',
                            alignLabelWithHint: true,
                          ),
                          validator: _required,
                        ),
                      ],
                    ),
                    cardGap,
                    SectionCard(
                      title: 'Person involved',
                      icon: Icons.person_outline,
                      caption:
                          'Search registered residents, or type a name '
                          'if the person is not registered.',
                      children: [
                        PartyField(
                          label: 'Name of the person',
                          initialValue: _respondent,
                          onSaved: (v) => _respondent = v,
                        ),
                      ],
                    ),
                    cardGap,
                    SectionCard(
                      title: 'Witness',
                      icon: Icons.visibility_outlined,
                      caption: 'Optional. Add someone who saw what happened.',
                      children: [
                        PartyField(
                          label: 'Witness (optional)',
                          isRequired: false,
                          initialValue: _witness,
                          onSaved: (v) => _witness = v,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text(
                          'Submit report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
