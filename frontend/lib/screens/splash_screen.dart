import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/routes/app_routes.dart';
import '../core/services/app_scope.dart';
import '../widgets/brand/trade_pulse_logo.dart';
import '../widgets/layout/atmosphere_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final authenticated = AppScope.auth(context).isAuthenticated;
    Navigator.of(context).pushReplacementNamed(
      authenticated ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AtmosphereBackground(
      style: AtmosphereStyle.auth,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const Center(child: TradePulseLogo()),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppConstants.tagline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}
