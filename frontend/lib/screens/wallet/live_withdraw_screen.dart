import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/services/trading_service.dart';
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

class LiveWithdrawScreen extends StatefulWidget {
  const LiveWithdrawScreen({super.key});

  @override
  State<LiveWithdrawScreen> createState() => _LiveWithdrawScreenState();
}

class _LiveWithdrawScreenState extends State<LiveWithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _address = TextEditingController();
  LivePaymentAsset? _method;
  String? _error;
  String? _notice;
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    _address.dispose();
    super.dispose();
  }

  double get _liveBalance {
    return TradingScope.maybeOf(context)?.liveBalance ?? 0;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _notice = null;
    });

    final amountError = Validators.withdrawAmount(_amount.text);
    if (amountError != null) {
      setState(() => _error = amountError);
      _formKey.currentState?.validate();
      return;
    }
    if (_method == null) {
      setState(() => _error = Validators.withdrawMethodRequired);
      return;
    }
    final addressError = Validators.withdrawAddress(_address.text, _method);
    if (addressError != null) {
      setState(() => _error = addressError);
      _formKey.currentState?.validate();
      return;
    }
    final amount = Validators.parseMoney(_amount.text)!;
    if (amount > _liveBalance) {
      setState(() => _error = Validators.withdrawInsufficient);
      return;
    }

    setState(() => _loading = true);
    try {
      final trading = TradingScope.maybeOf(context);
      if (trading != null) {
        await trading.previewWithdrawal(
          amount: amount,
          method: _method!.withdrawMethodId,
          address: _address.text.trim(),
        );
      }
      if (!mounted) return;
      setState(() => _notice = Validators.withdrawDepositRequired);
    } on WithdrawValidationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = Validators.withdrawDepositRequired);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final live = _liveBalance;
    final insufficient = live < Validators.withdrawMin;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Withdraw'),
          actions: [
            IconButton(
              tooltip: 'Deposit & Withdraw History',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.liveTransfers),
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
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Live Balance',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppUtils.formatMoney(live),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                if (insufficient) ...[
                  const SizedBox(height: 16),
                  PremiumCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: colors.danger,
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Insufficient Balance',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You do not have sufficient Live Balance to make a withdrawal.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdrawal Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 14),
                      const _InfoRow(label: 'Minimum Withdrawal', value: r'$50.00'),
                      _InfoRow(
                        label: 'Available Balance',
                        value: AppUtils.formatMoney(live),
                      ),
                      const _InfoRow(
                        label: 'Withdrawal Status',
                        value: 'Processing',
                      ),
                      const _InfoRow(
                        label: 'Processing',
                        value: 'Deposit required',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Withdrawal Amount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  label: 'Amount',
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: Validators.withdrawAmount,
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment Method',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                for (final asset in LivePaymentAsset.values) ...[
                  _MethodTile(
                    asset: asset,
                    selected: _method == asset,
                    onTap: () => setState(() {
                      _method = asset;
                      _error = null;
                      _notice = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                Text(
                  'Payment Address',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  label: 'Payment address',
                  controller: _address,
                  hintText: _method?.withdrawAddressHint ??
                      'Select a payment method first',
                  validator: (value) => Validators.withdrawAddress(value, _method),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ErrorState(message: _error!),
                  const SizedBox(height: 12),
                ],
                if (_notice != null) ...[
                  PremiumCard(
                    child: Text(
                      _notice!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: 'Submit Withdrawal',
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.mutedText, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
