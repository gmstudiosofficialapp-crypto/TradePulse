import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'market_controller.dart';
import 'settings_controller.dart';
import 'trading_controller.dart';

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope not found');
    return scope!.notifier!;
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController settings,
    required super.child,
  }) : super(notifier: settings);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope not found');
    return scope!.notifier!;
  }
}

class MarketScope extends InheritedNotifier<MarketController> {
  const MarketScope({
    super.key,
    required MarketController market,
    required super.child,
  }) : super(notifier: market);

  static MarketController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MarketScope>();
    assert(scope != null, 'MarketScope not found');
    return scope!.notifier!;
  }

  static MarketController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MarketScope>()?.notifier;
  }
}

class TradingScope extends InheritedNotifier<TradingController> {
  const TradingScope({
    super.key,
    required TradingController trading,
    required super.child,
  }) : super(notifier: trading);

  static TradingController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TradingScope>();
    assert(scope != null, 'TradingScope not found');
    return scope!.notifier!;
  }

  static TradingController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TradingScope>()?.notifier;
  }
}

class AppScope {
  static AuthController auth(BuildContext context) => AuthScope.of(context);

  static SettingsController settings(BuildContext context) =>
      SettingsScope.of(context);

  static MarketController market(BuildContext context) =>
      MarketScope.of(context);

  static TradingController trading(BuildContext context) =>
      TradingScope.of(context);
}
