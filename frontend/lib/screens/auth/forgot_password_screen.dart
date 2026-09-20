import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/validators.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/layout/auth_screen_frame.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AppScope.auth(context).resetPassword(email: _email.text);
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenFrame(
      title: 'Forgot Password',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              _sent
                  ? 'Password reset email sent. Please check your inbox.'
                  : 'Enter the email on your TradePulse account. We will send a password reset link.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!_sent) ...[
              AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorState(message: _error!),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Send Reset Email',
                loading: _loading,
                onPressed: _loading ? null : () => unawaited(_send()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
