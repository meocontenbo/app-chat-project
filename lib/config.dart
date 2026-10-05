import 'package:flutter/foundation.dart';

/// Base URL of the Go API.
/// - Release builds of the native apps talk to production.
/// - Debug builds talk to a local server (run_server.bat).
/// - Override anything at build time: --dart-define=API_URL=https://example.com/api
class AppConfig {
  static const productionApiUrl = 'https://chat.langlachill.net/api';
  static const _override = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) {
      // Deployed web app is served by nginx next to the API (same origin).
      // Local dev (flutter run on localhost:5000) talks to the Go server on :8080.
      final host = Uri.base.host;
      if (host != 'localhost' && host != '127.0.0.1') return '${Uri.base.origin}/api';
      return 'http://localhost:8080/api';
    }
    if (kReleaseMode) return productionApiUrl;
    // Android emulator reaches the host machine via 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }
}
