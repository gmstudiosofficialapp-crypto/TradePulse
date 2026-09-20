List<Map<String, dynamic>> _memory = [];

void resetTransfers() {
  _memory = [];
}

Future<List<Map<String, dynamic>>> loadTransfers() async {
  return [for (final row in _memory) Map<String, dynamic>.from(row)];
}

Future<void> saveTransfers(List<Map<String, dynamic>> rows) async {
  _memory = [for (final row in rows) Map<String, dynamic>.from(row)];
}
