import '../constants/app_constants.dart';

class AppUtils {
  const AppUtils._();

  static const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String formatMemberSince(DateTime date) {
    return '${months[date.month - 1]} ${date.year}';
  }

  static String formatPrice(double price) {
    if (price >= 100) return price.toStringAsFixed(2);
    if (price >= 1) return price.toStringAsFixed(4);
    return price.toStringAsFixed(5);
  }

  static String formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  static String formatSignedMoney(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${formatMoney(value)}';
  }

  static String formatClock(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final rest = safe % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  static String formatExpiryLabel(int seconds) {
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m';
  }

  static String formatTxnWhen(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, $hour:$minute $period';
  }

  static String maskTxid(String txid) {
    final value = txid.trim();
    if (value.length <= 10) return value;
    return '••••••${value.substring(value.length - 10)}';
  }

  static String formatStamp(DateTime value) {
    final local = value.toLocal();
    return '${formatMemberSince(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String formatChange(double changePct) {
    final sign = changePct >= 0 ? '+' : '';
    return '$sign${changePct.toStringAsFixed(2)}%';
  }

  static double winPayout(double stake, {double rate = AppConstants.payoutRate}) {
    return double.parse((stake * rate).toStringAsFixed(2));
  }
}
