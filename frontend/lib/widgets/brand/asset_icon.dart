import 'package:flutter/material.dart';

class AssetIcon extends StatelessWidget {
  const AssetIcon({
    super.key,
    required this.symbol,
    this.size = 32,
  });

  final String symbol;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spec = AssetIconCatalog.of(symbol);
    return Semantics(
      label: symbol,
      child: SizedBox(
        width: size,
        height: size,
        child: spec.primaryAsset == null && spec.secondaryAsset == null
            ? _Fallback(spec: spec, size: size)
            : spec.secondaryAsset == null
                ? _RoundAssetImage(path: spec.primaryAsset!, size: size, fallback: spec)
                : _PairFlags(
                    left: spec.primaryAsset!,
                    right: spec.secondaryAsset!,
                    size: size,
                    fallback: spec,
                  ),
      ),
    );
  }
}

class _RoundAssetImage extends StatelessWidget {
  const _RoundAssetImage({
    required this.path,
    required this.size,
    required this.fallback,
  });

  final String path;
  final double size;
  final AssetIconSpec fallback;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Fallback(spec: fallback, size: size),
      ),
    );
  }
}

class _PairFlags extends StatelessWidget {
  const _PairFlags({
    required this.left,
    required this.right,
    required this.size,
    required this.fallback,
  });

  final String left;
  final String right;
  final double size;
  final AssetIconSpec fallback;

  @override
  Widget build(BuildContext context) {
    final flag = size * 0.72;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: _RoundAssetImage(path: left, size: flag, fallback: fallback),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: _RoundAssetImage(path: right, size: flag, fallback: fallback),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.spec, required this.size});

  final AssetIconSpec spec;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: spec.color.withValues(alpha: 0.18),
        border: Border.all(color: spec.color.withValues(alpha: 0.7)),
      ),
      child: Center(
        child: Text(
          spec.letters,
          style: TextStyle(
            color: spec.color,
            fontSize: size * (spec.letters.length > 2 ? 0.28 : 0.34),
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class AssetIconSpec {
  const AssetIconSpec({
    required this.color,
    required this.letters,
    this.primaryAsset,
    this.secondaryAsset,
  });

  final Color color;
  final String letters;
  final String? primaryAsset;
  final String? secondaryAsset;
}

class AssetIconCatalog {
  static AssetIconSpec of(String symbol) {
    const crypto = 'assets/icons/crypto';
    const flags = 'assets/icons/flags';
    return switch (symbol) {
      'BTC/USD-OTC' => const AssetIconSpec(
          color: Color(0xFFF7931A),
          letters: 'BTC',
          primaryAsset: '$crypto/btc.png',
        ),
      'ETH/USD-OTC' => const AssetIconSpec(
          color: Color(0xFF627EEA),
          letters: 'ETH',
          primaryAsset: '$crypto/eth.png',
        ),
      'SOL/USD-OTC' => const AssetIconSpec(
          color: Color(0xFF9945FF),
          letters: 'SOL',
          primaryAsset: '$crypto/sol.png',
        ),
      'XRP/USD-OTC' => const AssetIconSpec(
          color: Color(0xFF23292F),
          letters: 'XRP',
          primaryAsset: '$crypto/xrp.png',
        ),
      'DOGE/USD-OTC' => const AssetIconSpec(
          color: Color(0xFFC2A633),
          letters: 'DOG',
          primaryAsset: '$crypto/doge.png',
        ),
      'EUR/USD-OTC' => const AssetIconSpec(
          color: Color(0xFF3D5AFE),
          letters: 'EU',
          primaryAsset: '$flags/eu.png',
          secondaryAsset: '$flags/us.png',
        ),
      'GBP/USD-OTC' => const AssetIconSpec(
          color: Color(0xFF1E88E5),
          letters: 'GB',
          primaryAsset: '$flags/gb.png',
          secondaryAsset: '$flags/us.png',
        ),
      'USD/JPY-OTC' => const AssetIconSpec(
          color: Color(0xFFE53935),
          letters: 'JP',
          primaryAsset: '$flags/us.png',
          secondaryAsset: '$flags/jp.png',
        ),
      'AUD/USD-OTC' => const AssetIconSpec(
          color: Color(0xFF00897B),
          letters: 'AU',
          primaryAsset: '$flags/au.png',
          secondaryAsset: '$flags/us.png',
        ),
      'USD/CAD-OTC' => const AssetIconSpec(
          color: Color(0xFFD32F2F),
          letters: 'CA',
          primaryAsset: '$flags/us.png',
          secondaryAsset: '$flags/ca.png',
        ),
      'USD/CHF-OTC' => const AssetIconSpec(
          color: Color(0xFFD50000),
          letters: 'CH',
          primaryAsset: '$flags/us.png',
          secondaryAsset: '$flags/ch.png',
        ),
      'EUR/GBP-OTC' => const AssetIconSpec(
          color: Color(0xFF5C6BC0),
          letters: 'EG',
          primaryAsset: '$flags/eu.png',
          secondaryAsset: '$flags/gb.png',
        ),
      'EUR/JPY-OTC' => const AssetIconSpec(
          color: Color(0xFF8E24AA),
          letters: 'EJ',
          primaryAsset: '$flags/eu.png',
          secondaryAsset: '$flags/jp.png',
        ),
      'GBP/JPY-OTC' => const AssetIconSpec(
          color: Color(0xFF3949AB),
          letters: 'GJ',
          primaryAsset: '$flags/gb.png',
          secondaryAsset: '$flags/jp.png',
        ),
      'AUD/JPY-OTC' => const AssetIconSpec(
          color: Color(0xFF00838F),
          letters: 'AJ',
          primaryAsset: '$flags/au.png',
          secondaryAsset: '$flags/jp.png',
        ),
      'GOLD/USD-OTC' => const AssetIconSpec(
          color: Color(0xFFD4AF37),
          letters: 'XAU',
        ),
      'SILVER/USD-OTC' => const AssetIconSpec(
          color: Color(0xFFB0BEC5),
          letters: 'XAG',
        ),
      'NASDAQ-OTC' => const AssetIconSpec(
          color: Color(0xFF29B6F6),
          letters: 'NDX',
        ),
      'S&P500-OTC' => const AssetIconSpec(
          color: Color(0xFF66BB6A),
          letters: 'SPX',
        ),
      'DOW JONES-OTC' => const AssetIconSpec(
          color: Color(0xFFFFA726),
          letters: 'DJI',
        ),
      _ => AssetIconSpec(
          color: const Color(0xFF2EE6C8),
          letters: symbol.replaceAll('-OTC', '').replaceAll('/', '').substring(
                0,
                symbol.replaceAll('-OTC', '').replaceAll('/', '').length >= 2
                    ? 2
                    : 1,
              ),
        ),
    };
  }
}
