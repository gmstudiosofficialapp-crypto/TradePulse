import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/brand/trade_pulse_logo.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  var _index = 0;

  void _finish() {
    AppScope.settings(context).markOnboardingSeen();
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.tpColors;
    final pages = [
      (
        title: strings.bangla ? 'ডেমোতে অনুশীলন' : 'Practice on Demo',
        body: strings.bangla
            ? 'ডেমো ব্যালেন্স দিয়ে BUY ও SELL অনুশীলন করুন।'
            : 'Practice BUY and SELL trades with Demo Balance.',
        icon: Icons.school_outlined,
      ),
      (
        title: strings.bangla ? 'ট্রেড কীভাবে' : 'How to trade',
        body: strings.bangla
            ? 'সময় ও অ্যামাউন্ট বেছে BUY বা SELL চাপুন। এক্সপায়ারিতে ফলাফল সেটেল হয়।'
            : 'Pick time and amount, then tap BUY or SELL. The trade settles at expiry.',
        icon: Icons.candlestick_chart,
      ),
      (
        title: strings.bangla ? 'লাইভ ডিপোজিট' : 'Live deposits',
        body: strings.bangla
            ? 'লাইভ ডিপোজিট সাবমিট করুন। প্রসেস শেষে ব্যালেন্স যোগ হবে।'
            : 'Submit a Live deposit. Balance is added after the request is processed.',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    return AtmosphereBackground(
      style: AtmosphereStyle.auth,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ResponsiveBody(
          maxWidth: 480,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const TradePulseLogo(compact: true, showTagline: false),
                  const SizedBox(height: 24),
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      itemCount: pages.length,
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(page.icon, size: 56, color: colors.accent),
                            const SizedBox(height: 20),
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              page.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.mutedText, height: 1.45),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        Container(
                          width: i == _index ? 18 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _index ? colors.accent : colors.cardBorder,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(onPressed: _finish, child: Text(strings.skip)),
                      const Spacer(),
                      SizedBox(
                        width: 160,
                        child: PrimaryButton(
                          label: _index == pages.length - 1 ? strings.getStarted : strings.next,
                          onPressed: () {
                            if (_index == pages.length - 1) {
                              _finish();
                              return;
                            }
                            _page.nextPage(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
