import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/live_wallet_models.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class LiveDepositConfirmScreen extends StatefulWidget {
  const LiveDepositConfirmScreen({super.key, required this.draft});

  final LiveDepositDraft draft;

  @override
  State<LiveDepositConfirmScreen> createState() => _LiveDepositConfirmScreenState();
}

class _LiveDepositConfirmScreenState extends State<LiveDepositConfirmScreen> {
  final _txid = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _txid.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: widget.draft.asset.placeholderAddress),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  Future<void> _submit() async {
    final txid = _txid.text.trim();
    if (txid.isEmpty) {
      setState(() => _error = 'Enter a transaction ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.wallet(context).submitDeposit(
        asset: widget.draft.asset,
        amount: widget.draft.amount,
        txid: txid,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.liveTransfers);
    } catch (_) {
      setState(() => _error = 'Unable to submit this deposit');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TextStyle _labelStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        );
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.draft.asset;
    final colors = context.tpColors;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Confirm Deposit')),
        body: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Method', style: _labelStyle(context)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        AssetIcon(symbol: asset.iconSymbol, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            asset.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Deposit Amount', style: _labelStyle(context)),
                    const SizedBox(height: 6),
                    Text(
                      AppUtils.formatMoney(widget.draft.amount),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Text('Deposit Address', style: _labelStyle(context)),
                    const SizedBox(height: 6),
                    SelectableText(
                      asset.placeholderAddress,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Address'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: 'Transaction ID / TXID',
                controller: _txid,
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                ErrorState(message: _error!),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Submit Deposit',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 12),
              Text(
                'Simulated request only. Live balance stays \$0.00.',
                style: TextStyle(color: colors.mutedText, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
