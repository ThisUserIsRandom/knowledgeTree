import 'dart:io';
import 'package:flutter/foundation.dart';

/// Resolves the user-entered backend URL for the current platform.
///
/// On the Android emulator `localhost` / `127.0.0.1` refer to the emulator
/// itself, so they are transparently rewritten to `10.0.2.2` (the emulator's
/// alias for the host machine) to avoid "connection refused" errors.
class BackendUrl {
  static String resolve(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);

    if (kIsWeb) return u;
    if (Platform.isAndroid) {
      final hostRe = RegExp(r'^(https?://)(localhost|127\.0\.0\.1)(:\d+)?(.*)$');
      final m = hostRe.firstMatch(u);
      if (m != null) {
        u = '${m.group(1)}10.0.2.2${m.group(3) ?? ''}${m.group(4) ?? ''}';
      }
    }
    return u;
  }
}
