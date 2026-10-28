enum WithdrawMethod { btc, usdtTrc20, eth, bkash, nagad }

enum WithdrawStatus { pending, successful, rejected }

enum WithdrawCategory { crypto, p2p }

extension WithdrawMethodX on WithdrawMethod {
  String get id => switch (this) {
        WithdrawMethod.btc => 'btc',
        WithdrawMethod.usdtTrc20 => 'usdt_trc20',
        WithdrawMethod.eth => 'eth_erc20',
        WithdrawMethod.bkash => 'bkash',
        WithdrawMethod.nagad => 'nagad',
      };

  WithdrawCategory get category => switch (this) {
        WithdrawMethod.btc ||
        WithdrawMethod.usdtTrc20 ||
        WithdrawMethod.eth =>
          WithdrawCategory.crypto,
        WithdrawMethod.bkash || WithdrawMethod.nagad => WithdrawCategory.p2p,
      };

  String get title => switch (this) {
        WithdrawMethod.btc => 'Bitcoin (BTC)',
        WithdrawMethod.usdtTrc20 => 'USDT (TRC20)',
        WithdrawMethod.eth => 'Ethereum (ERC20)',
        WithdrawMethod.bkash => 'bKash',
        WithdrawMethod.nagad => 'Nagad',
      };

  String get iconSymbol => switch (this) {
        WithdrawMethod.btc => 'BTC',
        WithdrawMethod.usdtTrc20 => 'USDT',
        WithdrawMethod.eth => 'ETH',
        WithdrawMethod.bkash => 'BKASH',
        WithdrawMethod.nagad => 'NAGAD',
      };

  String? get network => switch (this) {
        WithdrawMethod.btc => 'Bitcoin',
        WithdrawMethod.usdtTrc20 => 'TRON (TRC20)',
        WithdrawMethod.eth => 'ERC20',
        WithdrawMethod.bkash || WithdrawMethod.nagad => null,
      };

  String get detailsLabel => category == WithdrawCategory.p2p
      ? 'Mobile number'
      : 'Payment address';

  String get detailsHint => switch (this) {
        WithdrawMethod.btc => 'Enter your Bitcoin wallet address',
        WithdrawMethod.usdtTrc20 => 'Enter your USDT TRC20 wallet address',
        WithdrawMethod.eth => 'Enter your Ethereum ERC20 wallet address',
        WithdrawMethod.bkash => 'Enter your bKash number',
        WithdrawMethod.nagad => 'Enter your Nagad number',
      };

  static WithdrawMethod? fromId(String? id) {
    final key = (id ?? '').trim().toLowerCase();
    for (final item in WithdrawMethod.values) {
      if (item.id == key) return item;
    }
    return null;
  }
}

extension WithdrawStatusX on WithdrawStatus {
  String get label => switch (this) {
        WithdrawStatus.pending => 'Pending',
        WithdrawStatus.successful => 'Successful',
        WithdrawStatus.rejected => 'Rejected',
      };

  String get badgeLabel => switch (this) {
        WithdrawStatus.pending => 'Under Review',
        WithdrawStatus.successful => 'Successful',
        WithdrawStatus.rejected => 'Rejected',
      };

  String get infoTitle => switch (this) {
        WithdrawStatus.pending => 'Your withdrawal request is being processed.',
        WithdrawStatus.successful =>
          'Your withdrawal has been successfully processed.',
        WithdrawStatus.rejected => 'Your withdrawal request was rejected.',
      };

  String get infoBody => switch (this) {
        WithdrawStatus.pending =>
          "We'll notify you once there is an update.",
        WithdrawStatus.successful =>
          'Funds have been sent using the payment details on this request.',
        WithdrawStatus.rejected => '',
      };

  static WithdrawStatus fromApi(String? raw) {
    return switch ((raw ?? '').toLowerCase()) {
      'successful' => WithdrawStatus.successful,
      'rejected' => WithdrawStatus.rejected,
      _ => WithdrawStatus.pending,
    };
  }
}

enum WithdrawTimelineKind { completed, active, pending, rejected }

class WithdrawTimelineStep {
  const WithdrawTimelineStep({
    required this.title,
    required this.kind,
    this.at,
  });

