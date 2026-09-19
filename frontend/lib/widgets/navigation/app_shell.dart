import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/utils/breakpoints.dart';
import '../feedback/market_status_banner.dart';
import '../layout/atmosphere_background.dart';
import 'bottom_nav.dart';
import 'side_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  final String currentRoute;
  final Widget child;

  void _go(BuildContext context, String route) {
    if (route == currentRoute) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);

    return AtmosphereBackground(
      style: currentRoute == AppRoutes.trade
          ? AtmosphereStyle.trade
          : AtmosphereStyle.app,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            if (!compact)
              SideNav(
                currentRoute: currentRoute,
                onSelect: (route) => _go(context, route),
              ),
            Expanded(
              child: Column(
                children: [
                  const MarketStatusBanner(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: KeyedSubtree(
                        key: ValueKey(currentRoute),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: compact
            ? AppBottomNav(
                currentRoute: currentRoute,
                onSelect: (route) => _go(context, route),
              )
            : null,
      ),
    );
  }
}

bool isShellRoute(String? name) => AppRoutes.shell.contains(name);
