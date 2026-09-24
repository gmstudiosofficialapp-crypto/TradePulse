import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../buttons/primary_button.dart';

class SignupBonusDialog extends StatelessWidget {
  const SignupBonusDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SignupBonusDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: colors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.cardBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.glow,
                  border: Border.all(color: colors.accent.withValues(alpha: 0.45)),
                ),
                child: Icon(Icons.celebration_outlined, color: colors.accent, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                'Signup Bonus Received!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to TradePulse!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                r'$10',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'has been added to your Live Balance.\nYou can now use your Live Balance for trading.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Start Trading',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
