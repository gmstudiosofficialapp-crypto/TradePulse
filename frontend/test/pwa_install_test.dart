import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/pwa_install_bridge.dart';
import 'package:tradepulse_frontend/core/services/pwa_install_bridge_stub.dart';
import 'package:tradepulse_frontend/core/services/pwa_install_controller.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/main.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/widgets/pwa/pwa_install_banner.dart';

void main() {
  test('web manifest uses TradePulse PWA name', () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(manifest['name'], 'TradePulse');
    expect(manifest['short_name'], 'TradePulse');
    expect(manifest['display'], 'standalone');
    expect(manifest['start_url'], './');
    expect(manifest['scope'], './');
    expect(manifest['theme_color'], '#0B1730');
    expect(manifest['background_color'], '#0B1730');
    final icons = manifest['icons'] as List<dynamic>;
    expect(icons, isNotEmpty);
    expect(
      jsonEncode(manifest).toLowerCase().contains('tradepulse_frontend'),
      isFalse,
    );
  });

  test('index.html uses TradePulse app title', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html.contains('<title>TradePulse</title>'), isTrue);
    expect(
      html.contains('apple-mobile-web-app-title" content="TradePulse"'),
      isTrue,
    );
    expect(html.contains('apple-touch-icon'), isTrue);
    expect(html.contains('--tp-app-height'), isTrue);
    expect(html.contains('__tpSyncViewport'), isTrue);
    expect(html.contains('__tpTakeInstallPrompt'), isTrue);
    expect(html.contains('beforeinstallprompt'), isTrue);
    expect(html.contains('tradepulse_frontend'), isFalse);
  });

  test('native install surface hides after session dismiss or standalone', () {
    final bridge = StubPwaInstallBridge()..nativePrompt = true;
    final controller = PwaInstallController(bridge: bridge);
    expect(controller.surface, PwaInstallSurface.native);
    controller.dismiss();
    expect(controller.shouldShow, isFalse);

    final installed = StubPwaInstallBridge()
      ..nativePrompt = true
      ..standalone = true;
    expect(
      PwaInstallController(bridge: installed).surface,
      PwaInstallSurface.hidden,
    );
  });

  test('iOS surface never calls a fake native prompt', () async {
    final bridge = StubPwaInstallBridge()..iosBrowser = true;
    final controller = PwaInstallController(bridge: bridge);
    expect(controller.surface, PwaInstallSurface.ios);
    expect(await controller.installNow(), PwaPromptOutcome.unavailable);
    expect(bridge.promptCalls, 0);
    controller.openIosGuide();
    expect(controller.iosGuideOpen, isTrue);
  });

  test('Android Chrome shows install banner without a native prompt event',
      () async {
    final bridge = StubPwaInstallBridge()..androidBrowser = true;
    final controller = PwaInstallController(bridge: bridge);
    expect(controller.surface, PwaInstallSurface.android);
    expect(controller.shouldShow, isTrue);
    expect(await controller.installNow(), PwaPromptOutcome.unavailable);
    expect(bridge.promptCalls, 0);
  });

  testWidgets('Android banner uses native Install Now', (tester) async {
    final bridge = StubPwaInstallBridge()..nativePrompt = true;
    final controller = PwaInstallController(bridge: bridge);
    await tester.pumpWidget(_bannerApp(controller));
    expect(find.text('Install TradePulse'), findsOneWidget);
    expect(
      find.text('Install the app for faster access to your account.'),
      findsOneWidget,
    );
    expect(find.text('Install Now'), findsOneWidget);
    await tester.tap(find.text('Install Now'));
    await tester.pump();
    expect(bridge.promptCalls, 1);
  });

  testWidgets('iOS banner shows Add to Home Screen steps', (tester) async {
    final bridge = StubPwaInstallBridge()..iosBrowser = true;
    final controller = PwaInstallController(bridge: bridge);
    await tester.pumpWidget(_bannerApp(controller));
    expect(
      find.text('Add TradePulse to your Home Screen for faster access.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add to Home Screen'));
    await tester.pump();
    expect(find.textContaining('Share button'), findsOneWidget);
    expect(find.textContaining('Add to Home Screen'), findsWidgets);
  });

  testWidgets('Android banner without native prompt still offers Home Screen',
      (tester) async {
    final bridge = StubPwaInstallBridge()..androidBrowser = true;
    final controller = PwaInstallController(bridge: bridge);
    await tester.pumpWidget(_bannerApp(controller));
    expect(find.text('Install TradePulse'), findsOneWidget);
    expect(
      find.text('Add TradePulse to your Home Screen from the Chrome menu.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add to Home Screen'));
    await tester.pump();
    expect(find.textContaining('Chrome menu'), findsWidgets);
    expect(bridge.promptCalls, 0);
  });

  testWidgets('existing splash still shows TradePulse, not package name',
      (tester) async {
    await tester.pumpWidget(const TradePulseApp());
    expect(find.text('TradePulse'), findsWidgets);
    expect(find.text('tradepulse_frontend'), findsNothing);
    expect(find.text('Install TradePulse'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
  });
}

Widget _bannerApp(PwaInstallController controller) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: PwaInstallScope(
        install: controller,
        child: const Scaffold(
          body: PwaInstallBanner(),
        ),
      ),
    ),
  );
}
