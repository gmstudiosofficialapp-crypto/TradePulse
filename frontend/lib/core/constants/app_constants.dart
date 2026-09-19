class AppConstants {
  static const String appName = 'TradePulse';
  static const String tagline = 'OTC Demo Trading Simulator';
  static const String version = '0.3.0';
  static const String accountType = 'DEMO';
  static const String demoBalanceLabel = r'$10,000.00';
  static const String selectedTradeAsset = 'BTC/USD-OTC';
  static const List<int> expiryOptions = [5, 15, 30, 60, 300, 900];
  static const double minStake = 1;
  static const double maxStake = 10000;
  static const double payoutRate = 0.85;
  static const List<double> stakePresets = [10, 25, 50, 100, 500];
  static const int maxActiveSignalsPerAsset = 10;
  static const String demoOnlyNotice =
      'OTC / SIMULATED / DEMO. No live-money execution.';
  static const String marketEngineOffline = 'MARKET OFFLINE';
  static const String priceUnavailable = 'Price unavailable';
  static const String liveSimulation = 'LIVE SIMULATION';
  static const String simulatedOtc = 'SIMULATED OTC';

  static const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL');

  /// Local Flutter web-server (8090) talks to the API on 8000.
  /// A shared/public HTTPS origin uses that origin so one URL serves UI + API + WS.
  /// Optional: `--dart-define=API_BASE_URL=https://YOUR-APP.onrender.com`
  static String get apiBase {
    const defined = _apiBaseOverride;
    if (defined.trim().isNotEmpty) {
      return defined.trim().replaceAll(RegExp(r'/$'), '');
    }
    final base = Uri.base;
    final localDev = (base.host == '127.0.0.1' || base.host == 'localhost') &&
        base.port == 8090;
    if (localDev || base.host.isEmpty) {
      return 'http://127.0.0.1:8000';
    }
    return base.origin;
  }

  static String get marketWsUrl {
    final api = Uri.parse(apiBase);
    final scheme = api.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${api.authority}/ws/market';
  }
}
