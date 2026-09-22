import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/constants/otc_assets.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/models/chart_entry.dart';
import 'package:tradepulse_frontend/models/market_models.dart';
import 'package:tradepulse_frontend/models/trade_models.dart';
import 'package:tradepulse_frontend/widgets/brand/asset_icon.dart';

void main() {
  test('entry marker uses the candle that contains the timestamp', () {
    final candles = [
      MarketCandle(
        asset: 'BTC/USD-OTC',
        open: 1,
        high: 2,
        low: 0.5,
        close: 1.2,
        volume: 4,
        openTime: DateTime.utc(2026, 9, 19, 20, 5),
        closeTime: DateTime.utc(2026, 9, 19, 20, 6),
        closed: true,
      ),
      MarketCandle(
        asset: 'BTC/USD-OTC',
        open: 1.2,
        high: 1.4,
        low: 1.1,
        close: 1.3,
        volume: 4,
        openTime: DateTime.utc(2026, 9, 19, 20, 6),
        closeTime: DateTime.utc(2026, 9, 19, 20, 7),
        closed: true,
      ),
    ];
    final match = candleForEntry(
      candles,
      DateTime.utc(2026, 9, 19, 20, 5, 13),
    );
    expect(match?.openTime, DateTime.utc(2026, 9, 19, 20, 5));
    expect(
      candleForEntry(candles, DateTime.utc(2026, 9, 19, 20, 6, 0))?.openTime,
      DateTime.utc(2026, 9, 19, 20, 6),
    );
  });

  test('markers dedupe by trade id', () {
    final trade = DemoTrade(
      tradeId: 'same',
      asset: 'EUR/USD-OTC',
      direction: 'SELL',
      stake: 10,
      entryPrice: 1.08,
      entryTime: DateTime.utc(2026, 9, 19, 10),
      expiryTime: DateTime.utc(2026, 9, 19, 10, 0, 30),
      status: 'CLOSED',
      result: 'WIN',
      expirySeconds: 30,
    );
    final markers = ChartEntryMarker.uniqueForAsset('EUR/USD-OTC', [trade, trade]);
    expect(markers, isEmpty);
  });

  test('open trade markers stay until close', () {
    final trade = DemoTrade(
      tradeId: 'live',
      asset: 'BTC/USD-OTC',
      direction: 'BUY',
      stake: 10,
      entryPrice: 67000,
      entryTime: DateTime.utc(2026, 9, 19, 10),
      expiryTime: DateTime.utc(2026, 9, 19, 10, 0, 30),
      status: 'OPEN',
      expirySeconds: 30,
    );
    expect(ChartEntryMarker.uniqueForAsset('BTC/USD-OTC', [trade]), hasLength(1));
  });

  test('entry index stays on the candle that contains the time', () {
    final candles = [
      MarketCandle(
        asset: 'BTC/USD-OTC',
        open: 1,
        high: 2,
        low: 0.5,
        close: 1.2,
        volume: 4,
        openTime: DateTime.utc(2026, 9, 19, 20, 5),
        closeTime: DateTime.utc(2026, 9, 19, 20, 6),
        closed: true,
      ),
      MarketCandle(
        asset: 'BTC/USD-OTC',
        open: 1.2,
        high: 1.4,
        low: 1.1,
        close: 1.3,
        volume: 4,
        openTime: DateTime.utc(2026, 9, 19, 20, 6),
        closeTime: DateTime.utc(2026, 9, 19, 20, 7),
        closed: true,
      ),
    ];
    expect(indexOfEntry(candles, DateTime.utc(2026, 9, 19, 20, 5, 13)), 0);
    expect(indexOfEntry(candles, DateTime.utc(2026, 9, 19, 20, 6)), 1);
  });

  test('optional profile fields can stay empty', () async {
    final auth = LocalAuthService();
    await auth.signup(
      fullName: 'Ada Trader',
      email: 'ada@example.com',
      password: 'DemoPass1',
    );
    await auth.updateProfile(fullName: 'Ada Trader');
    expect(auth.currentUser()?.fullName, 'Ada Trader');
    expect(auth.currentUser()?.phone, '');
    await auth.updateProfile(
      fullName: 'Ada Trader',
      phone: '01700000000',
      country: 'Bangladesh',
    );
    expect(auth.currentUser()?.phone, '01700000000');
    expect(auth.currentUser()?.country, 'Bangladesh');
    expect(auth.currentUser()?.district, '');
  });

  test('signal spans stay unique per signalId', () {
    final first = TradeSignal(
      signalId: 's1',
      asset: 'BTC/USD-OTC',
      direction: 'BUY',
      confidence: 0.9,
      status: 'ACTIVE',
      entryPrice: 100,
      generatedAt: DateTime.utc(2026, 9, 19, 20, 5),
    );
    final second = TradeSignal(
      signalId: 's2',
      asset: 'BTC/USD-OTC',
      direction: 'SELL',
      confidence: 0.8,
      status: 'CLOSED',
      entryPrice: 101,
      generatedAt: DateTime.utc(2026, 9, 19, 20, 6),
      expiryTime: DateTime.utc(2026, 9, 19, 20, 7),
      closePrice: 99,
      result: 'WIN',
    );
    final spans = ChartSignalSpan.uniqueForAsset('BTC/USD-OTC', [first, first, second]);
    expect(spans, hasLength(1));
    expect(spans.single.signalId, 's1');
  });

  test('authentic crypto icon paths are bundled', () {
    expect(AssetIconCatalog.of('BTC/USD-OTC').primaryAsset, contains('btc.png'));
    expect(AssetIconCatalog.of('ETH/USD-OTC').primaryAsset, contains('eth.png'));
    expect(AssetIconCatalog.of('BTC').primaryAsset, contains('btc.png'));
    expect(AssetIconCatalog.of('USDT').primaryAsset, contains('usdt.png'));
    expect(AssetIconCatalog.of('USDC').primaryAsset, contains('usdc.png'));
    expect(AssetIconCatalog.of('NASDAQ-OTC').primaryAsset, isNull);
  });

  test('twenty assets use the 92/90/85/80 payout split', () {
    expect(OtcAssets.all, hasLength(20));
    expect(OtcAssets.payoutRates, hasLength(20));
    expect(OtcAssets.payoutLabel('BTC/USD-OTC'), '92%');
    expect(OtcAssets.payoutLabel('XRP/USD-OTC'), '90%');
    expect(OtcAssets.payoutLabel('DOGE/USD-OTC'), '85%');
    expect(OtcAssets.payoutLabel('DOW JONES-OTC'), '80%');
    expect(OtcAssets.payoutRates.values.where((rate) => rate == 0.92), hasLength(10));
    expect(OtcAssets.payoutRates.values.where((rate) => rate == 0.90), hasLength(2));
    expect(OtcAssets.payoutRates.values.where((rate) => rate == 0.85), hasLength(5));
    expect(OtcAssets.payoutRates.values.where((rate) => rate == 0.80), hasLength(3));
  });
}
