import 'package:flutter/material.dart';

class SettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  bool notificationsEnabled = true;
  bool soundEnabled = false;
  String language = 'English';
  final Set<String> favoriteAssets = {};

  bool isFavorite(String symbol) => favoriteAssets.contains(symbol);

  void toggleFavorite(String symbol) {
    if (!favoriteAssets.add(symbol)) {
      favoriteAssets.remove(symbol);
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setNotifications(bool value) {
    notificationsEnabled = value;
    notifyListeners();
  }

  void setSound(bool value) {
    soundEnabled = value;
    notifyListeners();
  }
}
