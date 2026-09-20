import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/validators.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/password_field.dart';
import '../../widgets/layout/auth_screen_frame.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.oobCode});

  final String? oobCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _verifying = true;
  bool _linkValid = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_verify()));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = widget.oobCode;
    if (code == null || code.isEmpty) {
      setState(() {
        _verifying = false;
        _linkValid = false;
        _error = 'This reset link is invalid or has already been used.';
      });
      return;
    }
    try {
      await AppScope.auth(context).verifyResetActionCode(code);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _linkValid = true;
        _error = null;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _linkValid = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final code = widget.oobCode;
    if (code == null || code.isEmpty || _loading || _success || !_linkValid) {
      return;
    }
    setState(() => _loading = true);
    try {
      await AppScope.auth(context).confirmPasswordReset(
        oobCode: code,
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() => _success = true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenFrame(
      title: _success ? 'Password Reset Successful' : 'Reset Password',
      child: _verifying
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            )
          : _success
              ? Column(
                  children: [
                    Text(
                      'Your password has been updated successfully.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Login',
                      onPressed: () {
                        Navigator.of(context)
                            .pushReplacementNamed(AppRoutes.login);
                      },
                    ),
                  ],
                )
              : !_linkValid
                  ? Column(
                      children: [
                        if (_error != null) ErrorState(message: _error!),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Forgot Password',
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              AppRoutes.forgotPassword,
                            );
                          },
                        ),
                      ],
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            'Choose a new password for your TradePulse account.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          PasswordField(
                            label: 'New Password',
                            controller: _password,
                            validator: Validators.strongPassword,
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            label: 'Confirm Password',
                            controller: _confirm,
                            validator: (value) => Validators.confirmPassword(
                              value,
                              _password.text,
                            ),
                            onSubmitted: (_) => _save(),
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            ErrorState(message: _error!),
                            const SizedBox(height: 12),
                          ],
                          PrimaryButton(
                            label: 'Save New Password',
                            loading: _loading,
                            onPressed: _loading
                                ? null
                                : () => unawaited(_save()),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
