import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/routes/app_routes.dart';
import 'package:tradepulse_frontend/core/services/admin_service.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/live_wallet_controller.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/market_controller.dart';
import 'package:tradepulse_frontend/core/services/offline_market_data_service.dart';
import 'package:tradepulse_frontend/core/services/pwa_install_controller.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/core/utils/app_utils.dart';
import 'package:tradepulse_frontend/core/utils/validators.dart';
import 'package:tradepulse_frontend/models/withdraw_models.dart';
import 'package:tradepulse_frontend/screens/admin/admin_login_screen.dart';
import 'package:tradepulse_frontend/screens/admin/admin_panel_screen.dart';
import 'package:tradepulse_frontend/screens/wallet/live_withdraw_screen.dart';
import 'package:tradepulse_frontend/screens/wallet/withdrawal_details_screen.dart';
import 'package:tradepulse_frontend/screens/wallet/withdrawal_history_screen.dart';

class _CreateTrading extends TradingService {
  _CreateTrading({this.failWith});

  final String? failWith;
  Map<String, dynamic>? last;

  @override
  Future<void> ensureAccount() async {}

  @override
  Future<Map<String, dynamic>> createWithdrawal({
    required double amount,
    required String method,
    required String paymentDetails,
  }) async {
    if (failWith != null) {
      throw WithdrawValidationException(failWith!);
    }
    last = {
      'request_id': 'wd-new',
      'amount_usd': amount,
      'amount_bdt': method == 'bkash' || method == 'nagad'
          ? Validators.usdToBdtAmount(amount)
          : null,
      'currency': method == 'bkash' || method == 'nagad' ? 'BDT' : 'USD',
      'payment_method': method,
      'payment_details': paymentDetails,
      'status': 'Pending',
      'created_at': '2026-08-24T16:15:00Z',
      'updated_at': '2026-08-24T16:16:00Z',
    };
    return {
      'ok': true,
      'request_created': true,
      'live_balance': 150.0,
      'request': last,
    };
  }
}

class _StoredWithdrawals extends TradingService {
  _StoredWithdrawals(this.rows);

  final List<WithdrawalRequest> rows;

  @override
  Future<void> ensureAccount() async {}

  @override
  Future<List<WithdrawalRequest>> listWithdrawals() async => rows;

  @override
  Future<WithdrawalRequest> getWithdrawal(String requestId) async {
    return rows.firstWhere((row) => row.requestId == requestId);
  }
}

class _FakeAdmin extends AdminSession {
  _FakeAdmin({this.failLogin = false, List<WithdrawalRequest>? rows})
      : rows = rows ?? [],
        super(AdminService());

  final bool failLogin;
  final List<WithdrawalRequest> rows;
  var signed = false;
  String? lastReason;

  @override
  bool get isSignedIn => signed;

  @override
  Future<void> login(String username, String password) async {
    if (failLogin || username.trim().isEmpty || password.isEmpty) {
      throw AdminAuthException('Invalid admin credentials');
    }
    signed = true;
    notifyListeners();
  }

  @override
  Future<List<WithdrawalRequest>> listWithdrawals({
    String? status,
    String? search,
  }) async {
    var next = rows;
    if (status != null && status.isNotEmpty) {
      next = next.where((row) => row.status.label == status).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final query = search.toLowerCase();
      next = next
          .where(
            (row) =>
                row.requestId.toLowerCase().contains(query) ||
                (row.userId ?? '').toLowerCase().contains(query),
          )
          .toList();
    }
    return next;
  }

  @override
  Future<WithdrawalRequest> approve(String requestId) async {
    return rows.firstWhere((row) => row.requestId == requestId);
  }

  @override
  Future<WithdrawalRequest> reject(String requestId, String reason) async {
    lastReason = reason;
    return rows.firstWhere((row) => row.requestId == requestId);
  }
}

WithdrawalRequest _request({
  required String id,
  required WithdrawStatus status,
  WithdrawMethod method = WithdrawMethod.usdtTrc20,
  String? reason,
  String userId = 'user-1',
}) {
  final created = DateTime.utc(2026, 8, 24, 16, 15);
  final processed = DateTime.utc(2026, 8, 24, 18, 40);
  return WithdrawalRequest(
    requestId: id,
    amountUsd: 1000,
    amountBdt: null,
    currency: 'USD',
    method: method,
    paymentDetails: 'THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq',
    status: status,
    createdAt: created,
    updatedAt: created.add(const Duration(minutes: 1)),
    rejectionReason: reason,
    processedAt: status == WithdrawStatus.pending ? null : processed,
    userId: userId,
  );
}

