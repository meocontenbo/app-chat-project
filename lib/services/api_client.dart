import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _http = http.Client();
  String? token;

  static const _defaultTimeout = Duration(seconds: 15);

  /// [timeout] must exceed the server's hold time when calling long-poll endpoints.
  Future<Map<String, dynamic>> get(String path, {Duration timeout = _defaultTimeout}) =>
      _send('GET', path, timeout: timeout);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  /// Like [post] but also returns the HTTP status (e.g. to tell 200 from 202).
  Future<(int, Map<String, dynamic>)> postWithStatus(String path, Map<String, dynamic> body) =>
      _sendRaw('POST', path, body: body);

  Future<Map<String, dynamic>> _send(String method, String path,
          {Map<String, dynamic>? body, Duration timeout = _defaultTimeout}) async =>
      (await _sendRaw(method, path, body: body, timeout: timeout)).$2;

  Future<(int, Map<String, dynamic>)> _sendRaw(String method, String path,
      {Map<String, dynamic>? body, Duration timeout = _defaultTimeout}) async {
    final req = http.Request(method, Uri.parse('${AppConfig.apiUrl}$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } catch (_) {
      throw ApiException(0, 'Không kết nối được tới server');
    }

    final data = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
          res.statusCode, data['error'] as String? ?? 'Lỗi ${res.statusCode}');
    }
    return (res.statusCode, data);
  }
}
