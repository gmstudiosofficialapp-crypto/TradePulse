import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/live_wallet_models.dart';
import 'live_wallet_store.dart';

class LiveWalletController extends ChangeNotifier {
  LiveWalletController({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  DateTime Function() _clock;
  List<LiveTransfer> transfers = [];

  static const liveBalance = 0.0;

  DateTime get now => _clock();

  void setClock(DateTime Function() clock) {
    _clock = clock;
    notifyListeners();
  }

  Future<void> restore() async {
    final rows = await LiveWalletStore.load();
    transfers = rows.map(LiveTransfer.fromJson).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    notifyListeners();
  }

  LiveTransferStatus statusOf(LiveTransfer transfer) => transfer.statusAt(now);

  Future<LiveTransfer> submitDeposit({
    required LivePaymentAsset asset,
    required double amount,
    required String txid,
  }) async {
    final record = LiveTransfer(
      id: 'live-${now.microsecondsSinceEpoch}',
      type: LiveTransferType.deposit,
      asset: asset,
      amount: amount,
      txid: txid.trim(),
      submittedAt: now.toUtc(),
    );
    transfers = [record, ...transfers];
    await LiveWalletStore.save([for (final item in transfers) item.toJson()]);
    notifyListeners();
    return record;
  }
}