  final String title;
  final WithdrawTimelineKind kind;
  final DateTime? at;

  String get rightLabel => switch (kind) {
        WithdrawTimelineKind.completed => '',
        WithdrawTimelineKind.active => 'In progress',
        WithdrawTimelineKind.pending => 'Pending',
        WithdrawTimelineKind.rejected => 'Rejected',
      };
}

class WithdrawalRequest {
  const WithdrawalRequest({
    required this.requestId,
    required this.amountUsd,
    required this.amountBdt,
    required this.currency,
    required this.method,
    required this.paymentDetails,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
    this.processedAt,
    this.userId,
    this.userEmail,
    this.userName,
  });

  final String requestId;
  final double amountUsd;
  final double? amountBdt;
  final String currency;
  final WithdrawMethod method;
  final String paymentDetails;
  final WithdrawStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
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

  DateTime? get createdStamp => _stamp(createdAt);
  DateTime? get updatedStamp => _stamp(updatedAt);
  DateTime? get processedStamp => _stamp(processedAt);

  static DateTime? _stamp(DateTime? value) {
    if (value == null) return null;
    if (value.millisecondsSinceEpoch <= 0) return null;
    return value;
  }

  List<WithdrawTimelineStep> get timeline {
    final created = createdStamp;
    final reviewed = updatedStamp ?? created;
    switch (status) {
      case WithdrawStatus.pending:
        return [
          WithdrawTimelineStep(
            title: 'Created',
            kind: WithdrawTimelineKind.completed,
            at: created,
          ),
          WithdrawTimelineStep(
            title: 'Under Review',
            kind: WithdrawTimelineKind.active,
            at: reviewed,
          ),
          const WithdrawTimelineStep(
            title: 'Processing',
            kind: WithdrawTimelineKind.pending,
          ),
          const WithdrawTimelineStep(
            title: 'Payment Processing',
            kind: WithdrawTimelineKind.pending,
          ),
          const WithdrawTimelineStep(
            title: 'Completed',
            kind: WithdrawTimelineKind.pending,
          ),
        ];
      case WithdrawStatus.successful:
        return [
          WithdrawTimelineStep(
            title: 'Created',
            kind: WithdrawTimelineKind.completed,
            at: created,
          ),
          WithdrawTimelineStep(
            title: 'Under Review',
            kind: WithdrawTimelineKind.completed,
            at: reviewed,
          ),
          WithdrawTimelineStep(
            title: 'Processing',
            kind: WithdrawTimelineKind.completed,
            at: processedStamp,
          ),
          WithdrawTimelineStep(
            title: 'Payment Processing',
            kind: WithdrawTimelineKind.completed,
            at: processedStamp,
          ),
          WithdrawTimelineStep(
            title: 'Completed',
            kind: WithdrawTimelineKind.completed,
            at: processedStamp,
          ),
        ];
      case WithdrawStatus.rejected:
        return [
          WithdrawTimelineStep(
            title: 'Created',
            kind: WithdrawTimelineKind.completed,
            at: created,
          ),
          WithdrawTimelineStep(
            title: 'Under Review',
            kind: WithdrawTimelineKind.completed,
            at: reviewed,
          ),
          WithdrawTimelineStep(
            title: 'Rejected',
            kind: WithdrawTimelineKind.rejected,
            at: processedStamp ?? reviewed,
          ),
        ];
    }
  }

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(Object? raw) {
      if (raw == null || '$raw'.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
      return DateTime.parse('$raw').toUtc();
    }

    return WithdrawalRequest(
      requestId: '${json['request_id']}',
      amountUsd: (json['amount_usd'] as num).toDouble(),
      amountBdt: json['amount_bdt'] == null
          ? null
          : (json['amount_bdt'] as num).toDouble(),
      currency: '${json['currency'] ?? 'USD'}',
      method: WithdrawMethodX.fromId('${json['payment_method']}') ??
          WithdrawMethod.btc,
      paymentDetails: '${json['payment_details'] ?? ''}',
      status: WithdrawStatusX.fromApi('${json['status']}'),
      createdAt: parseTime(json['created_at']),
      updatedAt: parseTime(json['updated_at']),
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
