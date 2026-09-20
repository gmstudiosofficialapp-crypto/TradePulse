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

    final media = MediaQuery.of(context);
    if (media.viewInsets.bottom > 80) {
      return const SizedBox.shrink();
    }

    final compact = media.size.width < 720;
    final bottom = media.padding.bottom + (compact ? 76 : 16);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom),
        child: _BannerCard(install: install),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.install});

  final PwaInstallController install;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final ios = install.surface == PwaInstallSurface.ios;
    final scheme = Theme.of(context).colorScheme;

    return Material(
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
                onPressed: ios
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
                child: Text(ios ? 'Add to Home Screen' : 'Install Now'),
              ),
            ),
            if (ios && install.iosGuideOpen) ...[
              const SizedBox(height: 10),
              Text(
                '1. Tap the Share button in Safari\n'
                '2. Select “Add to Home Screen”\n'
                '3. Tap “Add”',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      height: 1.45,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
