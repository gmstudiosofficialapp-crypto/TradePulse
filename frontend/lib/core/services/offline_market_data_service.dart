import '../../models/market_models.dart';
import 'market_data_service.dart';

class OfflineMarketDataService implements MarketDataService {
  @override
  Stream<MarketCandle> get candleStream => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get eventStream => const Stream.empty();

  @override
  Stream<EngineState> get connectionState => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> subscribeAsset(String asset) async {}

  @override
  Future<void> unsubscribeAsset(String asset) async {}

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<List<MarketCandle>> getHistoricalCandles(String asset) async => [];

  @override
  Future<List<MarketQuote>> getQuotes() async => [];

  @override
  Future<MarketStatus> getStatus() async {
    return const MarketStatus(state: EngineState.offline, simulated: true);
  }
}
