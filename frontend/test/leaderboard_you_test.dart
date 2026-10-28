import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/models/trade_models.dart';
import 'package:tradepulse_frontend/screens/leaderboard/leaderboard_screen.dart';

class _BoardTrading extends TradingService {
  @override
  Future<List<Map<String, dynamic>>> getLeaderboard({String? day}) async {
    return [
      {'rank': 1, 'name': 'Isaac Hayes', 'todays_win': 970741},
    ];
  }
}

Future<void> _pump(WidgetTester tester, TradingController trading) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: SettingsScope(
        settings: SettingsController(),
        child: TradingScope(
          trading: trading,
          child: const LeaderboardScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('user row sits under the generated board with profit', (tester) async {
    final trading = TradingController(_BoardTrading());
    trading.statistics = const DemoStatistics(totalProfitLoss: 48.2);
    await _pump(tester, trading);
    expect(find.text('Isaac Hayes'), findsOneWidget);
    expect(find.text('100+'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text(r'+$48.20'), findsOneWidget);
    expect(find.text('Your trading today'), findsNothing);
  });

  testWidgets('user row shows a loss under the generated board', (tester) async {
    final trading = TradingController(_BoardTrading());
    trading.statistics = const DemoStatistics(totalProfitLoss: -12.5);
    await _pump(tester, trading);
    expect(find.text('100+'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text(r'-$12.50'), findsOneWidget);
  });
}
