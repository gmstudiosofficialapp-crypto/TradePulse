import 'live_wallet_store_stub.dart'
    if (dart.library.html) 'live_wallet_store_web.dart' as impl;

class LiveWalletStore {
  static Future<List<Map<String, dynamic>>> load() => impl.loadTransfers();

  static Future<void> save(List<Map<String, dynamic>> rows) =>
      impl.saveTransfers(rows);

  static void reset() => impl.resetTransfers();
}
