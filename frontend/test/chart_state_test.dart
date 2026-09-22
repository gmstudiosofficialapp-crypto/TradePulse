import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/models/market_models.dart';
import 'package:tradepulse_frontend/widgets/charts/candlestick_chart.dart';

void main() {
  testWidgets('loading and offline are different and candles replace loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CandlestickChart(
            candles: [],
            feedState: EngineState.liveSimulation,
          ),
        ),
      ),
    );
    expect(find.text('Loading market data'), findsOneWidget);
    expect(find.text('Market offline'), findsNothing);
    expect(find.text('Waiting for candles…'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CandlestickChart(
            candles: [],
            feedState: EngineState.offline,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Market offline'), findsOneWidget);
    expect(find.text('Loading market data'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandlestickChart(
            candles: [
              MarketCandle(
                asset: 'BTC/USD-OTC',
                open: 100,
                high: 110,
                low: 95,
                close: 108,
                volume: 4,
                openTime: DateTime.utc(2026, 9, 22, 10),
                closeTime: DateTime.utc(2026, 9, 22, 10, 1),
                closed: true,
              ),
            ],
            feedState: EngineState.liveSimulation,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Loading market data'), findsNothing);
    expect(find.text('Market offline'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
