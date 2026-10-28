import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
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

  static const _presets = [50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0];

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

  bool _presetSelected(double value) {
    final raw = _amount.text.replaceAll(',', '').replaceAll('\$', '').trim();
    return raw == value.toStringAsFixed(0) || raw == value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final liveBalance = TradingScope.maybeOf(context)?.liveBalance ?? 0;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Deposit'),
          actions: [
            IconButton(
              tooltip: 'Deposit & Withdraw History',
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.depositHistory),
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
                const _DepositSteps(current: 1),
                const SizedBox(height: 18),
                PremiumCard(
                  emphasized: true,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accent.withValues(alpha: 0.14),
                          border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Icon(Icons.account_balance_wallet_outlined, color: colors.accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Balance',
                              style: TextStyle(
                                color: colors.mutedText,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppUtils.formatMoney(liveBalance),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Payment method',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                ),
                const SizedBox(height: 12),
                for (final asset in LivePaymentAsset.values) ...[
                  _AssetTile(
                    asset: asset,
                    selected: _asset == asset,
                    onTap: () => setState(() => _asset = asset),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                Text(
                  'Amount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Minimum ${AppUtils.formatMoney(Validators.depositMin)}  ·  Maximum ${AppUtils.formatMoney(Validators.depositMax)}',
                  style: TextStyle(color: colors.mutedText, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in _presets)
                      ChoiceChip(
                        label: Text(AppUtils.formatMoney(value).replaceAll('.00', '')),
                        selected: _presetSelected(value),
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

class _DepositSteps extends StatelessWidget {
  const _DepositSteps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    const labels = ['Method', 'Amount', 'Confirm'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < current ? colors.accent : colors.cardBorder,
              ),
            ),
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i + 1 <= current ? colors.accent : colors.inputFill,
                  border: Border.all(
                    color: i + 1 <= current ? colors.accent : colors.cardBorder,
                  ),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: i + 1 <= current
                        ? const Color(0xFF061018)
                        : colors.mutedText,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: i + 1 <= current ? colors.accent : colors.mutedText,
                ),
              ),
            ],
          ),
        ],
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: selected ? 0.98 : 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.accent : colors.cardBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.glow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AssetIcon(symbol: asset.iconSymbol, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    asset.depositNetworkLabel,
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
