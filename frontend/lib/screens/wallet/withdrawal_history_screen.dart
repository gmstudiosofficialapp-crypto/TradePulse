import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/withdraw_models.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  List<WithdrawalRequest> _items = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final trading = TradingScope.maybeOf(context);
    if (trading == null) return;
    setState(() => _error = null);
    try {
      final rows = await trading.listWithdrawals();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load withdrawal history';
      });
    }
  }

  void _open(WithdrawalRequest request) {
    Navigator.of(context)
        .pushNamed(AppRoutes.withdrawalDetails, arguments: request)
        .then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Withdrawal History')),
        body: ResponsiveBody(
          maxWidth: 560,
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (_error != null) ErrorState(message: _error!),
                            const SizedBox(height: 24),
                            const EmptyState(
                              title: 'No withdrawals yet',
                              message:
                                  'Submitted withdrawal requests will appear here.',
                              icon: Icons.south_west_rounded,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                          itemCount: _items.length + (_error == null ? 0 : 1),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (_error != null && index == 0) {
                              return ErrorState(message: _error!);
                            }
                            final item = _items[_error == null ? index : index - 1];
                            return _HistoryTile(
                              request: item,
                              onTap: () => _open(item),
                            );
                          },
                        ),
                ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.request, required this.onTap});

  final WithdrawalRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final color = switch (request.status) {
      WithdrawStatus.pending => colors.warning,
      WithdrawStatus.successful => colors.success,
      WithdrawStatus.rejected => colors.danger,
    };
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          AssetIcon(symbol: request.method.iconSymbol, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.method.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  request.requestId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
                Text(
                  '${AppUtils.formatMoney(request.amountUsd)} USD',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  request.paymentDetails,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
                if (request.createdStamp != null)
                  Text(
                    AppUtils.formatDetailStamp(request.createdStamp!),
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                if (request.status == WithdrawStatus.rejected &&
                    (request.rejectionReason ?? '').trim().isNotEmpty)
                  Text(
                    request.rejectionReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.danger),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  request.status.badgeLabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.chevron_right_rounded, color: colors.mutedText),
            ],
          ),
        ],
      ),
    );
  }
}
