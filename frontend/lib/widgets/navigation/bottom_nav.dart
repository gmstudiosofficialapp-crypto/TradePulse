import 'package:flutter/material.dart';

import 'shell_destinations.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentRoute,
    required this.onSelect,
  });

  final String currentRoute;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = shellDestinations.indexWhere(
      (item) => item.route == currentRoute,
    );

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) {
        onSelect(shellDestinations[index].route);
      },
      destinations: [
        for (final item in shellDestinations)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
      ],
    );
  }
}
