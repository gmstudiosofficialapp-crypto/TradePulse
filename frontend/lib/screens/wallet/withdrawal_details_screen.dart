import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/withdraw_models.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class WithdrawalDetailsScreen extends StatefulWidget {
  const WithdrawalDetailsScreen({
    super.key,
    required this.requestId,
    this.initial,
  });

  final String requestId;
  final WithdrawalRequest? initial;

  @override
  State<WithdrawalDetailsScreen> createState() =>
      _WithdrawalDetailsScreenState();
}

class _WithdrawalDetailsScreenState extends State<WithdrawalDetailsScreen> {
  WithdrawalRequest? _request;
  String? _error;
  var _loading = true;
  Timer? _poll;
  String? _copiedKey;

  @override
  void initState() {
    super.initState();
    _request = widget.initial;
    _loading = widget.initial == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.requestId.trim();
    if (id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Withdrawal request not found';
      });
      return;
    }
    final trading = TradingScope.maybeOf(context);
    if (trading == null) return;
    try {
      final next = await trading.getWithdrawal(id);
      if (!mounted) return;
      setState(() {
        _request = next;
        _error = null;
        _loading = false;
      });
      if (next.status != WithdrawStatus.pending) {
        _poll?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      if (_request != null) return;
      setState(() {
        _loading = false;
        _error = 'Withdrawal request not found';
      });
    }
  }

  Future<void> _copy(String key, String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copiedKey = key);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        duration: Duration(milliseconds: 1400),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedKey == key) {
        setState(() => _copiedKey = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Withdrawal details')),
        body: ResponsiveBody(
          maxWidth: 560,
          child: request == null
              ? _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: ErrorState(
                        message: _error ?? 'Withdrawal request not found',
                      ),
                    )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _StatusCard(request: request),
                      const SizedBox(height: 14),
                      _DetailsCard(
                        request: request,
                        copiedKey: _copiedKey,
                        onCopy: _copy,
                      ),
                      const SizedBox(height: 14),
                      _InfoCard(request: request),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.request});

  final WithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final amount = '${AppUtils.formatMoney(request.amountUsd)} USD';
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBadge(status: request.status),
          const SizedBox(height: 14),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 16),
          Divider(color: colors.cardBorder.withValues(alpha: 0.7), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                AssetIcon(symbol: request.method.iconSymbol, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.method.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.mutedText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          Divider(color: colors.cardBorder.withValues(alpha: 0.7), height: 1),
          const SizedBox(height: 16),
          _Timeline(steps: request.timeline),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});

  final List<WithdrawTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            lineKind: i + 1 < steps.length ? steps[i + 1].kind : steps[i].kind,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.lineKind,
  });

  final WithdrawTimelineStep step;
  final bool isLast;
  final WithdrawTimelineKind lineKind;

  Color _dotColor(TradePulseColors colors) {
    return switch (step.kind) {
      WithdrawTimelineKind.completed ||
      WithdrawTimelineKind.active =>
        colors.accentSecondary,
      WithdrawTimelineKind.rejected => colors.danger,
      WithdrawTimelineKind.pending => colors.mutedText.withValues(alpha: 0.45),
    };
  }

  Color _lineColor(TradePulseColors colors) {
    return switch (lineKind) {
      WithdrawTimelineKind.completed ||
      WithdrawTimelineKind.active ||
      WithdrawTimelineKind.rejected =>
        colors.accentSecondary.withValues(alpha: 0.7),
      WithdrawTimelineKind.pending => colors.cardBorder,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final accent = _dotColor(colors);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                _TimelineDot(kind: step.kind, color: accent),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: _lineColor(colors),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: step.kind == WithdrawTimelineKind.pending
                                ? colors.mutedText
                                : null,
                          ),
                        ),
                      ),
                      _TimelineStatus(kind: step.kind),
                    ],
                  ),
                  if (step.at != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppUtils.formatDetailStamp(step.at!),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.kind, required this.color});

  final WithdrawTimelineKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = kind != WithdrawTimelineKind.pending;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: filled ? 0 : 2),
      ),
      child: kind == WithdrawTimelineKind.completed
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : kind == WithdrawTimelineKind.rejected
              ? const Icon(Icons.close, size: 14, color: Colors.white)
              : kind == WithdrawTimelineKind.active
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
    );
  }
}

