import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/withdraw_models.dart';
import '../constants/app_constants.dart';

class AdminAuthException implements Exception {
  AdminAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminService {
  AdminService({String? httpBase}) : httpBase = httpBase ?? AppConstants.apiBase;

  final String httpBase;
  String? token;

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<void> login({required String username, required String password}) async {
    final response = await http.post(
      Uri.parse('$httpBase/api/admin/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 401) {
      throw AdminAuthException('Invalid admin credentials');
    }
    if (response.statusCode != 200 || body is! Map || body['token'] == null) {
      throw AdminAuthException('Unable to sign in');
    }
    token = '${body['token']}';
  }

  Future<List<WithdrawalRequest>> listWithdrawals({
    String? status,
    String? search,
  }) async {
    final uri = Uri.parse('$httpBase/api/admin/withdrawals').replace(
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 401) {
      throw AdminAuthException('Admin session expired');
    }
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = body['withdrawals'] as List<dynamic>? ?? [];
    return rows
        .map((row) => WithdrawalRequest.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<WithdrawalRequest> approve(String requestId) async {
    final response = await http.post(
      Uri.parse('$httpBase/api/admin/withdrawals/$requestId/approve'),
      headers: _headers(),
    );
    return _parseMutation(response);
  }

  Future<WithdrawalRequest> reject(String requestId, String reason) async {
    final response = await http.post(
      Uri.parse('$httpBase/api/admin/withdrawals/$requestId/reject'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    return _parseMutation(response);
  }

  WithdrawalRequest _parseMutation(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode == 401) {
      throw AdminAuthException('Admin session expired');
    }
    if (response.statusCode != 200 || body is! Map || body['request'] is! Map) {
      final detail = body is Map ? body['detail'] : 'Unable to update withdrawal';
      throw AdminAuthException('$detail');
    }
    return WithdrawalRequest.fromJson(
      Map<String, dynamic>.from(body['request'] as Map),
    );
  }
}

class AdminSession extends ChangeNotifier {
  AdminSession(this._service);

  final AdminService _service;
  bool get isSignedIn => (_service.token ?? '').isNotEmpty;

  Future<void> login(String username, String password) async {
    await _service.login(username: username, password: password);
    notifyListeners();
  }

  Future<List<WithdrawalRequest>> listWithdrawals({
    String? status,
    String? search,
  }) {
    return _service.listWithdrawals(status: status, search: search);
  }

  Future<WithdrawalRequest> approve(String requestId) =>
      _service.approve(requestId);

  Future<WithdrawalRequest> reject(String requestId, String reason) =>
      _service.reject(requestId, reason);
}
