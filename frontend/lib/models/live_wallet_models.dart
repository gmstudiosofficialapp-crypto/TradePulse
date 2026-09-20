enum LivePaymentAsset {
  btc,
  usdtTrc20,
  eth,
  usdcErc20,
}

extension LivePaymentAssetX on LivePaymentAsset {
  String get id => name;

  String get iconSymbol => switch (this) {
        LivePaymentAsset.btc => 'BTC',
        LivePaymentAsset.usdtTrc20 => 'USDT',
        LivePaymentAsset.eth => 'ETH',
        LivePaymentAsset.usdcErc20 => 'USDC',
      };

  String get title => switch (this) {
        LivePaymentAsset.btc => 'Bitcoin (BTC)',
        LivePaymentAsset.usdtTrc20 => 'USDT — TRON (TRC20)',
        LivePaymentAsset.eth => 'Ethereum (ETH)',
        LivePaymentAsset.usdcErc20 => 'USDC — ERC20',
      };

  String get shortName => switch (this) {
        LivePaymentAsset.btc => 'Bitcoin',
        LivePaymentAsset.usdtTrc20 => 'USDT',
        LivePaymentAsset.eth => 'Ethereum',
        LivePaymentAsset.usdcErc20 => 'USDC',
      };

  String? get network => switch (this) {
        LivePaymentAsset.btc => null,
        LivePaymentAsset.usdtTrc20 => 'TRON (TRC20)',
        LivePaymentAsset.eth => null,
        LivePaymentAsset.usdcErc20 => 'ERC20',
      };

  String get placeholderAddress => switch (this) {
        LivePaymentAsset.btc => 'YOUR_BTC_DEPOSIT_ADDRESS',
        LivePaymentAsset.usdtTrc20 => 'YOUR_USDT_DEPOSIT_ADDRESS',
        LivePaymentAsset.eth => 'YOUR_ETH_DEPOSIT_ADDRESS',
        LivePaymentAsset.usdcErc20 => 'YOUR_USDC_DEPOSIT_ADDRESS',
      };

  static LivePaymentAsset fromId(String id) {
    return LivePaymentAsset.values.firstWhere(
      (item) => item.id == id,
      orElse: () => LivePaymentAsset.btc,
    );
  }
}

class LiveDepositDraft {
  const LiveDepositDraft({required this.asset, required this.amount});

  final LivePaymentAsset asset;
  final double amount;
}

enum LiveTransferType { deposit, withdraw }

enum LiveTransferStatus { pending, failed }

class LiveTransfer {
  const LiveTransfer({
    required this.id,
    required this.type,
    required this.asset,
    required this.amount,
    required this.txid,
    required this.submittedAt,
  });

  final String id;
  final LiveTransferType type;
  final LivePaymentAsset asset;
  final double amount;
  final String txid;
  final DateTime submittedAt;

  static const pendingWindow = Duration(minutes: 15);

  LiveTransferStatus statusAt(DateTime now) {
    if (!now.difference(submittedAt).isNegative &&
        now.difference(submittedAt) >= pendingWindow) {
      return LiveTransferStatus.failed;
    }
    return LiveTransferStatus.pending;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'asset': asset.id,
        'network': asset.network,
        'amount': amount,
        'txid': txid,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
      };

  factory LiveTransfer.fromJson(Map<String, dynamic> json) {
    return LiveTransfer(
      id: json['id'] as String,
      type: LiveTransferType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => LiveTransferType.deposit,
      ),
      asset: LivePaymentAssetX.fromId('${json['asset']}'),
      amount: (json['amount'] as num).toDouble(),
      txid: '${json['txid']}',
      submittedAt: DateTime.parse('${json['submittedAt']}').toUtc(),
    );
  }
}
