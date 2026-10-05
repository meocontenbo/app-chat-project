import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the auth token. Prefers the OS secure store (Keychain / Credential Manager /
/// Keystore / libsecret); if that is unavailable — e.g. an ad-hoc signed, sandboxed macOS
/// build gets errSecMissingEntitlement (-34018) — it falls back to the app's private
/// preferences file so login still works.
class TokenStore {
  static const _key = 'auth_token';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  bool _secureBroken = false;

  Future<String?> read() async {
    if (!_secureBroken) {
      try {
        final v = await _secure.read(key: _key);
        if (v != null) return v;
      } on PlatformException {
        _secureBroken = true;
      }
    }
    return (await SharedPreferences.getInstance()).getString(_key);
  }

  Future<void> write(String token) async {
    if (!_secureBroken) {
      try {
        await _secure.write(key: _key, value: token);
        return;
      } on PlatformException {
        _secureBroken = true;
      }
    }
    await (await SharedPreferences.getInstance()).setString(_key, token);
  }

  Future<void> delete() async {
    if (!_secureBroken) {
      try {
        await _secure.delete(key: _key);
      } on PlatformException {
        _secureBroken = true;
      }
    }
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
