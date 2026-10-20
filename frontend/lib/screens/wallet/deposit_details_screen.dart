import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/deposit_models.dart';
import '../../models/withdraw_models.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class DepositDetailsScreen extends StatefulWidget {
  const DepositDetailsScreen({super.key, required this.requestId, this.initial});

  final String requestId;
  final DepositRequest? initial;

  @override
  State<DepositDetailsScreen> createState() => _DepositDetailsScreenState();
}

class _DepositDetailsScreenState extends State<DepositDetailsScreen> {
  DepositRequest? _request;
  String? _error;

  @override
  void initState() {
    super.initState();
    _request = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (widget.requestId.isEmpty) return;
    final trading = TradingScope.maybeOf(context);
    if (trading == null) return;
    try {
      final row = await trading.getDeposit(widget.requestId);
      if (!mounted) return;
      setState(() => _request = row);
    } catch (_) {
      if (!mounted || _request != null) return;
      setState(() => _error = 'Deposit request not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final colors = context.tpColors;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Deposit details')),
        body: ResponsiveBody(
          maxWidth: 560,
          child: request == null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorState(message: _error ?? 'Loading deposit'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AssetIcon(symbol: request.method.iconSymbol, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  request.method.title,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                              ),
                              Text(
                                request.status.badgeLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: switch (request.status) {
                                    WithdrawStatus.pending => colors.warning,
                                    WithdrawStatus.successful => colors.success,
                                    WithdrawStatus.rejected => colors.danger,
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _Row('Amount', '${AppUtils.formatMoney(request.amountUsd)} USD'),
                          _Row('Network', request.network),
                          _Row('Transaction ID', request.txid),
                          _Row('Request ID', request.requestId),
                          if (request.createdStamp != null)
                            _Row('Submitted', AppUtils.formatDetailStamp(request.createdStamp!)),
                          const SizedBox(height: 8),
                          Text(
                            switch (request.status) {
                              WithdrawStatus.pending =>
                                'Under review. Live Balance is not credited until an administrator approves this request.',
                              WithdrawStatus.successful =>
                                'An administrator approved this request. Live Balance was credited once for this deposit.',
                              WithdrawStatus.rejected =>
                                'This request was rejected. Live Balance was not credited.',
                            },
                            style: TextStyle(color: colors.mutedText, height: 1.4),
                          ),
                          if (request.status == WithdrawStatus.rejected &&
                              (request.rejectionReason ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Rejection Reason:',
                              style: TextStyle(
                                color: colors.danger,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(request.rejectionReason!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: context.tpColors.mutedText)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
