import 'package:flutter/material.dart';

import '../services/app_scope.dart';

class AppStrings {
  const AppStrings(this.bangla);

  final bool bangla;

  factory AppStrings.of(BuildContext context) {
    final language = AppScope.settings(context).language;
    return AppStrings(language == 'bn' || language == 'বাংলা');
  }

  String _t(String en, String bn) => bangla ? bn : en;

  String get navHome => _t('Home', 'হোম');
  String get navMarkets => _t('Markets', 'মার্কেট');
  String get navTrade => _t('Trade', 'ট্রেড');
  String get navHistory => _t('History', 'হিস্ট্রি');
  String get navProfile => _t('Profile', 'প্রোফাইল');

  String get demoBalance => _t('Demo Balance', 'ডেমো ব্যালেন্স');
  String get liveBalance => _t('Live Balance', 'লাইভ ব্যালেন্স');
  String get manageFunds => _t('Manage Funds', 'ফান্ড ম্যানেজ');
  String get manageFundsSubtitle =>
      _t('Deposit or withdraw from your Live account', 'লাইভ অ্যাকাউন্টে ডিপোজিট বা উইথড্র');
  String get deposit => _t('Deposit', 'ডিপোজিট');
  String get withdraw => _t('Withdraw', 'উইথড্র');
  String get leaderboard => _t('LEADERBOARD', 'লিডারবোর্ড');
  String get recentActivity => _t('Recent activity', 'সাম্প্রতিক ট্রেড');
  String get noTradesYet => _t('No trades yet', 'এখনো কোনো ট্রেড নেই');
  String get marketOverview => _t('Market overview', 'মার্কেট ওভারভিউ');
  String get otcPlatform => _t('OTC Trading Platform', 'OTC ট্রেডিং প্ল্যাটফর্ম');
  String get tagline => _t('Fast • Simple • Trading', 'দ্রুত • সহজ • ট্রেডিং');
  String get loadingMarket => _t('Loading market…', 'মার্কেট লোড হচ্ছে…');
  String get wallet => _t('Wallet', 'ওয়ালেট');
  String get depositHistory => _t('Deposit history', 'ডিপোজিট হিস্ট্রি');
  String get withdrawalHistory => _t('Withdrawal history', 'উইথড্র হিস্ট্রি');
  String get theme => _t('Theme', 'থিম');
  String get language => _t('Language', 'ভাষা');
  String get english => _t('English', 'English');
  String get bengali => _t('বাংলা', 'বাংলা');
  String get appearance => _t('Appearance', 'অ্যাপিয়ারেন্স');
  String get yourToday => _t('Your trading today', 'আজকের আপনার ট্রেড');
  String get skip => _t('Skip', 'স্কিপ');
  String get next => _t('Next', 'পরবর্তী');
  String get getStarted => _t('Get started', 'শুরু করুন');
}
