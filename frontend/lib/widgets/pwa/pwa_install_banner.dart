import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/services/pwa_install_controller.dart';
import '../../core/theme/app_colors.dart';

class PwaInstallBanner extends StatelessWidget {
  const PwaInstallBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final install = PwaInstallScope.maybeOf(context);
    if (install == null || !install.shouldShow) {
      return const SizedBox.shrink();
    }

    final colors = context.tpColors;
    final ios = install.surface == PwaInstallSurface.ios;
    final android = install.surface == PwaInstallSurface.android;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Material(
        color: colors.card.withValues(alpha: 0.96),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.download_rounded, color: colors.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Install TradePulse',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ios
                              ? 'Add TradePulse to your Home Screen for faster access.'
                              : android
                                  ? 'Add TradePulse to your Home Screen from the Chrome menu.'
                                  : 'Install the app for faster access to your account.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.mutedText,
                                height: 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: install.dismiss,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: ios || android
                      ? install.openIosGuide
                      : () {
                          install.installNow();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: scheme.onPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(
                    ios || android ? 'Add to Home Screen' : 'Install Now',
                  ),
                ),
              ),
              if ((ios || android) && install.iosGuideOpen) ...[
                const SizedBox(height: 10),
                Text(
                  ios
                      ? '1. Tap the Share button in Safari\n'
                          '2. Select “Add to Home Screen”\n'
                          '3. Tap “Add”'
                      : '1. Tap the Chrome menu (⋮)\n'
                          '2. Tap Install app or Add to Home screen\n'
                          '3. Tap Install',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        height: 1.45,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
