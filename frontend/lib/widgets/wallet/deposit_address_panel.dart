import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/live_wallet_models.dart';

class DepositAddressPanel extends StatelessWidget {
  const DepositAddressPanel({
    super.key,
    required this.asset,
    this.onCopied,
  });

  final LivePaymentAsset asset;
  final VoidCallback? onCopied;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: asset.placeholderAddress));
    onCopied?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final address = asset.placeholderAddress;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.glow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: QrImageView(
            data: address,
            size: 164,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0B1730),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0B1730),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Scan to pay',
          style: TextStyle(
            color: colors.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
            ),
            child: Text(
              asset.depositNetworkLabel.toUpperCase(),
              style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            color: colors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  address,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    height: 1.55,
                    letterSpacing: 0.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy Address',
                onPressed: () => _copy(context),
                icon: Icon(Icons.copy_rounded, color: colors.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Send only ${asset.shortName} on ${asset.depositNetworkLabel}. Other assets may be lost.',
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Copy Address'),
          ),
        ),
      ],
    );
  }
}
