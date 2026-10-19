import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/services/trading_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../models/withdraw_models.dart';
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
  final _details = TextEditingController();
  WithdrawMethod? _method;
  String? _error;
  var _loading = false;
  var _titleTaps = 0;
  DateTime? _firstTap;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _details.dispose();
    super.dispose();
  }

  double get _liveBalance {
    return TradingScope.maybeOf(context)?.liveBalance ?? 0;
  }

  double? get _usdAmount => Validators.parseMoney(_amount.text);

  void _onTitleTap() {
    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > const Duration(seconds: 2)) {
      _firstTap = now;
      _titleTaps = 1;
      return;
    }
    _titleTaps += 1;
    if (_titleTaps < 5) return;
    _titleTaps = 0;
    _firstTap = null;
    Navigator.of(context).pushNamed(AppRoutes.adminLogin);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final amountError = Validators.withdrawAmount(_amount.text, _method);
    if (amountError != null) {
      setState(() => _error = amountError);
      _formKey.currentState?.validate();
      return;
    }
    if (_method == null) {
      setState(() => _error = Validators.withdrawMethodRequired);
      return;
    }
    final detailsError = Validators.withdrawPaymentDetails(_details.text, _method);
    if (detailsError != null) {
      setState(() => _error = detailsError);
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
      if (trading == null) {
        throw WithdrawValidationException('Unable to submit withdrawal');
      }
      final result = await trading.createWithdrawal(
        amount: amount,
        method: _method!.id,
        paymentDetails: _details.text.trim(),
      );
      if (!mounted) return;
      final request = result['request'];
      await _showSubmitted();
      if (!mounted) return;
      if (request is Map) {
        Navigator.of(context).pushNamed(
          AppRoutes.withdrawalDetails,
          arguments: WithdrawalRequest.fromJson(Map<String, dynamic>.from(request)),
        );
      }
    } on WithdrawValidationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to submit withdrawal');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSubmitted() {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(Validators.withdrawSubmittedTitle),
          content: const Text(Validators.withdrawSubmittedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final live = _liveBalance;
    final insufficient = live < Validators.withdrawMin;
    final method = _method;
    final usd = _usdAmount;
    final bdt = method?.category == WithdrawCategory.p2p && usd != null
        ? Validators.usdToBdtAmount(usd)
        : null;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: GestureDetector(
            key: const Key('withdraw-title'),
            onTap: _onTitleTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text('Withdraw'),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Withdrawal History',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.withdrawalHistory),
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
                      const _InfoRow(label: 'Crypto minimum', value: r'$50.00'),
                      const _InfoRow(label: 'Crypto maximum', value: r'$10,000.00'),
                      const _InfoRow(label: 'P2P minimum', value: '৳5,000.00'),
                      const _InfoRow(label: 'P2P maximum', value: '৳50,000.00'),
                      const _InfoRow(label: 'P2P rate', value: r'$1 = ৳124'),
                      _InfoRow(
                        label: 'Available Balance',
                        value: AppUtils.formatMoney(live),
                      ),
                      const _InfoRow(
                        label: 'Processing time',
                        value: '2–12 hours',
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
                  validator: (value) => Validators.withdrawAmount(value, method),
                ),
                if (bdt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${AppUtils.formatMoney(usd!)} = ${AppUtils.formatBdt(bdt)}',
                    style: TextStyle(
                      color: colors.accentSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Payment Method',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Crypto',
                  style: TextStyle(
                    color: colors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in const [
                  WithdrawMethod.btc,
                  WithdrawMethod.usdtTrc20,
                  WithdrawMethod.eth,
                ]) ...[
                  _MethodTile(
                    method: item,
                    selected: method == item,
                    onTap: () => setState(() {
                      _method = item;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),
                Text(
                  'P2P',
                  style: TextStyle(
                    color: colors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in const [
                  WithdrawMethod.bkash,
                  WithdrawMethod.nagad,
                ]) ...[
                  _MethodTile(
                    method: item,
                    selected: method == item,
                    onTap: () => setState(() {
                      _method = item;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                Text(
                  method?.detailsLabel ?? 'Payment details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  label: method?.detailsLabel ?? 'Payment details',
                  controller: _details,
                  hintText: method?.detailsHint ?? 'Select a payment method first',
                  keyboardType: method?.category == WithdrawCategory.p2p
                      ? TextInputType.phone
                      : TextInputType.text,
                  validator: (value) =>
                      Validators.withdrawPaymentDetails(value, method),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ErrorState(message: _error!),
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
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final WithdrawMethod method;
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
            AssetIcon(symbol: method.iconSymbol, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (method.network != null)
                    Text(
                      method.network!,
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