Widget _app({
  required Widget home,
  double liveBalance = 0,
  TradingService? trading,
  AdminSession? admin,
}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: home,
    routes: {
      AppRoutes.adminLogin: (_) => const AdminLoginScreen(),
      AppRoutes.adminPanel: (_) => const AdminPanelScreen(),
      AppRoutes.withdrawalHistory: (_) => const WithdrawalHistoryScreen(),
    },
    onGenerateRoute: (settings) {
      if (settings.name == AppRoutes.withdrawalDetails) {
        final args = settings.arguments;
        return MaterialPageRoute<void>(
          builder: (_) => WithdrawalDetailsScreen(
            requestId: args is WithdrawalRequest ? args.requestId : '$args',
            initial: args is WithdrawalRequest ? args : null,
          ),
        );
      }
      return null;
    },
    builder: (context, child) {
      return AuthScope(
        auth: AuthController(LocalAuthService()),
        child: SettingsScope(
          settings: SettingsController(),
          child: MarketScope(
            market: MarketController(OfflineMarketDataService()),
            child: TradingScope(
              trading: TradingController(trading ?? _CreateTrading())
                ..liveBalance = liveBalance
                ..balance = 10000,
              child: LiveWalletScope(
                wallet: LiveWalletController(),
                child: AdminScope(
                  admin: admin ?? _FakeAdmin(),
                  child: PwaInstallScope(
                    install: PwaInstallController(),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Submit Withdrawal'));
  await tester.tap(find.widgetWithText(FilledButton, 'Submit Withdrawal'));
  await tester.pump();
}

void main() {
  test('withdraw validators cover amount, p2p conversion, and addresses', () {
    expect(Validators.withdrawAmount('49.99'), Validators.withdrawMinMessage);
    expect(Validators.withdrawAmount('50'), isNull);
    expect(Validators.withdrawAmount('10000'), isNull);
    expect(Validators.withdrawAmount('10000.01'), Validators.withdrawMaxMessage);
    expect(Validators.usdToBdtAmount(100), 12400);
    expect(Validators.usdToBdtAmount(200), 24800);
    expect(
      Validators.withdrawAmount('40', WithdrawMethod.bkash),
      Validators.withdrawP2pMinMessage,
    );
    expect(
      Validators.withdrawAmount('404', WithdrawMethod.nagad),
      Validators.withdrawP2pMaxMessage,
    );
    expect(Validators.withdrawAmount('100', WithdrawMethod.bkash), isNull);
    expect(
      Validators.withdrawPaymentDetails(null, WithdrawMethod.btc),
      Validators.withdrawAddressRequired,
    );
    expect(Validators.withdrawPaymentDetails('abc', null), Validators.withdrawMethodRequired);
    expect(
      Validators.withdrawPaymentDetails('abc', WithdrawMethod.btc),
      Validators.withdrawBtcInvalid,
    );
    expect(
      Validators.withdrawPaymentDetails('test', WithdrawMethod.usdtTrc20),
      Validators.withdrawTrc20Invalid,
    );
    expect(
      Validators.withdrawPaymentDetails('0x12', WithdrawMethod.eth),
      Validators.withdrawEthInvalid,
    );
    expect(
      Validators.withdrawPaymentDetails('123', WithdrawMethod.bkash),
      Validators.withdrawBkashInvalid,
    );
    expect(
      Validators.withdrawPaymentDetails('12', WithdrawMethod.nagad),
      Validators.withdrawNagadInvalid,
    );
    expect(
      Validators.withdrawPaymentDetails(
        '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
        WithdrawMethod.btc,
      ),
      isNull,
    );
    expect(
      Validators.withdrawPaymentDetails(
        'THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq',
        WithdrawMethod.usdtTrc20,
      ),
      isNull,
    );
    expect(
      Validators.withdrawPaymentDetails(
        '0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6',
        WithdrawMethod.eth,
      ),
      isNull,
    );
    expect(
      Validators.withdrawPaymentDetails('01712345678', WithdrawMethod.bkash),
      isNull,
    );
    expect(
      Validators.withdrawPaymentDetails('01812345678', WithdrawMethod.nagad),
      isNull,
    );
    expect(
      Validators.withdrawSubmittedBody,
      contains('15 minutes to 7 days'),
    );
    expect(Validators.withdrawSubmittedBody.contains('2–12 hours'), isFalse);
    expect(Validators.withdrawSubmittedBody.toLowerCase().contains('guaranteed'), isFalse);
  });

  testWidgets('withdraw form validates amount before submit', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen(), liveBalance: 200));
    await tester.pump();
    expect(find.text('Submit Withdrawal'), findsOneWidget);
    expect(find.text('Crypto'), findsOneWidget);
    expect(find.text('P2P'), findsOneWidget);
    expect(find.text('Processing time'), findsNothing);
    expect(find.textContaining('2–12 hours'), findsNothing);
    expect(find.textContaining('15 minutes'), findsNothing);
    expect(find.text('Bangladesh'), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '20');
    await _submit(tester);
    expect(find.text(Validators.withdrawMinMessage), findsWidgets);
    expect(find.text(Validators.withdrawDepositRequired), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '10000.01');
    await _submit(tester);
    expect(find.text(Validators.withdrawMaxMessage), findsWidgets);
    expect(find.text(Validators.withdrawDepositRequired), findsNothing);
  });

  testWidgets('withdraw requires method and valid payment details', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen(), liveBalance: 200));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await _submit(tester);
    expect(find.text(Validators.withdrawMethodRequired), findsOneWidget);

    await tester.tap(find.text('Bitcoin (BTC)'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Payment address'), 'abc');
    await _submit(tester);
    expect(find.text(Validators.withdrawBtcInvalid), findsWidgets);
    expect(find.textContaining('not eligible for withdrawal'), findsNothing);

    await tester.ensureVisible(find.text('USDT (TRC20)'));
    await tester.tap(find.text('USDT (TRC20)'));
    await tester.pump();
    expect(find.text('Enter your USDT TRC20 wallet address'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Payment address'), 'hello');
    await _submit(tester);
    expect(find.text(Validators.withdrawTrc20Invalid), findsWidgets);

    await tester.ensureVisible(find.text('Ethereum (ERC20)'));
    await tester.tap(find.text('Ethereum (ERC20)'));
    await tester.pump();
    expect(find.text('Enter your Ethereum ERC20 wallet address'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Payment address'), '0x12');
    await _submit(tester);
    expect(find.text(Validators.withdrawEthInvalid), findsWidgets);
  });

  testWidgets('p2p amount shows bdt equivalent', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen(), liveBalance: 200));
    await tester.pump();
    await tester.ensureVisible(find.text('bKash'));
    await tester.tap(find.text('bKash'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await tester.pump();
    expect(find.text('${AppUtils.formatMoney(100)} = ${AppUtils.formatBdt(12400)}'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '123');
    await _submit(tester);
    expect(find.text(Validators.withdrawBkashInvalid), findsWidgets);
  });

  testWidgets('insufficient live balance blocks submit', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen()));
    await tester.pump();
    expect(find.text('Insufficient Balance'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    await tester.tap(find.text('Bitcoin (BTC)'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Payment address'),
      '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
    );
    await _submit(tester);
    expect(find.text(Validators.withdrawInsufficient), findsOneWidget);
    expect(find.textContaining('not eligible for withdrawal'), findsNothing);
  });

  testWidgets('valid withdraw submits a persistent pending request', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final trading = _CreateTrading();
    await tester.pumpWidget(
      _app(home: const LiveWithdrawScreen(), liveBalance: 250, trading: trading),
    );
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await tester.tap(find.text('Bitcoin (BTC)'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Payment address'),
      '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
    );
    await _submit(tester);
    await tester.pump();
    expect(find.text(Validators.withdrawSubmittedTitle), findsOneWidget);
    expect(find.text(Validators.withdrawSubmittedBody), findsOneWidget);
    expect(find.text(Validators.withdrawDepositRequired), findsNothing);
    expect(trading.last?['status'], 'Pending');
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Withdrawal details'), findsOneWidget);
    expect(find.text('Under Review'), findsWidgets);
  });

  test('withdrawal timeline maps pending successful and rejected states', () {
    final pending = _request(id: 'p1', status: WithdrawStatus.pending);
    expect(pending.timeline.map((step) => step.title).toList(), [
      'Created',
      'Under Review',
      'Processing',
      'Payment Processing',
      'Completed',
    ]);
    expect(pending.timeline[1].kind, WithdrawTimelineKind.active);
    expect(
      pending.timeline.skip(2).every((step) => step.kind == WithdrawTimelineKind.pending),
      isTrue,
    );

    final successful = _request(id: 's1', status: WithdrawStatus.successful);
    expect(
      successful.timeline.every((step) => step.kind == WithdrawTimelineKind.completed),
      isTrue,
    );
    expect(
      successful.timeline.any((step) => step.kind == WithdrawTimelineKind.pending),
      isFalse,
    );

    final rejected = _request(
      id: 'r1',
      status: WithdrawStatus.rejected,
      reason: 'Please make a deposit before requesting a withdrawal.',
    );
    expect(rejected.timeline.last.title, 'Rejected');
    expect(rejected.timeline.last.kind, WithdrawTimelineKind.rejected);
    expect(rejected.timeline.any((step) => step.title == 'Completed'), isFalse);
  });

  testWidgets('pending withdrawal details uses backend request data', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final request = _request(id: 'wd-pending-1', status: WithdrawStatus.pending);
    await tester.pumpWidget(
      _app(
        home: WithdrawalDetailsScreen(requestId: request.requestId, initial: request),
        trading: _StoredWithdrawals([request]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Withdrawal details'), findsOneWidget);
    expect(find.text('Under Review'), findsWidgets);
    expect(find.text(r'$1,000.00 USD'), findsWidgets);
    expect(find.text('USDT (TRC20)'), findsWidgets);
    expect(find.text('wd-pending-1'), findsOneWidget);
    expect(find.text('THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Your withdrawal request is under review.'), findsOneWidget);
    expect(find.text("We'll notify you once there is an update."), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('successful withdrawal details completes the timeline', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final successful = _request(id: 'wd-ok', status: WithdrawStatus.successful);
    await tester.pumpWidget(
      _app(
        home: WithdrawalDetailsScreen(requestId: successful.requestId, initial: successful),
        trading: _StoredWithdrawals([successful]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Successful'), findsWidgets);
    expect(find.text('Your withdrawal has been successfully processed.'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('rejected withdrawal details shows admin reason', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    const reason = 'Please make a deposit before requesting a withdrawal.';
    final rejected = _request(
      id: 'wd-no',
      status: WithdrawStatus.rejected,
      reason: reason,
    );
    await tester.pumpWidget(
      _app(
        home: WithdrawalDetailsScreen(requestId: rejected.requestId, initial: rejected),
        trading: _StoredWithdrawals([rejected]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Rejected'), findsWidgets);
    expect(find.text('Your withdrawal request was rejected.'), findsOneWidget);
    expect(find.text('Rejection Reason:'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    expect(find.text('Your withdrawal has been successfully processed.'), findsNothing);
    expect(find.text('In progress'), findsNothing);
  });

  testWidgets('withdrawal history lists backend requests', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final request = _request(id: 'wd-hist', status: WithdrawStatus.pending);
    await tester.pumpWidget(
      _app(
        home: const WithdrawalHistoryScreen(),
        trading: _StoredWithdrawals([request]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Withdrawal History'), findsOneWidget);
    expect(find.text('USDT (TRC20)'), findsOneWidget);
    expect(find.text(r'$1,000.00 USD'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
    expect(
      find.text(AppUtils.formatDetailStamp(DateTime.utc(2026, 8, 24, 16, 15))),
      findsOneWidget,
    );
    expect(find.text('wd-hist'), findsNothing);
    expect(find.text('THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq'), findsNothing);
    expect(find.text('TRON (TRC20)'), findsNothing);
    expect(find.text('In progress'), findsNothing);
  });

  testWidgets('five taps on withdraw title opens admin login', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen(), liveBalance: 200));
    await tester.pump();
    final title = find.byKey(const Key('withdraw-title'));
    expect(title, findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(title);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('admin login accepts a backend session', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final admin = _FakeAdmin(rows: [_request(id: 'wd-admin', status: WithdrawStatus.pending)]);
    await tester.pumpWidget(
      _app(home: const AdminLoginScreen(), admin: admin, liveBalance: 200),
    );
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'operator');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Withdrawals'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('wd-admin'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('admin login rejects invalid credentials', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _app(home: const AdminLoginScreen(), admin: _FakeAdmin(failLogin: true)),
    );
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'x');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'y');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Invalid admin credentials'), findsOneWidget);
    expect(find.text('Withdrawals'), findsNothing);
  });

  testWidgets('admin panel approve confirmation and reject dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final admin = _FakeAdmin(
      rows: [_request(id: 'wd-admin', status: WithdrawStatus.pending)],
    )..signed = true;
    await tester.pumpWidget(
      _app(home: const AdminPanelScreen(), admin: admin, liveBalance: 200),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('User or Request ID'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(find.text('Approve Withdrawal?'), findsOneWidget);
    expect(find.text('Are you sure you want to approve this withdrawal?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(find.text('Rejection Reason'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Reject Withdrawal'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rejection Reason'),
      'Please make a deposit before requesting a withdrawal.',
    );
    await tester.tap(find.text('Reject Withdrawal'));
    await tester.pump();
    expect(
      admin.lastReason,
      'Please make a deposit before requesting a withdrawal.',
    );
  });
}
