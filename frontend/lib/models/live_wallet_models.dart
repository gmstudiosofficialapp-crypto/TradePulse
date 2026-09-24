enum LivePaymentAsset {
  btc,
  usdtTrc20,
  eth,
}

extension LivePaymentAssetX on LivePaymentAsset {
  String get id => name;

  String get iconSymbol => switch (this) {
        LivePaymentAsset.btc => 'BTC',
        LivePaymentAsset.usdtTrc20 => 'USDT',
        LivePaymentAsset.eth => 'ETH',
      };

  String get title => switch (this) {
        LivePaymentAsset.btc => 'Bitcoin (BTC)',
        LivePaymentAsset.usdtTrc20 => 'USDT — TRON (TRC20)',
        LivePaymentAsset.eth => 'ETH — ERC20',
      };

  String get shortName => switch (this) {
        LivePaymentAsset.btc => 'Bitcoin',
        LivePaymentAsset.usdtTrc20 => 'USDT',
        LivePaymentAsset.eth => 'ETH',
      };

  String? get network => switch (this) {
        LivePaymentAsset.btc => null,
        LivePaymentAsset.usdtTrc20 => 'TRON (TRC20)',
        LivePaymentAsset.eth => 'ERC20',
      };

  String get depositNetworkLabel => switch (this) {
        LivePaymentAsset.btc => 'Bitcoin Network',
        LivePaymentAsset.usdtTrc20 => 'TRON (TRC20)',
        LivePaymentAsset.eth => 'Ethereum Network',
      };

  String get withdrawMethodId => switch (this) {
        LivePaymentAsset.btc => 'btc',
        LivePaymentAsset.usdtTrc20 => 'usdt_trc20',
        LivePaymentAsset.eth => 'eth_erc20',
      };

  String get withdrawAddressHint => switch (this) {
        LivePaymentAsset.btc => 'Enter your Bitcoin wallet address',
        LivePaymentAsset.usdtTrc20 => 'Enter your USDT TRC20 wallet address',
        LivePaymentAsset.eth => 'Enter your Ethereum ERC20 wallet address',
      };

  String get placeholderAddress => switch (this) {
        LivePaymentAsset.btc => '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
        LivePaymentAsset.usdtTrc20 => 'THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq',
        LivePaymentAsset.eth => '0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6',
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
