class PasswordResetLink {
  const PasswordResetLink._();

  static String? oobCodeFrom(Uri uri) {
    final direct = uri.queryParameters['oobCode'];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final fragment = uri.fragment;
    if (fragment.contains('oobCode=')) {
      final query = fragment.contains('?')
          ? fragment.substring(fragment.indexOf('?') + 1)
          : fragment;
      return Uri.splitQueryString(query)['oobCode'];
    }
    return null;
  }

  static bool isReset(Uri uri) {
    final mode = uri.queryParameters['mode'] ??
        (uri.fragment.contains('mode=')
            ? Uri.splitQueryString(
                uri.fragment.contains('?')
                    ? uri.fragment.substring(uri.fragment.indexOf('?') + 1)
                    : uri.fragment,
              )['mode']
            : null);
    return mode == 'resetPassword' && oobCodeFrom(uri) != null;
  }
}
