import 'package:flutter/material.dart';

import '../../core/services/admin_service.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/validators.dart';
import '../../models/withdraw_models.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _search = TextEditingController();
  String? _status;
  List<WithdrawalRequest> _items = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = AppScope.admin(context);
    if (admin == null || !admin.isSignedIn) {
      setState(() {
        _loading = false;
        _error = 'Admin authorization required';
      });
      return;
    }
    setState(() => _error = null);
    try {
      final rows = await admin.listWithdrawals(
        status: _status,
        search: _search.text,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load withdrawals';
      });
    }
  }

  Future<void> _approve(WithdrawalRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve Withdrawal?'),
          content: const Text(
            'Are you sure you want to approve this withdrawal?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.admin(context)?.approve(request.requestId);
      if (mounted) await _load();
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _reject(WithdrawalRequest request) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rejection Reason'),
          content: AppTextField(
            label: 'Rejection Reason',
            controller: reason,
            hintText: 'Please make a deposit before requesting a withdrawal.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reject Withdrawal'),
            ),
          ],
        );
      },
    );
    final text = reason.text;
    reason.dispose();
    if (confirmed != true || !mounted) return;
    if (text.trim().isEmpty) {
      setState(() => _error = Validators.withdrawRejectionRequired);
      return;
    }
    try {
      await AppScope.admin(context)?.reject(request.requestId, text.trim());
      if (mounted) await _load();
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Withdrawals')),
        body: ResponsiveBody(
          maxWidth: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Search',
                      controller: _search,
                      hintText: 'User or Request ID',
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _load,
                        child: const Text('Apply search'),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final item in <(String?, String)>[
                          (null, 'All'),
                          ('Pending', 'Pending'),
                          ('Successful', 'Successful'),
                          ('Rejected', 'Rejected'),
                        ])
                          ChoiceChip(
                            label: Text(item.$2),
                            selected: _status == item.$1,
                            onSelected: (_) {
                              setState(() => _status = item.$1);
                              _load();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ErrorState(message: _error!),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 48),
                                  EmptyState(
                                    title: 'No withdrawals',
                                    message:
                                        'Withdrawal requests will appear here.',
                                    icon: Icons.account_balance_wallet_outlined,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                                itemCount: _items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  return _AdminTile(
                                    request: item,
                                    onApprove: item.status ==
                                            WithdrawStatus.pending
                                        ? () => _approve(item)
                                        : null,
                                    onReject: item.status ==
                                            WithdrawStatus.pending
                                        ? () => _reject(item)
                                        : null,
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final WithdrawalRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetIcon(symbol: request.method.iconSymbol, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  request.requestId,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                request.status.label,
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
          const SizedBox(height: 10),
          Text(request.accountLabel.isEmpty ? request.userId ?? '' : request.accountLabel),
          Text('${AppUtils.formatMoney(request.amountUsd)} USD'),
          Text(request.method.title),
          Text(
            request.paymentDetails,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (request.createdStamp != null)
            Text(
              AppUtils.formatDetailStamp(request.createdStamp!),
              style: TextStyle(color: colors.mutedText, fontSize: 12),
            ),
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onApprove != null)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                const SizedBox(width: 8),
                if (onReject != null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: onReject,
                    child: const Text('Reject'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
