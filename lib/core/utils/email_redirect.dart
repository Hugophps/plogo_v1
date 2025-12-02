import 'package:flutter/foundation.dart' show kIsWeb;

import 'email_redirect_stub.dart'
    if (dart.library.html) 'email_redirect_web.dart';

const _mobileFallbackRedirect = 'http://localhost:3000/';

String resolveEmailRedirectTo() {
  if (kIsWeb) {
    final webBase = getWebRedirectOrigin();
    if (webBase.isNotEmpty) {
      return '$webBase/';
    }
  }
  return _mobileFallbackRedirect;
}
