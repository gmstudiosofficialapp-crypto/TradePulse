import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/trade_models.dart';
import '../constants/app_constants.dart';

class TradingService {
  TradingService({
    String? httpBase,
    Future<String?> Function()? tokenProvider,
  })  : httpBase = httpBase ?? AppConstants.apiBase,
        _tokenProvider = tokenProvider;

  final String httpBase;
  final Future<String?> Function()? _tokenProvider;

  Future<Map<String, String>> _headers() async {
    final token = await _tokenProvider?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> ensureAccount() async {
    final response = await http.post(
      Uri.parse('$httpBase/api/me'),
      headers: await _headers(),
    );
    if (response.statusCode == 401) {
      throw Exception('Session expired. Sign in again.');
    }
  }

  Future<double> getBalance(String userId) async {
    final response = await http.get(
      Uri.parse('$httpBase/api/demo/balance'),
      headers: await _headers(),
    );
    if (response.statusCode == 401) {
      throw Exception('Session expired. Sign in again.');
    }
    if (response.statusCode != 200) return 10000;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['balance'] as num).toDouble();
  }

  Future<double> creditDemo(double amount) async {
    final response = await http.post(
      Uri.parse('$httpBase/api/demo/credit'),
      headers: await _headers(),
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode == 401) {
      throw Exception('Session expired. Sign in again.');
    }
    if (response.statusCode != 200) {
      throw Exception('Unable to add demo balance');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['balance'] as num).toDouble();
  }

  Future<DemoStatistics> getStatistics(String userId) async {
    final response = await http.get(
      Uri.parse('$httpBase/api/demo/statistics'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return const DemoStatistics();
    return DemoStatistics.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<DemoTrade>> getTrades(String userId) async {
    final response = await http.get(
      Uri.parse('$httpBase/api/demo/trades'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = body['trades'] as List<dynamic>? ?? [];
    return rows
        .map((row) => DemoTrade.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<DemoTrade> openTrade({
    required String userId,
    required String asset,
    required String direction,
    required double stake,
    int expirySeconds = 60,
  }) async {
    final response = await http.post(
      Uri.parse('$httpBase/api/demo/trades'),
      headers: await _headers(),
      body: jsonEncode({
        'asset': asset,
        'direction': direction,
        'stake': stake,
        'expiry_seconds': expirySeconds,
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : 'Unable to open demo trade';
      throw Exception(detail);
    }
    return DemoTrade.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<TradeSignal>> listSignals(String asset) async {
    final uri = Uri.parse('$httpBase/api/signals').replace(
      queryParameters: {'asset': asset},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = body['signals'] as List<dynamic>? ?? [];
    return rows
        .map((row) => TradeSignal.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<TradeSignal> latestSignal(String asset) async {
    final uri = Uri.parse('$httpBase/api/signals/latest').replace(
      queryParameters: {'asset': asset},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return TradeSignal.waiting(asset);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final signal = body['signal'];
    if (signal is Map) {
      return TradeSignal.fromJson(Map<String, dynamic>.from(signal));
    }
    return TradeSignal.waiting(asset);
  }
}
