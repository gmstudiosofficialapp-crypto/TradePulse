class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String markets = '/markets';
  static const String trade = '/trade';
  static const String history = '/history';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';
  static const String liveDeposit = '/live-deposit';
  static const String liveDepositConfirm = '/live-deposit-confirm';
  static const String liveWithdraw = '/live-withdraw';
  static const String liveTransfers = '/live-transfers';

  static const public = {
    splash,
    login,
    signup,
    forgotPassword,
    resetPassword,
  };

  static const shell = {
    home,
    markets,
    trade,
    history,
    profile,
  };
}
