import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/otc_assets.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/services/settings_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/chart_entry.dart';
import '../../models/market_models.dart';
import '../../models/trade_models.dart';
import '../../core/services/trading_controller.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/buttons/pressable.dart';
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
  Timer? _flashTimer;
  String? _highlightId;
  String? _seenResultId;
  String? _flashResult;
  var _watchlistOpen = false;
  var _activeOpen = false;
  TradingController? _trading;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.trading(context);
    if (_trading != next) {
      _trading?.removeListener(_onTrading);
      _trading = next..addListener(_onTrading);
    }
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
    _flashTimer?.cancel();
    _trading?.removeListener(_onTrading);
    super.dispose();
  }

  void _onTrading() {
    if (!mounted) return;
    final result = AppScope.trading(context).lastResult;
    if (result == null || result.result == null) return;
    if (result.tradeId == _seenResultId) return;
    _seenResultId = result.tradeId;
    setState(() => _flashResult = result.result);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _flashResult = null);
    });
  }

  Future<void> _place(String direction) async {
    if (AppScope.settings(context).isLiveMode) {
      await _showLiveBlocked();
      return;
    }
    final market = AppScope.market(context);
    final trading = AppScope.trading(context);
    await trading.openTrade(asset: market.focusedAsset, direction: direction);
  }

  Future<void> _showLiveBlocked() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Insufficient Balance'),
          content: const Text(
            'Your live balance is \$0.00.\nLive trading is unavailable.',
          ),
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
    final settings = AppScope.settings(context);
    final live = market.status.state == EngineState.liveSimulation;
    final reconnecting = market.status.state == EngineState.reconnecting;
    final liveUi = settings.isLiveMode;
    final canTrade = liveUi ? true : live;
    final quote = market.quotes[market.focusedAsset];

    final panel = _ManualTradePanel(
      trading: trading,
      canTrade: canTrade,
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
    final actives = trading.activeTrades;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final watchWidth = math.min(280.0, constraints.maxWidth - 24);
          const ticketReserve = 214.0;

          return Stack(
            children: [
              Positioned.fill(
                child: CandlestickChart(
                  candles: market.candles,
                  entries: entries,
                  spans: spans,
                  highlightId: _highlightId,
                  immersive: true,
                  livePrice: quote?.price,
                  overlayInsets: const EdgeInsets.fromLTRB(0, 92, 0, 8),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: _TradeTopBar(
                  asset: market.focusedAsset,
                  price: quote?.price,
                  reconnecting: reconnecting,
                  onToggleWatchlist: () =>
                      setState(() => _watchlistOpen = !_watchlistOpen),
                ),
              ),
              if (_flashResult != null)
                Positioned(
                  top: 96,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(child: _ResultFlash(result: _flashResult!)),
                  ),
                ),
              if (_watchlistOpen)
                Positioned(
                  top: 96,
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
                    if (actives.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: _ActiveTradesBar(
                          trades: actives,
                          expanded: _activeOpen,
                          onToggle: () => setState(() => _activeOpen = !_activeOpen),
                          onSelect: (id) => setState(() => _highlightId = id),
                        ),
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

class _TradeTopBar extends StatelessWidget {
  const _TradeTopBar({
    required this.asset,
    required this.price,
    required this.reconnecting,
    required this.onToggleWatchlist,
  });

  final String asset;
  final double? price;
  final bool reconnecting;
  final VoidCallback onToggleWatchlist;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final user = AppScope.auth(context).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Pressable(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colors.accent.withValues(alpha: 0.18),
                child: Text(
                  user?.initials ?? 'TP',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Spacer(),
            const _ModeBalanceControl(),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleWatchlist,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        AssetIcon(symbol: asset, size: 26),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            asset,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.expand_more, color: colors.mutedText, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price == null ? '—' : AppUtils.formatPrice(price!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (reconnecting)
                  Text(
                    'RECONNECTING',
                    style: TextStyle(fontSize: 11, color: colors.mutedText),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeBalanceControl extends StatelessWidget {
  const _ModeBalanceControl();

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final settings = AppScope.settings(context);
    final trading = AppScope.trading(context);
    final live = settings.isLiveMode;
    final label = live ? 'LIVE' : 'DEMO';
    final balance = live ? 0.0 : trading.demoDisplayBalance;

    return Pressable(
      onPressed: () => _openSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.cardBorder.withValues(alpha: 0.8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: live ? colors.danger : colors.accent,
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: colors.mutedText),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                AppUtils.formatMoney(balance),
                key: ValueKey('$label-$balance'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final settings = AppScope.settings(context);
    final trading = AppScope.trading(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.tpColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Trading mode', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 12),
                _ModeTile(
                  title: 'DEMO MODE',
                  subtitle: 'Simulated balance and trading',
                  selected: !settings.isLiveMode,
                  onTap: () {
                    settings.setTradingUiMode(TradingUiMode.demo);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 8),
                _ModeTile(
                  title: 'LIVE MODE',
                  subtitle: 'Live-style interface',
                  selected: settings.isLiveMode,
                  onTap: () {
                    settings.setTradingUiMode(TradingUiMode.live);
                    Navigator.pop(sheetContext);
                  },
                ),
                if (!settings.isLiveMode) ...[
                  const SizedBox(height: 18),
                  Text('Balance', style: Theme.of(sheetContext).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    AppUtils.formatMoney(trading.demoDisplayBalance),
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openDeposit(context);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Deposit'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDeposit(BuildContext context) async {
    final trading = AppScope.trading(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.tpColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Demo deposit', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Simulated demo funds only. Not a real payment.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amount in const [100.0, 500.0, 1000.0, 5000.0])
                      OutlinedButton(
                        onPressed: () {
                          unawaited(trading.addDemoFunds(amount));
                          Navigator.pop(sheetContext);
                        },
                        child: Text('+${AppUtils.formatMoney(amount)}'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    unawaited(trading.restoreDemoFunds());
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Restore \$10,000.00'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Pressable(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.12)
              : colors.canvasAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.accent : colors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: colors.mutedText)),
          ],
        ),
      ),
    );
  }
}

class _ManualTradePanel extends StatefulWidget {
  const _ManualTradePanel({
    required this.trading,
    required this.canTrade,
    required this.onBuy,
    required this.onSell,
  });

  final TradingController trading;
  final bool canTrade;
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
    if (parsed < AppConstants.minStake) {
      widget.trading.showMessage('Minimum trade amount is \$1.');
    } else if (parsed > AppConstants.maxStake) {
      widget.trading.showMessage('Maximum trade amount is \$10,000.');
    } else if (widget.trading.error == 'Minimum trade amount is \$1.' ||
        widget.trading.error == 'Maximum trade amount is \$10,000.') {
      widget.trading.showMessage('');
    }
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
        color: colors.card.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: colors.cardBorder.withValues(alpha: 0.7))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.canTrade ? widget.onBuy : null,
                      child: const Text(
                        'BUY',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.danger,
                        foregroundColor: onEmphasis,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.canTrade ? widget.onSell : null,
                      child: const Text(
                        'SELL',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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

class _ResultFlash extends StatelessWidget {
  const _ResultFlash({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final win = result == 'WIN';
    final colors = context.tpColors;
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: (win ? colors.success : colors.danger).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          win ? 'WIN' : 'LOSS',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ActiveTradesBar extends StatelessWidget {
  const _ActiveTradesBar({
    required this.trades,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final List<DemoTrade> trades;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  String _countdown(DemoTrade trade) {
    final seconds = trade.expiryTime.difference(DateTime.now().toUtc()).inSeconds;
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final rest = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Column(
      children: [
        Pressable(
          onPressed: onToggle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.cardBorder.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Text(
                  'Active ${trades.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final trade in trades)
                        Text(
                          _countdown(trade),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colors.mutedText,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final trade in trades)
                  InkWell(
                    onTap: () => onSelect(trade.tradeId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            trade.direction,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: trade.direction == 'BUY'
                                  ? colors.success
                                  : colors.danger,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(AppUtils.formatMoney(trade.stake), style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          Text(
                            AppUtils.formatPrice(trade.entryPrice),
                            style: TextStyle(fontSize: 12, color: colors.mutedText),
                          ),
                          const Spacer(),
                          Text(
                            _countdown(trade),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

