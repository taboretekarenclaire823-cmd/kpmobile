import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _codeRequested = false;
  bool _sending = false;
  bool _resetting = false;
  bool _showPasswords = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      final message = await ApiService.requestPasswordReset(_email.text);
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _code.clear();
        _password.clear();
        _confirmPassword.clear();
      });
      _showMessage(message);
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _resetting = true);
    try {
      final message = await ApiService.resetPassword(
        email: _email.text,
        code: _code.text,
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AuthHeader(
            title: 'Reset your password',
            subtitle: 'We will email you a one-time reset code.',
            logoSize: 76,
            bottomPadding: 28,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              children: [
                AuthCard(
                  child: Form(
                    key: _emailFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          decoration: authDecoration(
                            context,
                            label: 'Account email',
                            icon: Icons.email_outlined,
                          ),
                          validator: _validateEmail,
                          onChanged: (_) {
                            if (_codeRequested) {
                              setState(() {
                                _codeRequested = false;
                                _code.clear();
                                _password.clear();
                                _confirmPassword.clear();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _sending ? null : _requestCode,
                            child: _sending
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : Text(
                                    _codeRequested
                                        ? 'Send another reset code'
                                        : 'Send reset code',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_codeRequested) ...[
                  const SizedBox(height: 20),
                  AuthCard(
                    child: Form(
                      key: _resetFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Enter the code from your email and choose a new password. '
                            'The code expires in 15 minutes.',
                            style: TextStyle(height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 6,
                            decoration: authDecoration(
                              context,
                              label: 'Six-digit reset code',
                              icon: Icons.password,
                            ),
                            validator: (value) => (value ?? '').length == 6
                                ? null
                                : 'Enter the six-digit code.',
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _password,
                            obscureText: !_showPasswords,
                            decoration: authDecoration(
                              context,
                              label: 'New password',
                              icon: Icons.lock_reset,
                              suffix: IconButton(
                                tooltip: _showPasswords
                                    ? 'Hide passwords'
                                    : 'Show passwords',
                                onPressed: () => setState(
                                  () => _showPasswords = !_showPasswords,
                                ),
                                icon: Icon(
                                  _showPasswords
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ).copyWith(helperText: 'At least 8 characters.'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter a new password.';
                              }
                              if (value.length < 8) {
                                return 'Use at least 8 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPassword,
                            obscureText: !_showPasswords,
                            decoration: authDecoration(
                              context,
                              label: 'Confirm new password',
                              icon: Icons.check_circle_outline,
                            ),
                            validator: (value) => value != _password.text
                                ? 'The passwords do not match.'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _resetting ? null : _resetPassword,
                              child: _resetting
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.onPrimary,
                                      ),
                                    )
                                  : const Text('Reset password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
