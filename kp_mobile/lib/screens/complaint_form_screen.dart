import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/party_field.dart';

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  // These lists must match ComplaintController.php in Laravel.
  static const _types = [
    'Civil Dispute',
    'Criminal Dispute',
    'Property Dispute',
    'Boundary Dispute',
    'Money/Financial Dispute',
    'Family Dispute',
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
  final _otherComplaintType = TextEditingController();
  final _incidentBarangay = TextEditingController();
  final _incidentCity = TextEditingController();

  String? _type;
  String? _location;
  DateTime? _incidentAt;
  final List<PartyEntry> _respondents = [PartyEntry()];
  final List<PartyEntry> _witnesses = [];
  int? _blotterId;
  List<Map<String, dynamic>> _blotters = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBlotters();
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _otherComplaintType.dispose();
    _incidentBarangay.dispose();
    _incidentCity.dispose();
    super.dispose();
  }

  /// The resident's own open reports, so one can be linked (optional).
  Future<void> _loadBlotters() async {
    try {
      final all = await ApiService.getBlotters();
      if (!mounted) return;
      setState(() {
        _blotters = all
            .where(
              (b) =>
                  (b['status'] == 'Open' || b['status'] == 'Pending') &&
                  b['has_complaint'] != true,
            )
            .toList();
      });
    } catch (_) {
      // Linking a report is optional, so just hide the field.
    }
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
    _formKey.currentState!.save();

    if (_incidentAt == null) {
      _msg('Please choose when the incident happened.');
      return;
    }

    if (_location == 'Outside Paraiso' &&
        (_type == 'Property Dispute' || _type == 'Boundary Dispute')) {
      _msg(
        'Property and boundary disputes must be filed in the barangay where '
        'the property is located. Please contact staff to be referred to the '
        'right barangay.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final complaint = await ApiService.createComplaint({
        'complaint_title': _title.text.trim(),
        'complaint_details': _details.text.trim(),
        'complaint_type': _type,
        if (_type == 'Other')
          'other_complaint_type': _otherComplaintType.text.trim(),
        'incident_datetime': _forApi(_incidentAt!),
        'incident_location': _location,
        if (_location == 'Outside Paraiso') ...{
          'incident_barangay': _incidentBarangay.text.trim(),
          'incident_city': _incidentCity.text.trim(),
        },
        if (_blotterId != null) 'blotter_id': _blotterId,
        'respondents':
            _respondents.map((entry) => entry.value!.toApi()).toList(),
        if (_witnesses.any((entry) => entry.value != null))
          'witnesses': _witnesses
              .where((entry) => entry.value != null)
              .map((entry) => entry.value!.toApi())
              .toList(),
      });

      if (!mounted) return;
      final complaintId = complaint['id'];
      if (complaintId is! int) {
        throw const FormatException(
          'The complaint was submitted, but its ID was not returned.',
        );
      }
      final message = complaint['submission_message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Complaint submitted'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(complaintId);
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
      appBar: styledAppBar(context, 'File a complaint'),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ScreenHeader(
                icon: Icons.gavel,
                title: 'Formal complaint',
                subtitle:
                    'Staff review it first. A filing fee may be '
                    'required; the barangay will tell you.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      title: 'The complaint',
                      icon: Icons.description_outlined,
                      children: [
                        if (_blotters.isNotEmpty) ...[
                          DropdownButtonFormField<int?>(
                            isExpanded: true,
                            decoration: fieldDecoration(
                              'Link one of your reports (optional)',
                              icon: Icons.link,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('None'),
                              ),
                              ..._blotters.map(
                                (b) => DropdownMenuItem<int?>(
                                  value: b['id'] as int,
                                  child: Text(
                                    '${b['blotter_number']}  •  ${b['title']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _blotterId = v),
                          ),
                          gap,
                        ],
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
                            'Type of complaint',
                            icon: Icons.category_outlined,
                          ),
                          items: _types
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _type = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        if (_type == 'Other') ...[
                          gap,
                          TextFormField(
                            controller: _otherComplaintType,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 150,
                            decoration: fieldDecoration(
                              'Describe the complaint type',
                              icon: Icons.edit_note,
                            ),
                            validator: (value) => _type == 'Other'
                                ? _required(value)
                                : null,
                          ),
                        ],
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
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        if (_location == 'Outside Paraiso') ...[
                          gap,
                          Text(
                            'Complaints outside Paraiso can proceed only when '
                            'the parties live in the same city and at least '
                            'one respondent is a Paraiso resident.',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
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
                      title: 'Person you are complaining about',
                      icon: Icons.person_outline,
                      caption:
                          'Add up to 10 respondents. Search registered '
                          'residents, or type a name if the person is not '
                          'registered.',
                      children: [
                        for (final entry in _respondents) ...[
                          if (_respondents.indexOf(entry) > 0) gap,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: PartyField(
                                  key: ObjectKey(entry),
                                  label: _respondents.indexOf(entry) == 0
                                      ? 'Name of the person'
                                      : 'Respondent '
                                          '${_respondents.indexOf(entry) + 1}',
                                  requireCity: _location == 'Outside Paraiso',
                                  initialValue: entry.value,
                                  onSaved: (value) => entry.value = value,
                                ),
                              ),
                              if (_respondents.length > 1)
                                IconButton(
                                  tooltip: 'Remove respondent',
                                  onPressed: () => setState(
                                    () => _respondents.remove(entry),
                                  ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                            ],
                          ),
                        ],
                        if (_respondents.length < 10) ...[
                          gap,
                          OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _respondents.add(PartyEntry()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add respondent'),
                          ),
                        ],
                      ],
                    ),
                    cardGap,
                    SectionCard(
                      title: 'Witness',
                      icon: Icons.visibility_outlined,
                      caption:
                          'Optional. Add up to 10 witnesses who saw what '
                          'happened.',
                      children: [
                        for (final entry in _witnesses) ...[
                          if (_witnesses.indexOf(entry) > 0) gap,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: PartyField(
                                  key: ObjectKey(entry),
                                  label:
                                      'Witness '
                                      '${_witnesses.indexOf(entry) + 1} '
                                      '(optional)',
                                  isRequired: false,
                                  initialValue: entry.value,
                                  onSaved: (value) => entry.value = value,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove witness',
                                onPressed: () => setState(
                                  () => _witnesses.remove(entry),
                                ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                        ],
                        if (_witnesses.length < 10) ...[
                          gap,
                          OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _witnesses.add(PartyEntry()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add witness'),
                          ),
                        ],
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
                          'Submit complaint',
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
