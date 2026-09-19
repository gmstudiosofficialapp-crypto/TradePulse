import '../../models/otc_asset.dart';

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

  static String categoryLabel(AssetCategory category) {
    return switch (category) {
      AssetCategory.crypto => 'CRYPTO',
      AssetCategory.forex => 'FOREX',
      AssetCategory.commodities => 'COMMODITIES',
      AssetCategory.indices => 'INDICES',
    };
  }
}
