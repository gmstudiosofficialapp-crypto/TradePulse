import 'package:flutter/material.dart';

class Breakpoints {
  static const double compact = 700;
  static const double wide = 1100;

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compact;
  }

  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= wide;
  }
}
