import 'package:flutter/material.dart';

import '../../widgets/cards/premium_card.dart';
import 'atmosphere_background.dart';
import 'responsive_body.dart';

class AuthScreenFrame extends StatelessWidget {
  const AuthScreenFrame({
    super.key,
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return AtmosphereBackground(
      style: AtmosphereStyle.auth,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: title == null ? null : AppBar(title: Text(title!)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ResponsiveBody(
                maxWidth: 440,
                child: PremiumCard(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
