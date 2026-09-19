import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_private_signal/main.dart';

void main() {
  testWidgets('private app is labeled ground truth', (tester) async {
    await tester.pumpWidget(const PrivateSignalApp(httpBase: 'http://127.0.0.1:9'));
    await tester.pump();
    expect(find.textContaining('PRIVATE TEST / GROUND TRUTH'), findsWidgets);
    expect(find.textContaining('NOT a real prediction'), findsOneWidget);
  });
}
