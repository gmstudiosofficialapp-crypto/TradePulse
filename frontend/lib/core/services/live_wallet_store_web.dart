import 'dart:convert';

import 'package:web/web.dart' as web;

const _key = 'tradepulse.liveTransfers.v1';

void resetTransfers() {
  web.window.localStorage.removeItem(_key);
}

Future<List<Map<String, dynamic>>> loadTransfers() async {
  final raw = web.window.localStorage.getItem(_key);
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return [
      for (final row in decoded)
        if (row is Map<String, dynamic>) Map<String, dynamic>.from(row)
        else if (row is Map) Map<String, dynamic>.from(row),
    ];
  } catch (_) {
    return [];
  }
}

Future<void> saveTransfers(List<Map<String, dynamic>> rows) async {
  web.window.localStorage.setItem(_key, jsonEncode(rows));
}
