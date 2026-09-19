import '../../models/market_models.dart';

abstract class MarketDataService {
  Future<void> connect();
  Future<void> disconnect();
  Future<void> subscribeAsset(String asset);
  Future<void> unsubscribeAsset(String asset);
  Stream<MarketCandle> get candleStream;
  Stream<Map<String, dynamic>> get eventStream;
  Stream<EngineState> get connectionState;
  Future<List<MarketCandle>> getHistoricalCandles(String asset);
  Future<List<MarketQuote>> getQuotes();
  Future<MarketStatus> getStatus();
  Future<void> identify(String userId);
}
