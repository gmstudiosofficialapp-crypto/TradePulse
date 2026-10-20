import 'withdraw_models.dart';

enum DepositMethod { btc, usdtTrc20, eth }

extension DepositMethodX on DepositMethod {
  String get id => switch (this) {
        DepositMethod.btc => 'btc',
        DepositMethod.usdtTrc20 => 'usdt_trc20',
        DepositMethod.eth => 'eth_erc20',
      };

  String get title => switch (this) {
        DepositMethod.btc => 'Bitcoin (BTC)',
        DepositMethod.usdtTrc20 => 'USDT (TRC20)',
        DepositMethod.eth => 'Ethereum (ERC20)',
      };

  String get iconSymbol => switch (this) {
        DepositMethod.btc => 'BTC',
        DepositMethod.usdtTrc20 => 'USDT',
        DepositMethod.eth => 'ETH',
      };

  static DepositMethod fromId(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    return switch (key) {
      'usdt_trc20' || 'usdt' => DepositMethod.usdtTrc20,
      'eth_erc20' || 'eth' || 'ethereum' => DepositMethod.eth,
      _ => DepositMethod.btc,
    };
  }
}

class DepositRequest {
  const DepositRequest({
    required this.requestId,
    required this.amountUsd,
    required this.method,
    required this.network,
    required this.txid,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.credited = false,
    this.rejectionReason,
    this.processedAt,
    this.userId,
    this.userEmail,
    this.userName,
  });

  final String requestId;
  final double amountUsd;
  final DepositMethod method;
  final String network;
  final String txid;
  final WithdrawStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool credited;
  final String? rejectionReason;
  final DateTime? processedAt;
  final String? userId;
  final String? userEmail;
  final String? userName;

  String get accountLabel {
    final name = (userName ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (userEmail ?? '').trim();
    if (email.isNotEmpty) return email;
    return userId ?? '';
  }

  DateTime? get createdStamp {
    if (createdAt.millisecondsSinceEpoch <= 0) return null;
    return createdAt;
  }

  factory DepositRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(Object? raw) {
      if (raw == null || '$raw'.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
      return DateTime.parse('$raw').toUtc();
    }

    return DepositRequest(
      requestId: '${json['request_id']}',
      amountUsd: (json['amount_usd'] as num).toDouble(),
      method: DepositMethodX.fromId('${json['payment_method']}'),
      network: '${json['network'] ?? ''}',
      txid: '${json['txid'] ?? ''}',
      status: WithdrawStatusX.fromApi('${json['status']}'),
      createdAt: parseTime(json['created_at']),
      updatedAt: parseTime(json['updated_at']),
      credited: json['credited'] == true,
      rejectionReason: json['rejection_reason'] == null
          ? null
          : '${json['rejection_reason']}',
      processedAt:
          json['processed_at'] == null ? null : parseTime(json['processed_at']),
      userId: json['user_id'] == null ? null : '${json['user_id']}',
      userEmail: json['user_email'] == null ? null : '${json['user_email']}',
      userName: json['user_name'] == null ? null : '${json['user_name']}',
    );
  }
}
