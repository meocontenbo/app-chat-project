import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/token_store.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient api;
  final TokenStore _storage = TokenStore();

  AuthStatus status = AuthStatus.unknown;
  User? user;

  AuthProvider(this.api);

  /// Restores a saved session on app start.
  Future<void> init() async {
    final saved = await _storage.read();
    if (saved != null) {
      api.token = saved;
      try {
        user = User.fromJson(await api.get('/me'));
        status = AuthStatus.authenticated;
        notifyListeners();
        return;
      } on ApiException catch (e) {
        // Forget the token only when the server rejects it; if the server is
        // unreachable, keep it so the next launch can retry.
        if (e.statusCode == 401) await _storage.delete();
      }
      api.token = null;
    }
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    final res = await api.post('/auth/login', {'login': login, 'password': password});
    await _setSession(res);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await api.post('/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    await _setSession(res);
  }

  Future<void> logout() async {
    await _storage.delete();
    api.token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _setSession(Map<String, dynamic> res) async {
    final token = res['token'] as String;
    await _storage.write(token);
    api.token = token;
    user = User.fromJson(res['user'] as Map<String, dynamic>);
    status = AuthStatus.authenticated;
    notifyListeners();
  }
}
