import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'app_ui.dart';

/// A person picked for a report: either a registered resident (by id)
/// or a typed-in name with a barangay (same as the web "freeform" entry).
class PartyValue {
  final int? residentId;
  final String? residentName;
  final String? freeformName;
  final String? freeformBarangay;
  final String? freeformCity;

  const PartyValue.resident(this.residentId, this.residentName)
    : freeformName = null,
      freeformBarangay = null,
      freeformCity = null;

  const PartyValue.freeform(
    this.freeformName,
    this.freeformBarangay, [
    this.freeformCity,
  ]) : residentId = null,
       residentName = null;

  String get label => residentName ?? freeformName ?? '';

  /// Shape the Laravel controller expects.
  Map<String, dynamic> toApi() => residentId != null
      ? {'resident_id': residentId}
      : {
          'freeform_name': freeformName,
          'freeform_barangay': freeformBarangay,
          if (freeformCity != null && freeformCity!.trim().isNotEmpty)
            'freeform_city': freeformCity,
        };
}

class PartyField extends FormField<PartyValue> {
  PartyField({
    super.key,
    required String label,
    bool isRequired = true,
    bool requireCity = false,
    super.onSaved,
    super.initialValue,
  }) : super(
         validator: (v) {
           if (isRequired && v == null) return 'Required';
           if (requireCity &&
               v != null &&
               v.residentId == null &&
               (v.freeformCity == null || v.freeformCity!.trim().isEmpty)) {
             return 'Please enter the person again with their city.';
           }
           return null;
         },
         builder: (state) {
           final v = state.value;
           return InkWell(
             borderRadius: BorderRadius.circular(12),
             onTap: () async {
               final picked = await showModalBottomSheet<PartyValue>(
                 context: state.context,
                 isScrollControlled: true,
                 showDragHandle: true,
                 shape: const RoundedRectangleBorder(
                   borderRadius: BorderRadius.vertical(
                     top: Radius.circular(24),
                   ),
                 ),
                 builder: (_) => _PartySheet(requireCity: requireCity),
               );
               if (picked != null) state.didChange(picked);
             },
             child: InputDecorator(
               decoration: fieldDecoration(
                 label,
                 icon: Icons.person_outline,
                 suffix: v == null
                     ? const Icon(Icons.arrow_drop_down)
                     : IconButton(
                         icon: const Icon(Icons.clear),
                         onPressed: () => state.didChange(null),
                       ),
               ).copyWith(errorText: state.errorText),
               child: v == null
                   ? const Text('Tap to choose')
                   : Text(
                       v.residentId != null
                           ? v.label
                           : '${v.label}  (not registered • ${v.freeformBarangay})',
                     ),
             ),
           );
         },
       );
}

class _PartySheet extends StatefulWidget {
  final bool requireCity;

  const _PartySheet({required this.requireCity});

  @override
  State<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends State<_PartySheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _freeformKey = GlobalKey<FormState>();

  Timer? _debounce;
  bool _manual = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    _barangay.dispose();
    _city.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    final term = q.trim();

    if (term.length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final r = await ApiService.searchResidents(term);
        // Ignore answers for something the user has already changed.
        if (!mounted || _search.text.trim() != term) return;
        setState(() => _results = r);
      } catch (e) {
        if (mounted) {
          setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String _initial(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, inset + 16),
      child: SizedBox(
        height: (media.size.height - inset) * 0.7,
        child: _manual ? _manualEntry() : _searchView(),
      ),
    );
  }

  Widget _hint(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 36, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _searchView() {
    final colors = Theme.of(context).colorScheme;
    final searched = _search.text.trim().length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a person',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          autofocus: true,
          onChanged: _onChanged,
          decoration: fieldDecoration(
            'Search registered residents',
            icon: Icons.search,
          ),
        ),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: TextStyle(color: colors.error)),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final r in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(_initial(r['name'].toString())),
                  ),
                  title: Text(r['name'].toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(
                    context,
                    PartyValue.resident(r['id'] as int, r['name'].toString()),
                  ),
                ),
              if (!_loading && _error == null && _results.isEmpty && searched)
                _hint(
                  Icons.person_search_outlined,
                  'No registered resident found.',
                ),
              if (!searched)
                _hint(Icons.search, 'Type at least 2 letters of the name.'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Not on the list? Type their name'),
          onPressed: () => setState(() {
            _manual = true;
            _name.text = _search.text.trim();
          }),
        ),
      ],
    );
  }

  Widget _manualEntry() {
    return Form(
      key: _freeformKey,
      child: ListView(
        children: [
          Text(
            'Person not registered',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            widget.requireCity
                ? 'Type their name, barangay, and city or municipality.'
                : 'Type their name and barangay. City is optional.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDecoration(
              'Full name (write "Unknown" if not known)',
              icon: Icons.person_outline,
            ),
            validator: _req,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _barangay,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDecoration(
              'Barangay',
              hint: 'e.g. Brgy. Paraiso',
              icon: Icons.location_city_outlined,
            ),
            validator: _req,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDecoration(
              widget.requireCity
                  ? 'City / municipality'
                  : 'City / municipality (optional)',
              icon: Icons.location_city_outlined,
            ),
            validator: widget.requireCity ? _req : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _manual = false),
                child: const Text('Back to search'),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (!_freeformKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    PartyValue.freeform(
                      _name.text.trim(),
                      _barangay.text.trim(),
                      _city.text.trim(),
                    ),
                  );
                },
                child: const Text('Use this name'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
