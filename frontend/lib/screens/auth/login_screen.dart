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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AppScope.auth(context).login(
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenFrame(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const TradePulseLogo(),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            PasswordField(
              label: 'Password',
              controller: _password,
              validator: Validators.password,
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
                },
                child: const Text('Forgot Password'),
              ),
            ),
            if (_error != null) ...[
              ErrorState(message: _error!),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: 'Login',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.signup);
              },
              child: const Text('Create a demo account'),
            ),
          ],
        ),
      ),
    );
  }
}
