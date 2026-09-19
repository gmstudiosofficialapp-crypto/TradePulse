import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'shell_destinations.dart';

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.currentRoute,
    required this.onSelect,
  });

  final String currentRoute;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;

    return ColoredBox(
      color: colors.sidebar,
      child: SafeArea(
        child: SizedBox(
          width: 232,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  AppConstants.accountType,
                  style: TextStyle(color: colors.mutedText),
                ),
              ),
              const SizedBox(height: 12),
              for (final item in shellDestinations)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: ListTile(
                    selected: item.route == currentRoute,
                    selectedTileColor: colors.accent.withValues(alpha: 0.16),
                    selectedColor: colors.accent,
                    iconColor: colors.mutedText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: item.route == currentRoute
                          ? BorderSide(color: colors.accent.withValues(alpha: 0.45))
                          : BorderSide.none,
                    ),
                    leading: Icon(
                      item.route == currentRoute
                          ? item.selectedIcon
                          : item.icon,
                    ),
                    title: Text(item.label),
                    onTap: () => onSelect(item.route),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
