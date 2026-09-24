import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/utils/app_utils.dart';

void main() {
  test('stake input formats as currency without sending the display string', () {
    expect(AppUtils.formatStakeInput(10), r'$10');
    expect(AppUtils.formatStakeInput(1000), r'$1,000');
    expect(AppUtils.formatStakeInput(10000), r'$10,000');
    expect(AppUtils.formatStakeInput(1000000), r'$1,000,000');
    expect(AppUtils.parseStakeInput(r'$10'), 10);
    expect(AppUtils.parseStakeInput(r'$1,000'), 1000);
    expect(AppUtils.parseStakeInput(r'$10,000'), 10000);
    expect(AppUtils.parseStakeInput(r'$1,000,000'), 1000000);
    expect(AppUtils.parseStakeInput('10000'), 10000);
  });
}
