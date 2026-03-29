String userFacingErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error == null) {
    return fallback;
  }

  var raw = error.toString().trim();
  if (raw.isEmpty) {
    return fallback;
  }

  const prefixes = ['Exception:', 'DioException [unknown]:', 'DioException:'];
  for (final prefix in prefixes) {
    if (raw.startsWith(prefix)) {
      raw = raw.substring(prefix.length).trim();
    }
  }

  final lower = raw.toLowerCase();

  if (lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection error') ||
      lower.contains('timed out')) {
    return "Can't reach LabGuard right now. Check your connection and try again.";
  }

  if ((lower.contains('refresh token') || lower.contains('session')) &&
      (lower.contains('invalid') || lower.contains('expired'))) {
    return 'Your session has ended. Sign in again to continue.';
  }

  if (lower.contains('not yet trusted') ||
      (lower.contains('invitation code') &&
          (lower.contains('invalid') || lower.contains('expired')))) {
    return 'This account is not approved yet. Use a valid invite code or contact the owner.';
  }

  if (lower.contains('identity is required')) {
    return 'Enter an approved account email to continue.';
  }

  if (lower.contains('location permission is required')) {
    return 'Allow location access before refreshing this device location.';
  }

  if (lower.contains('no production-ready vpn region') ||
      lower.contains('vpn infrastructure unavailable')) {
    return 'VPN regions are not ready for this account yet.';
  }

  if (lower.contains('request_in_progress') ||
      lower.contains('already in progress') ||
      lower.contains('already pending')) {
    return 'Another request is already in progress.';
  }

  if (lower.contains('route get:/') || lower == 'not found') {
    return fallback;
  }

  if (raw.startsWith('Unable to') ||
      raw.startsWith("Can't ") ||
      raw.startsWith('This ') ||
      raw.startsWith('Allow ')) {
    return raw;
  }

  return raw;
}
