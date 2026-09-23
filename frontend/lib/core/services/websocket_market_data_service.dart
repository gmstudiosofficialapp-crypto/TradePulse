import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/market_models.dart';
import '../constants/app_constants.dart';
import 'market_data_service.dart';

class WebSocketMarketDataService implements MarketDataService {
  WebSocketMarketDataService({
    String? httpBase,
    String? wsUrl,
    Future<String?> Function()? tokenProvider,
  })  : httpBase = httpBase ?? AppConstants.apiBase,
        wsUrl = wsUrl ?? AppConstants.marketWsUrl,
        _tokenProvider = tokenProvider;

  final String httpBase;
  final String wsUrl;
  final Future<String?> Function()? _tokenProvider;

  WebSocketChannel? _channel;
  final _candles = StreamController<MarketCandle>.broadcast();
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _connection = StreamController<EngineState>.broadcast();
  StreamSubscription<dynamic>? _sub;
  final _subscribed = <String>{};
  Timer? _reconnect;
  var _closed = false;
  String? _userId;

  @override
  Stream<MarketCandle> get candleStream => _candles.stream;

  @override
  Stream<Map<String, dynamic>> get eventStream => _events.stream;

  @override
  Stream<EngineState> get connectionState => _connection.stream;

  @override
  Future<void> connect() async {
    _closed = false;
    await _openSocket();
  }

  Future<void> _openSocket() async {
    await _sub?.cancel();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
      await _identifyCurrentUser();
      for (final asset in _subscribed) {
        _send({'type': 'subscribe', 'asset': asset});
      }
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final message = jsonDecode(raw) as Map<String, dynamic>;
      _events.add(message);
      final type = message['type'];
      if (type == 'candle_update' ||
          type == 'candle_close' ||
          type == 'candle_closed') {
        final candle = MarketCandle.fromJson(
          Map<String, dynamic>.from(message['candle'] as Map),
        );
        _candles.add(candle);
      }
    } catch (_) {
      // Invalid market payloads are ignored after parse failure.
    }
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _connection.add(EngineState.reconnecting);
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 2), () {
      if (!_closed) {
        unawaited(_openSocket());
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _closed = true;
    _reconnect?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> _identifyCurrentUser() async {
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return;
    _send({'type': 'identify', 'token': token});
  }

  @override
  Future<void> identify(String userId) async {
    _userId = userId;
    await _identifyCurrentUser();
  }

  @override
  Future<void> subscribeAsset(String asset) async {
    _subscribed.add(asset);
    _send({'type': 'subscribe', 'asset': asset});
  }

  @override
  Future<void> unsubscribeAsset(String asset) async {
    _subscribed.remove(asset);
    _send({'type': 'unsubscribe', 'asset': asset});
  }

  @override
  Future<List<MarketCandle>> getHistoricalCandles(String asset) async {
    final uri = Uri.parse(
      '$httpBase/api/market/candles',
    ).replace(queryParameters: {'asset': asset, 'limit': '500'});
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = body['candles'] as List<dynamic>? ?? [];
    return rows
        .map((row) => MarketCandle.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<List<MarketQuote>> getQuotes() async {
    final response = await http.get(Uri.parse('$httpBase/api/market/quotes'));
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = body['quotes'] as List<dynamic>? ?? [];
    return rows
        .map((row) => MarketQuote.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<MarketStatus> getStatus() async {
    try {
      final response = await http.get(Uri.parse('$httpBase/api/market/status'));
      if (response.statusCode != 200) {
        return const MarketStatus(state: EngineState.offline, simulated: true);
      }
      return MarketStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return const MarketStatus(state: EngineState.offline, simulated: true);
    }
  }
}
