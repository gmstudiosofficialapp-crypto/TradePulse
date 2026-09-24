import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/validators.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/password_field.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AppScope.auth(context).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AtmosphereBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Change Password')),
      body: ResponsiveBody(
        maxWidth: 480,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                PasswordField(
                  label: 'Current password',
                  controller: _current,
                  validator: Validators.password,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  label: 'New password',
                  controller: _next,
                  validator: Validators.strongPassword,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  label: 'Confirm new password',
                  controller: _confirm,
                  validator: (value) =>
                      Validators.confirmPassword(value, _next.text),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ErrorState(message: _error!),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: 'Update password',
                  loading: _loading,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
