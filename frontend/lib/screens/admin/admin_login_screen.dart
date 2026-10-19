import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/app_scope.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/forms/password_field.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  var _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final admin = AppScope.admin(context);
    if (admin == null) {
      setState(() => _error = 'Admin is unavailable');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await admin.login(_username.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.adminPanel);
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to sign in');
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
        appBar: AppBar(title: const Text('Admin Login')),
        body: ResponsiveBody(
          maxWidth: 440,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppTextField(
                label: 'Username',
                controller: _username,
              ),
              const SizedBox(height: 14),
              PasswordField(
                label: 'Password',
                controller: _password,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorState(message: _error!),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Sign in',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
