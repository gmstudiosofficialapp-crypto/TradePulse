import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/validators.dart';
import '../../widgets/brand/trade_pulse_logo.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/forms/password_field.dart';
import '../../widgets/layout/auth_screen_frame.dart';
import '../../widgets/layout/entrance.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AppScope.auth(context).signup(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
      );
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenFrame(
      title: 'Sign Up',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const Entrance(
              child: TradePulseLogo(compact: true, showTagline: false),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Full Name',
              controller: _name,
              validator: (value) => Validators.requiredField(value, 'Full name'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            PasswordField(
              label: 'Password',
              controller: _password,
              validator: Validators.strongPassword,
            ),
            const SizedBox(height: 12),
            PasswordField(
              label: 'Confirm Password',
              controller: _confirm,
              validator: (value) =>
                  Validators.confirmPassword(value, _password.text),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorState(message: _error!),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: 'Create Account',
              loading: _loading,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
