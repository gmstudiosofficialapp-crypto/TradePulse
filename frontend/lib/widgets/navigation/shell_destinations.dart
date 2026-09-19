import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';

class ShellDestination {
  const ShellDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const shellDestinations = [
  ShellDestination(
    route: AppRoutes.home,
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  ShellDestination(
    route: AppRoutes.markets,
    label: 'Markets',
    icon: Icons.candlestick_chart_outlined,
    selectedIcon: Icons.candlestick_chart,
  ),
  ShellDestination(
    route: AppRoutes.trade,
    label: 'Trade',
    icon: Icons.swap_vert_circle_outlined,
    selectedIcon: Icons.swap_vert_circle,
  ),
  ShellDestination(
    route: AppRoutes.history,
    label: 'History',
    icon: Icons.history,
    selectedIcon: Icons.history,
  ),
  ShellDestination(
    route: AppRoutes.profile,
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];