class _TimelineStatus extends StatelessWidget {
  const _TimelineStatus({required this.kind});

  final WithdrawTimelineKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    if (kind == WithdrawTimelineKind.completed) {
      return Icon(Icons.check, size: 18, color: colors.accentSecondary);
    }
    final label = switch (kind) {
      WithdrawTimelineKind.active => 'In progress',
      WithdrawTimelineKind.pending => 'Pending',
      WithdrawTimelineKind.rejected => 'Rejected',
      WithdrawTimelineKind.completed => '',
    };
    final color = switch (kind) {
      WithdrawTimelineKind.active => colors.accentSecondary,
      WithdrawTimelineKind.rejected => colors.danger,
      _ => colors.mutedText,
    };
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.request,
    required this.copiedKey,
    required this.onCopy,
  });

  final WithdrawalRequest request;
  final String? copiedKey;
  final Future<void> Function(String key, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _DetailRow(
        label: 'Transaction ID',
        value: request.requestId,
        copyKey: 'txid',
        copiedKey: copiedKey,
        onCopy: onCopy,
      ),
      _DetailRow(
        label: 'Withdrawal method',
        value: request.method.title,
      ),
      _DetailRow(
        label: 'Amount',
        value: request.method.category == WithdrawCategory.p2p &&
                request.amountBdt != null
            ? '${AppUtils.formatMoney(request.amountUsd)}  ·  ${AppUtils.formatBdt(request.amountBdt!)}'
            : '${AppUtils.formatMoney(request.amountUsd)} USD',
      ),
      if (request.method.network != null)
        _DetailRow(
          label: 'Network',
          value: request.method.network!,
        ),
      _DetailRow(
        label: 'Payment details',
        value: request.paymentDetails,
        copyKey: 'pay',
        copiedKey: copiedKey,
        onCopy: onCopy,
        mono: true,
      ),
      if (request.createdStamp != null) ...[
        _DetailRow(
          label: 'Date',
          value: AppUtils.formatDetailDate(request.createdStamp!),
        ),
        _DetailRow(
          label: 'Time',
          value: AppUtils.formatDetailTime(request.createdStamp!),
        ),
      ],
      _DetailRow(
        label: 'Status',
        value: request.status.badgeLabel,
        trailing: _StatusBadge(status: request.status, compact: true),
      ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: context.tpColors.cardBorder.withValues(alpha: 0.55),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyKey,
    this.copiedKey,
    this.onCopy,
    this.mono = false,
    this.trailing,
  });

  final String label;
  final String value;
  final String? copyKey;
  final String? copiedKey;
  final Future<void> Function(String key, String value)? onCopy;
  final bool mono;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final copied = copyKey != null && copiedKey == copyKey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: trailing ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.35,
                    fontFamily: mono ? 'monospace' : null,
                  ),
                ),
          ),
          if (copyKey != null && value.isNotEmpty) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => onCopy?.call(copyKey!, value),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16,
                  color: copied ? colors.success : colors.mutedText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.request});

  final WithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final reason = (request.rejectionReason ?? '').trim();
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            request.status == WithdrawStatus.successful
                ? Icons.check_circle_outline
                : request.status == WithdrawStatus.rejected
                    ? Icons.info_outline
                    : Icons.hourglass_top_rounded,
            color: request.status == WithdrawStatus.successful
                ? colors.success
                : request.status == WithdrawStatus.rejected
                    ? colors.danger
                    : colors.accentSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.status.infoTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                if (request.status == WithdrawStatus.pending) ...[
                  const SizedBox(height: 6),
                  Text(
                    request.status.infoBody,
                    style: TextStyle(
                      color: colors.mutedText,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (request.status == WithdrawStatus.rejected) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Rejection Reason:',
                    style: TextStyle(
                      color: colors.mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (reason.isNotEmpty)
                    Text(
                      reason,
                      style: const TextStyle(height: 1.4, fontSize: 13),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.compact = false});

  final WithdrawStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final color = switch (status) {
      WithdrawStatus.pending => colors.warning,
      WithdrawStatus.successful => colors.success,
      WithdrawStatus.rejected => colors.danger,
    };
    return Align(
      alignment: compact ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          status.badgeLabel,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 11 : 12,
          ),
        ),
      ),
    );
  }
}
