import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/otc_assets.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/chart_entry.dart';
import '../../models/market_models.dart';
import '../../models/trade_models.dart';
import '../../core/services/trading_controller.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/charts/candlestick_chart.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key, this.initialAsset});

  final String? initialAsset;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  Timer? _clock;
  String? _highlightId;
  var _watchlistOpen = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncAsset());
    });
  }

  Future<void> _syncAsset() async {
    final market = AppScope.market(context);
    final trading = AppScope.trading(context);
    final requested = widget.initialAsset;
    if (requested != null &&
        OtcAssets.all.any((asset) => asset.symbol == requested)) {
      await market.focusAsset(requested);
    }
    if (!mounted) return;
    await trading.loadSignal(market.focusedAsset);
    await trading.refresh(asset: market.focusedAsset);
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _place(String direction) async {
    final market = AppScope.market(context);
    final trading = AppScope.trading(context);
    await trading.openTrade(asset: market.focusedAsset, direction: direction);
  }

  Future<void> _selectAsset(String symbol) async {
    final market = AppScope.market(context);
    await market.focusAsset(symbol);
    if (!mounted) return;
    await AppScope.trading(context).loadSignal(symbol);
  }

  @override
  Widget build(BuildContext context) {
    final market = AppScope.market(context);
    final trading = AppScope.trading(context);
    final live = market.status.state == EngineState.liveSimulation;
    final reconnecting = market.status.state == EngineState.reconnecting;
    final signal = trading.signal.asset == market.focusedAsset
        ? trading.signal
        : TradeSignal.waiting(market.focusedAsset);
    final canTrade =
        live && trading.canOpenTrade(market.focusedAsset);

    final panel = _ManualTradePanel(
      trading: trading,
      canTrade: canTrade,
      payoutPct: (AppConstants.payoutRate * 100).round(),
      onBuy: () => _place('BUY'),
      onSell: () => _place('SELL'),
    );
    final watchlist = _Watchlist(
      selected: market.focusedAsset,
      onSelect: (symbol) {
        setState(() => _watchlistOpen = false);
        unawaited(_selectAsset(symbol));
      },
    );
    final entries = ChartEntryMarker.uniqueForAsset(market.focusedAsset, [
      ...trading.history,
    ]);
    final spans = ChartSignalSpan.uniqueForAsset(
      market.focusedAsset,
      trading.signalsFor(market.focusedAsset),
    );
    final lifecycle = _LifecycleStrip(
      trading: trading,
      onSelect: (id) => setState(() => _highlightId = id),
    );

    final hasPositions =
        trading.activeTrades.isNotEmpty || trading.lastResult != null;
    final utc = DateTime.now().toUtc();
    final utcStamp =
        '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:${utc.second.toString().padLeft(2, '0')}UTC';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final watchWidth = math.min(280.0, constraints.maxWidth - 24);
          const ticketReserve = 220.0;
          final chartInsets = EdgeInsets.fromLTRB(
            8,
            56,
            8,
            ticketReserve + (hasPositions ? 88 : 8),
          );

          return Stack(
            children: [
              Positioned.fill(
                child: CandlestickChart(
                  candles: market.candles,
                  entries: entries,
                  spans: spans,
                  highlightId: _highlightId,
                  immersive: true,
                  overlayInsets: chartInsets,
                ),
              ),
              Positioned(
                top: 10,
                left: 12,
                right: 72,
                child: _ChartHud(
                  asset: market.focusedAsset,
                  utcStamp: utcStamp,
                  reconnecting: reconnecting,
                  signal: signal,
                  onToggleWatchlist: () =>
                      setState(() => _watchlistOpen = !_watchlistOpen),
                ),
              ),
              if (_watchlistOpen)
                Positioned(
                  top: 58,
                  left: 12,
                  bottom: ticketReserve + 16,
                  width: watchWidth,
                  child: watchlist,
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPositions)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: lifecycle,
                      ),
                    panel,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChartHud extends StatelessWidget {
  const _ChartHud({
    required this.asset,
    required this.utcStamp,
    required this.reconnecting,
    required this.signal,
    required this.onToggleWatchlist,
  });

  final String asset;
  final String utcStamp;
  final bool reconnecting;
  final TradeSignal signal;
  final VoidCallback onToggleWatchlist;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleWatchlist,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssetIcon(symbol: asset, size: 26),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      asset,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, color: colors.mutedText),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                reconnecting
                    ? 'RECONNECTING'
                    : '$utcStamp  ·  Confidence: ${(signal.confidence * 100).round()}%',
                style: TextStyle(fontSize: 11, color: colors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualTradePanel extends StatefulWidget {
  const _ManualTradePanel({
    required this.trading,
    required this.canTrade,
    required this.payoutPct,
    required this.onBuy,
    required this.onSell,
  });

  final TradingController trading;
  final bool canTrade;
  final int payoutPct;
  final VoidCallback onBuy;
  final VoidCallback onSell;

  @override
  State<_ManualTradePanel> createState() => _ManualTradePanelState();
}

class _ManualTradePanelState extends State<_ManualTradePanel> {
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.trading.stake.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _commitAmount(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '').replaceAll('\$', ''));
    if (parsed == null) return;
    widget.trading.setStake(parsed);
  }

  String _hhmmss(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final rest = safe % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final onEmphasis = Theme.of(context).colorScheme.onSecondary;
    final controller = widget.trading;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: colors.cardBorder.withValues(alpha: 0.7))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final seconds in AppConstants.expiryOptions)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(AppUtils.formatExpiryLabel(seconds)),
                    selected: controller.expirySeconds == seconds,
                    onSelected: (_) => controller.setExpiry(seconds),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TicketField(
                    label: 'Time',
                    value: _hhmmss(controller.expirySeconds),
                    icon: Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TicketField(
                    label: 'Amount',
                    icon: Icons.payments_outlined,
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      onChanged: _commitAmount,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.success,
                      foregroundColor: onEmphasis,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: widget.canTrade ? widget.onBuy : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('BUY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('${widget.payoutPct}%', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.danger,
                      foregroundColor: onEmphasis,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: widget.canTrade ? widget.onSell : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('SELL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('${widget.payoutPct}%', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 8),
              Text(controller.error!, style: TextStyle(color: colors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketField extends StatelessWidget {
  const _TicketField({
    required this.label,
    required this.icon,
    this.value,
    this.child,
  });

  final String label;
  final IconData icon;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.canvasAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: colors.mutedText)),
                if (child != null) child! else Text(
                  value ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Icon(icon, size: 18, color: colors.mutedText),
        ],
      ),
    );
  }
}

class _Watchlist extends StatefulWidget {
  const _Watchlist({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<_Watchlist> createState() => _WatchlistState();
}

class _WatchlistState extends State<_Watchlist> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final market = AppScope.market(context);
    final settings = AppScope.settings(context);
    final q = _query.trim().toLowerCase();
    final assets = [...OtcAssets.all]
      ..sort((a, b) {
        final fa = settings.isFavorite(a.symbol);
        final fb = settings.isFavorite(b.symbol);
        if (fa == fb) return a.symbol.compareTo(b.symbol);
        return fa ? -1 : 1;
      });
    final visible = assets
        .where((asset) => q.isEmpty || asset.symbol.toLowerCase().contains(q))
        .toList();
    return PremiumCard(
      glass: true,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search asset',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final asset = visible[index];
                final quote = market.quotes[asset.symbol];
                final active = asset.symbol == widget.selected;
                final change = quote?.changePct ?? 0;
                final changeColor = change >= 0 ? colors.success : colors.danger;
                return InkWell(
                  onTap: () => widget.onSelect(asset.symbol),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? colors.accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => settings.toggleFavorite(asset.symbol),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              settings.isFavorite(asset.symbol)
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: settings.isFavorite(asset.symbol)
                                  ? colors.accent
                                  : colors.mutedText,
                            ),
                          ),
                        ),
                        AssetIcon(symbol: asset.symbol, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            asset.symbol,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              quote == null ? '-' : AppUtils.formatPrice(quote.price),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              quote == null ? '' : AppUtils.formatChange(change),
                              style: TextStyle(fontSize: 10, color: changeColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleStrip extends StatelessWidget {
  const _LifecycleStrip({
    required this.trading,
    required this.onSelect,
  });

  final TradingController trading;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final actives = trading.activeTrades;
    final result = trading.lastResult;
    return Column(
      children: [
        if (actives.isNotEmpty)
          PremiumCard(
            glass: true,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE DEMO TRADE',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                for (final active in actives)
                  InkWell(
                    onTap: () => onSelect(active.tradeId),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          Text(active.asset),
                          Text('Direction: ${active.direction}'),
                          Text(AppUtils.formatMoney(active.stake)),
                          Text(
                            AppUtils.formatClock(
                              active.expiryTime.difference(DateTime.now().toUtc()).inSeconds,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (result != null) ...[
          if (actives.isNotEmpty) const SizedBox(height: 6),
          PremiumCard(
            glass: true,
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(result.result ?? 'CLOSED', style: Theme.of(context).textTheme.titleLarge),
                Text(result.asset),
                Text('P/L: ${AppUtils.formatSignedMoney(result.profitLoss)}'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

