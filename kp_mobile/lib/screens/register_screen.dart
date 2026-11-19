import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _puroks = [
    'Bliss', 'Kalikasan', 'Masipag', 'Mesias',
    'Pag-asa', 'San Miguel', 'Others',
  ];
  // Match these to the options in your web Resident form.
  static const _civilStatuses = [
    'Single', 'Married', 'Widowed', 'Separated', 'Annulled',
  ];
  static const _educationalStatuses = [
    'No Formal Education',
    'Elementary Level',
    'Elementary Graduate',
    'High School Level',
    'High School Graduate',
    'Senior High School Graduate',
    'Vocational',
    'College Level',
    'College Graduate',
    'Post Graduate',
  ];

  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _suffix = TextEditingController();
  final _contact = TextEditingController();
  final _contactEmail = TextEditingController();
  final _nationality = TextEditingController(text: 'Filipino');
  final _occupation = TextEditingController();
  final _street = TextEditingController();
  final _otherPurok = TextEditingController();
  final _pwdId = TextEditingController();
  final _seniorCitizenId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _imagePicker = ImagePicker();

  DateTime? _birthdate;
  String? _sex;
  String? _civilStatus;
  String? _educationalStatus;
  String? _purok;
  String? _verificationDocumentPath;
  bool _isPwd = false;
  bool _isSeniorCitizen = false;
  bool _is4psBeneficiary = false;

  List<Map<String, String>> _regions = [];
  List<Map<String, String>> _provinces = [];
  List<Map<String, String>> _cities = [];
  List<Map<String, String>> _barangays = [];
  String? _regionCode;
  String? _provinceCode;
  String? _cityCode;
  String? _barangayCode;

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void initState() {
    super.initState();
    _run(() async {
      final r = await ApiService.getRegions();
      if (!mounted) return;
      setState(() => _regions = r);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _first, _middle, _last, _suffix, _contact, _contactEmail, _nationality,
      _occupation, _street, _otherPurok, _pwdId, _seniorCitizenId, _email,
      _password, _confirmPassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() job) async {
    try {
      await job();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _pickVerificationDocument() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final extension = picked.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        _msg('Choose a JPG or PNG image.');
        return;
      }
      if (await picked.length() > 5 * 1024 * 1024) {
        _msg('The verification image must be 5 MB or smaller.');
        return;
      }

      if (mounted) {
        setState(() => _verificationDocumentPath = picked.path);
      }
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthdate == null) {
      _msg('Please choose your birthdate.');
      return;
    }

    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'first_name': _first.text.trim(),
        'middle_name': _middle.text.trim().isEmpty ? null : _middle.text.trim(),
        'last_name': _last.text.trim(),
        'suffix': _suffix.text.trim().isEmpty ? null : _suffix.text.trim(),
        'birthdate': _fmt(_birthdate!),
        'sex': _sex,
        'civil_status': _civilStatus,
        'nationality': _nationality.text.trim(),
        'educational_status': _educationalStatus,
        'occupation': _occupation.text.trim(),
        'contact_number': _contact.text.trim(),
        'email_address': _contactEmail.text.trim(),
        'region_id': _regionCode,
        'province_id': _provinceCode,
        'city_id': _cityCode,
        'barangay_id': _barangayCode,
        'purok': _purok,
        'other_purok': _purok == 'Others' && _otherPurok.text.trim().isNotEmpty
            ? _otherPurok.text.trim()
            : null,
        'street_address':
            _street.text.trim().isEmpty ? null : _street.text.trim(),
        'is_pwd': _isPwd,
        'pwd_id_number': _isPwd && _pwdId.text.trim().isNotEmpty
            ? _pwdId.text.trim()
            : null,
        'is_senior_citizen': _isSeniorCitizen,
        'senior_citizen_id_number':
            _isSeniorCitizen && _seniorCitizenId.text.trim().isNotEmpty
                ? _seniorCitizenId.text.trim()
                : null,
        'is_4ps_beneficiary': _is4psBeneficiary,
        'email': _email.text.trim(),
        'password': _password.text,
      };

      final result = await ApiService.register(
        body,
        verificationDocumentPath: _verificationDocumentPath,
      );
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: result['user'],
            resident: result['user']?['resident'],
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  // ------------------------------------------------------------- widgets

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      decoration: authDecoration(context, label: label, icon: icon),
      validator: validator,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      decoration: authDecoration(
        context,
        label: label,
        icon: Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _listDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
    IconData? icon,
    bool required = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: authDecoration(context, label: label, icon: icon),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: required ? (v) => v == null ? 'Required' : null : null,
    );
  }

  Widget _dropdown({
    Key? key,
    required String label,
    required List<Map<String, String>> items,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: value,
      isExpanded: true,
      decoration: authDecoration(context, label: label),
      items: items
          .map((e) =>
              DropdownMenuItem(value: e['code'], child: Text(e['name']!)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _notice(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.onPrimaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The barangay will review your registration before you can '
              'use the services. Please use your real name and details.',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 16);

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            AuthHeader(
              title: 'Create your account',
              subtitle: 'Register to file reports and track your cases',
              logoSize: 76,
              bottomPadding: 28,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _notice(context),
                  const SizedBox(height: 20),

                  // ---------------------------------------- personal info
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthSectionTitle(
                          icon: Icons.person_outline,
                          title: 'Personal information',
                          subtitle: 'As shown on your valid ID',
                        ),
                        const SizedBox(height: 20),
                        _field(
                          controller: _first,
                          label: 'First name',
                          icon: Icons.badge_outlined,
                          capitalization: TextCapitalization.words,
                          validator: _required,
                        ),
                        gap,
                        _field(
                          controller: _middle,
                          label: 'Middle name (optional)',
                          capitalization: TextCapitalization.words,
                        ),
                        gap,
                        _field(
                          controller: _last,
                          label: 'Last name',
                          capitalization: TextCapitalization.words,
                          validator: _required,
                        ),
                        gap,
                        _field(
                          controller: _suffix,
                          label: 'Suffix (Jr., Sr., optional)',
                        ),
                        gap,
                        InkWell(
                          onTap: _pickBirthdate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: authDecoration(
                              context,
                              label: 'Birthdate',
                              icon: Icons.cake_outlined,
                              suffix: const Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _birthdate == null
                                  ? 'Tap to choose'
                                  : _fmt(_birthdate!),
                              style: TextStyle(
                                color: _birthdate == null
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                        gap,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _listDropdown(
                                label: 'Sex',
                                items: const ['Male', 'Female'],
                                value: _sex,
                                required: true,
                                onChanged: (v) => setState(() => _sex = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _listDropdown(
                                label: 'Civil status',
                                items: _civilStatuses,
                                value: _civilStatus,
                                required: true,
                                onChanged: (v) =>
                                    setState(() => _civilStatus = v),
                              ),
                            ),
                          ],
                        ),
                        gap,
                        _field(
                          controller: _nationality,
                          label: 'Nationality (optional)',
                          capitalization: TextCapitalization.words,
                        ),
                        gap,
                        _listDropdown(
                          label: 'Educational attainment (optional)',
                          items: _educationalStatuses,
                          value: _educationalStatus,
                          onChanged: (v) =>
                              setState(() => _educationalStatus = v),
                        ),
                        gap,
                        _field(
                          controller: _occupation,
                          label: 'Occupation (optional)',
                          icon: Icons.work_outline,
                          capitalization: TextCapitalization.words,
                        ),
                        gap,
                        _field(
                          controller: _contact,
                          label: 'Contact number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _required,
                        ),
                        gap,
                        _field(
                          controller: _contactEmail,
                          label: 'Contact email (optional)',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return null;
                            if (email.length > 255 ||
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(email)) {
                              return 'Enter a valid contact email.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---------------------------------- special classification
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthSectionTitle(
                          icon: Icons.accessibility_new,
                          title: 'Special classification',
                          subtitle: 'Answer if applicable',
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Person with disability'),
                          value: _isPwd,
                          onChanged: (value) => setState(() => _isPwd = value),
                        ),
                        if (_isPwd) ...[
                          gap,
                          _field(
                            controller: _pwdId,
                            label: 'PWD ID number (optional)',
                          ),
                        ],
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Senior citizen'),
                          value: _isSeniorCitizen,
                          onChanged: (value) =>
                              setState(() => _isSeniorCitizen = value),
                        ),
                        if (_isSeniorCitizen) ...[
                          gap,
                          _field(
                            controller: _seniorCitizenId,
                            label: 'Senior citizen ID number (optional)',
                          ),
                        ],
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('4Ps beneficiary'),
                          value: _is4psBeneficiary,
                          onChanged: (value) =>
                              setState(() => _is4psBeneficiary = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -------------------------------------------- address
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthSectionTitle(
                          icon: Icons.home_outlined,
                          title: 'Address',
                          subtitle: 'Where you currently live',
                        ),
                        const SizedBox(height: 20),
                        _dropdown(
                          label: 'Region',
                          items: _regions,
                          value: _regionCode,
                          onChanged: (v) {
                            setState(() {
                              _regionCode = v;
                              _provinceCode = _cityCode = _barangayCode = null;
                              _provinces = _cities = _barangays = [];
                            });
                            if (v == null) return;
                            _run(() async {
                              final list = await ApiService.getProvinces(v);
                              if (!mounted) return;
                              setState(() => _provinces = list);
                            });
                          },
                        ),
                        gap,
                        _dropdown(
                          key: ValueKey('province-$_regionCode'),
                          label: 'Province',
                          items: _provinces,
                          value: _provinceCode,
                          onChanged: (v) {
                            setState(() {
                              _provinceCode = v;
                              _cityCode = _barangayCode = null;
                              _cities = _barangays = [];
                            });
                            if (v == null) return;
                            _run(() async {
                              final list = await ApiService.getCities(v);
                              if (!mounted) return;
                              setState(() => _cities = list);
                            });
                          },
                        ),
                        gap,
                        _dropdown(
                          key: ValueKey('city-$_provinceCode'),
                          label: 'City / Municipality',
                          items: _cities,
                          value: _cityCode,
                          onChanged: (v) {
                            setState(() {
                              _cityCode = v;
                              _barangayCode = null;
                              _barangays = [];
                            });
                            if (v == null) return;
                            _run(() async {
                              final list = await ApiService.getBarangays(v);
                              if (!mounted) return;
                              setState(() => _barangays = list);
                            });
                          },
                        ),
                        gap,
                        _dropdown(
                          key: ValueKey('barangay-$_cityCode'),
                          label: 'Barangay',
                          items: _barangays,
                          value: _barangayCode,
                          onChanged: (v) => setState(() => _barangayCode = v),
                        ),
                        gap,
                        _listDropdown(
                          label: 'Purok (optional)',
                          items: _puroks,
                          value: _purok,
                          onChanged: (v) => setState(() => _purok = v),
                        ),
                        if (_purok == 'Others') ...[
                          gap,
                          _field(
                            controller: _otherPurok,
                            label: 'Other purok',
                            validator: _required,
                          ),
                        ],
                        gap,
                        _field(
                          controller: _street,
                          label: 'House / Street (optional)',
                          icon: Icons.signpost_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -------------------------------- verification document
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthSectionTitle(
                          icon: Icons.verified_user_outlined,
                          title: 'Proof of residency',
                          subtitle: 'Optional JPG or PNG image, up to 5 MB',
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _pickVerificationDocument,
                          icon: Icon(
                            _verificationDocumentPath == null
                                ? Icons.upload_file_outlined
                                : Icons.check_circle_outline,
                          ),
                          label: Text(
                            _verificationDocumentPath == null
                                ? 'Choose an ID or proof of address'
                                : 'Image selected',
                          ),
                        ),
                        if (_verificationDocumentPath != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () => setState(
                                      () => _verificationDocumentPath = null,
                                    ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove image'),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -------------------------------------------- account
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthSectionTitle(
                          icon: Icons.lock_outline,
                          title: 'Account',
                          subtitle: 'What you will use to log in',
                        ),
                        const SizedBox(height: 20),
                        _field(
                          controller: _email,
                          label: 'Email address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        gap,
                        _passwordField(
                          controller: _password,
                          label: 'Password (min. 8 characters)',
                          hidden: _hidePassword,
                          onToggle: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'At least 8 characters'
                              : null,
                        ),
                        gap,
                        _passwordField(
                          controller: _confirmPassword,
                          label: 'Confirm password',
                          hidden: _hideConfirm,
                          onToggle: () =>
                              setState(() => _hideConfirm = !_hideConfirm),
                          validator: (v) => v != _password.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          : const Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed:
                            _loading ? null : () => Navigator.of(context).maybePop(),
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}