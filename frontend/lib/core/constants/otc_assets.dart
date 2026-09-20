import '../../models/otc_asset.dart';
import 'app_constants.dart';

class OtcAssets {
  static const popular = [
    OtcAsset(symbol: 'BTC/USD-OTC', category: AssetCategory.crypto),
    OtcAsset(symbol: 'ETH/USD-OTC', category: AssetCategory.crypto),
    OtcAsset(symbol: 'EUR/USD-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'GOLD/USD-OTC', category: AssetCategory.commodities),
    OtcAsset(symbol: 'NASDAQ-OTC', category: AssetCategory.indices),
    OtcAsset(symbol: 'GBP/USD-OTC', category: AssetCategory.forex),
  ];

  static const all = [
    OtcAsset(symbol: 'BTC/USD-OTC', category: AssetCategory.crypto),
    OtcAsset(symbol: 'ETH/USD-OTC', category: AssetCategory.crypto),
    OtcAsset(symbol: 'SOL/USD-OTC', category: AssetCategory.crypto),
    OtcAsset(symbol: 'XRP/USD-OTC', category: AssetCategory.crypto),
    OtcAsset(symbol: 'DOGE/USD-OTC', category: AssetCategory.crypto),
    OtcAsset(symbol: 'EUR/USD-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'GBP/USD-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'USD/JPY-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'AUD/USD-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'USD/CAD-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'USD/CHF-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'EUR/GBP-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'EUR/JPY-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'GBP/JPY-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'AUD/JPY-OTC', category: AssetCategory.forex),
    OtcAsset(symbol: 'GOLD/USD-OTC', category: AssetCategory.commodities),
    OtcAsset(symbol: 'SILVER/USD-OTC', category: AssetCategory.commodities),
    OtcAsset(symbol: 'NASDAQ-OTC', category: AssetCategory.indices),
    OtcAsset(symbol: 'S&P500-OTC', category: AssetCategory.indices),
    OtcAsset(symbol: 'DOW JONES-OTC', category: AssetCategory.indices),
  ];

  static const payoutRates = <String, double>{
    'BTC/USD-OTC': 0.92,
    'ETH/USD-OTC': 0.92,
    'SOL/USD-OTC': 0.92,
    'EUR/USD-OTC': 0.92,
    'GBP/USD-OTC': 0.92,
    'USD/JPY-OTC': 0.92,
    'GOLD/USD-OTC': 0.92,
    'NASDAQ-OTC': 0.92,
    'S&P500-OTC': 0.92,
    'EUR/JPY-OTC': 0.92,
    'XRP/USD-OTC': 0.90,
    'GBP/JPY-OTC': 0.90,
    'DOGE/USD-OTC': 0.85,
    'AUD/USD-OTC': 0.85,
    'USD/CAD-OTC': 0.85,
    'SILVER/USD-OTC': 0.85,
    'EUR/GBP-OTC': 0.85,
    'USD/CHF-OTC': 0.80,
    'AUD/JPY-OTC': 0.80,
    'DOW JONES-OTC': 0.80,
  };

  static double payoutRate(String symbol) =>
      payoutRates[symbol] ?? AppConstants.payoutRate;

  static String payoutLabel(String symbol) =>
      '${(payoutRate(symbol) * 100).round()}%';

  static String categoryLabel(AssetCategory category) {
    return switch (category) {
      AssetCategory.crypto => 'CRYPTO',
      AssetCategory.forex => 'FOREX',
      AssetCategory.commodities => 'COMMODITIES',
      AssetCategory.indices => 'INDICES',
    };
  }
}
