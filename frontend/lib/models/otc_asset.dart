enum AssetCategory { crypto, forex, commodities, indices }

class OtcAsset {
  const OtcAsset({
    required this.symbol,
    required this.category,
  });

  final String symbol;
  final AssetCategory category;
}
