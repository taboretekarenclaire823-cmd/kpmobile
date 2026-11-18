import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';

String _errorText(Object? e) =>
    (e ?? 'Something went wrong.').toString().replaceFirst('Exception: ', '');

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _occupation = TextEditingController();
  final _street = TextEditingController();
  final _picker = ImagePicker();

  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contact.dispose();
    _email.dispose();
    _occupation.dispose();
    _street.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final p = await ApiService.getProfile();
      if (!mounted) return;
      _contact.text = (p['contact_number'] ?? '').toString();
      _email.text = (p['email_address'] ?? '').toString();
      _occupation.text = (p['occupation'] ?? '').toString();
      _street.text = (p['street_address'] ?? '').toString();
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final result = await ApiService.updateProfile({
        'contact_number': _contact.text.trim(),
        'email_address': _email.text.trim(),
        'occupation': _occupation.text.trim(),
        'street_address': _street.text.trim(),
      });
      final updated = Map<String, dynamic>.from(result['data'] as Map);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _contact.text = (updated['contact_number'] ?? '').toString();
        _email.text = (updated['email_address'] ?? '').toString();
        _occupation.text = (updated['occupation'] ?? '').toString();
        _street.text = (updated['street_address'] ?? '').toString();
      });
      _msg((result['message'] ?? 'Your profile was updated.').toString());
    } catch (e) {
      _msg(_errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- photo

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _photoBusy = true);
      final updated = await ApiService.uploadProfilePhoto(picked.path);
      if (!mounted) return;
      // Only the photo changes; unsaved text in the form is left alone.
      setState(() => _profile = updated);
      _msg('Your photo was updated.');
    } catch (e) {
      _msg(_errorText(e));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      final updated = await ApiService.deleteProfilePhoto();
      if (!mounted) return;
      setState(() => _profile = updated);
      _msg('Your photo was removed.');
    } catch (e) {
      _msg(_errorText(e));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _showPhotoOptions(bool hasPhoto) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> p) {
    final colors = Theme.of(context).colorScheme;
    final url = (p['photo_url'] ?? '').toString();
    final hasPhoto = url.isNotEmpty;

    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.onPrimary,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 53,
              backgroundColor: colors.primaryContainer,
              backgroundImage: hasPhoto ? NetworkImage(url) : null,
              onBackgroundImageError: hasPhoto ? (_, _) {} : null,
              child: hasPhoto
                  ? null
                  : Icon(Icons.person,
                      size: 52, color: colors.onPrimaryContainer),
            ),
          ),
          if (_photoBusy)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: colors.onPrimary,
              elevation: 2,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _photoBusy ? null : () => _showPhotoOptions(hasPhoto),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.camera_alt,
                      size: 20, color: colors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ UI

  String _val(dynamic v) =>
      (v == null || v.toString().isEmpty) ? '—' : v.toString();

  String _yesNo(dynamic value) => value == true ? 'Yes' : 'No';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: styledAppBar(context, 'My profile'),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final colors = Theme.of(context).colorScheme;
    final p = _profile!;
    final loginEmail = _val(p['login_email']);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeaderBand(
          child: Column(
            children: [
              _avatar(p),
              const SizedBox(height: 14),
              Text(
                _val(p['full_name']),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (loginEmail != '—') ...[
                const SizedBox(height: 4),
                Text(
                  loginEmail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.85),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Resident information',
                icon: Icons.badge_outlined,
                caption: 'To correct your name, birth date or other verified '
                    'details, please visit the barangay hall.',
                children: [
                  DetailRow(
                      label: 'Resident No.', value: _val(p['resident_no'])),
                  DetailRow(label: 'Full name', value: _val(p['full_name'])),
                  DetailRow(label: 'Birth date', value: _val(p['birthdate'])),
                  DetailRow(label: 'Sex', value: _val(p['sex'])),
                  DetailRow(
                      label: 'Civil status', value: _val(p['civil_status'])),
                  DetailRow(
                      label: 'Nationality', value: _val(p['nationality'])),
                  DetailRow(
                    label: 'Education',
                    value: _val(p['educational_status']),
                  ),
                  DetailRow(label: 'Purok', value: _val(p['purok'])),
                  DetailRow(
                      label: 'Person with disability',
                      value: _yesNo(p['is_pwd'])),
                  if (p['is_pwd'] == true)
                    DetailRow(
                      label: 'PWD ID No.',
                      value: _val(p['pwd_id_number']),
                    ),
                  DetailRow(
                      label: 'Senior citizen',
                      value: _yesNo(p['is_senior_citizen'])),
                  if (p['is_senior_citizen'] == true)
                    DetailRow(
                      label: 'Senior citizen ID No.',
                      value: _val(p['senior_citizen_id_number']),
                    ),
                  DetailRow(
                      label: '4Ps beneficiary',
                      value: _yesNo(p['is_4ps_beneficiary'])),
                  DetailRow(label: 'Login email', value: loginEmail),
                  DetailRow(
                      label: 'Verification',
                      value: _val(p['verification_status'])),
                ],
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Contact details',
                icon: Icons.contact_phone_outlined,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _contact,
                          keyboardType: TextInputType.phone,
                          maxLength: 20,
                          decoration: fieldDecoration('Contact number',
                              icon: Icons.phone_outlined),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) {
                              return 'Enter your contact number.';
                            }
                            if (!RegExp(r'^[0-9+\-\s]{7,20}$')
                                .hasMatch(value)) {
                              return 'Enter a valid contact number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          maxLength: 255,
                          decoration: fieldDecoration(
                              'Contact email (optional)',
                              icon: Icons.email_outlined),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return null;
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _occupation,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 255,
                          decoration: fieldDecoration('Occupation (optional)',
                              icon: Icons.work_outline),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _street,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 255,
                          decoration: fieldDecoration(
                              'Street address (optional)',
                              icon: Icons.home_outlined),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text(
                              'Save changes',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Security',
                icon: Icons.lock_outline,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen()),
                      ),
                      icon: const Icon(Icons.password),
                      label: const Text('Change password'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _showPasswords = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final message = await ApiService.changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      _msg(message);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _msg(_errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _toggle() => IconButton(
        tooltip: _showPasswords ? 'Hide passwords' : 'Show passwords',
        icon: Icon(
            _showPasswords ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _showPasswords = !_showPasswords),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: styledAppBar(context, 'Change password'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const ScreenHeader(
              icon: Icons.lock_outline,
              title: 'Keep your account safe',
              subtitle: 'Choose a new password with at least 8 characters.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: SectionCard(
                title: 'New password',
                icon: Icons.password,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _current,
                          obscureText: !_showPasswords,
                          decoration: fieldDecoration(
                            'Current password',
                            icon: Icons.lock_outline,
                            suffix: _toggle(),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Enter your current password.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _new,
                          obscureText: !_showPasswords,
                          decoration: fieldDecoration(
                            'New password',
                            icon: Icons.lock_reset,
                          ).copyWith(helperText: 'At least 8 characters.'),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Enter a new password.';
                            }
                            if (v.length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirm,
                          obscureText: !_showPasswords,
                          decoration: fieldDecoration(
                            'Confirm new password',
                            icon: Icons.check_circle_outline,
                          ),
                          validator: (v) => v != _new.text
                              ? 'The passwords do not match.'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: const Text(
                              'Change password',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
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