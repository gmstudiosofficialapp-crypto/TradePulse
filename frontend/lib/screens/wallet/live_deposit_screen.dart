import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../models/live_wallet_models.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/buttons/pressable.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class LiveDepositScreen extends StatefulWidget {
  const LiveDepositScreen({super.key});

  @override
  State<LiveDepositScreen> createState() => _LiveDepositScreenState();
}

class _LiveDepositScreenState extends State<LiveDepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '50');
  LivePaymentAsset _asset = LivePaymentAsset.btc;
  String? _error;

  static const _presets = [50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final parsed = double.parse(
      _amount.text.replaceAll(',', '').replaceAll('\$', '').trim(),
    );
    Navigator.of(context).pushNamed(
      AppRoutes.liveDepositConfirm,
      arguments: LiveDepositDraft(asset: _asset, amount: parsed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AtmosphereBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Deposit'),
        actions: [
          IconButton(
            tooltip: 'Deposit & Withdraw History',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.liveTransfers),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Live account funding',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.mutedText,
                    ),
              ),
              const SizedBox(height: 16),
              PremiumCard(
                child: Row(
                  children: [
                    Text('Live Balance', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      AppUtils.formatMoney(0),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment method',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
              ),
              const SizedBox(height: 10),
              for (final asset in LivePaymentAsset.values) ...[
                _AssetTile(
                  asset: asset,
                  selected: _asset == asset,
                  onTap: () => setState(() => _asset = asset),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Text(
                'Amount',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in _presets)
                    ChoiceChip(
                      label: Text(AppUtils.formatMoney(value).replaceAll('.00', '')),
                      selected: _amount.text.replaceAll(',', '') ==
                              value.toStringAsFixed(0) ||
                          _amount.text == value.toStringAsFixed(2),
                      onSelected: (_) {
                        setState(() {
                          _amount.text = value.toStringAsFixed(0);
                          _error = null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Custom amount',
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.liveDepositAmount,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorState(message: _error!),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Continue',
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final LivePaymentAsset asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Pressable(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: selected ? 0.98 : 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.accent : colors.cardBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            AssetIcon(symbol: asset.iconSymbol, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (asset.network != null)
                    Text(
                      asset.network!,
                      style: TextStyle(fontSize: 12, color: colors.mutedText),
                    ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? colors.accent : colors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
