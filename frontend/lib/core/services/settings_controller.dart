import 'package:flutter/material.dart';

enum TradingUiMode { demo, live }

class SettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  bool notificationsEnabled = true;
  bool soundEnabled = false;
  String language = 'English';
  TradingUiMode tradingUiMode = TradingUiMode.demo;
  final Set<String> favoriteAssets = {};

  bool get isLiveMode => tradingUiMode == TradingUiMode.live;

  void setTradingUiMode(TradingUiMode mode) {
    if (tradingUiMode == mode) return;
    tradingUiMode = mode;
    notifyListeners();
  }

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
