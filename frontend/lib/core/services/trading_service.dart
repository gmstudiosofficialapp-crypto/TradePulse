import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/trade_models.dart';
import '../constants/app_constants.dart';
import 'signup_bonus_notice.dart';

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
    if (response.statusCode == 200) {
      applySignupBonusPayload(response.body);
    }
  }

  Future<double> getLiveBalance(String userId) async {
    final response = await http.get(
      Uri.parse('$httpBase/api/live/balance'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return 0;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['balance'] as num).toDouble();
  }

  Future<List<DemoTrade>> getLiveTrades(String userId) async {
    final response = await http.get(
      Uri.parse('$httpBase/api/live/trades'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = body['trades'] as List<dynamic>? ?? [];
    return rows
        .map((row) => DemoTrade.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> previewWithdrawal({
    required double amount,
    required String method,
    required String address,
  }) async {
    final response = await http.post(
      Uri.parse('$httpBase/api/live/withdraw/preview'),
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'method': method,
        'address': address,
      }),
    );
    if (response.statusCode == 401) {
      throw Exception('Session expired. Sign in again.');
    }
    final body = jsonDecode(response.body);
    if (response.statusCode == 400) {
      final detail = body is Map ? body['detail'] : 'Unable to preview withdrawal';
      throw WithdrawValidationException('$detail');
    }
    if (response.statusCode != 200 || body is! Map) {
      throw Exception('Unable to preview withdrawal');
    }
    return Map<String, dynamic>.from(body);
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({String? day}) async {
    final uri = Uri.parse('$httpBase/api/leaderboard').replace(
      queryParameters: {if (day != null) 'day': day},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = body['entries'] as List<dynamic>? ?? [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
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
    bool live = false,
  }) async {
    final response = await http.post(
      Uri.parse('$httpBase/api/demo/trades'),
      headers: await _headers(),
      body: jsonEncode({
        'asset': asset,
        'direction': direction,
        'stake': stake,
        'expiry_seconds': expirySeconds,
        'live': live,
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

class WithdrawValidationException implements Exception {
  WithdrawValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
