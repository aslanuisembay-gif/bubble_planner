import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'convex_env.dart';

/// Convex Auth (пароль + логин вручную).
class ConvexAuthSession {
  ConvexAuthSession._();

  static const _kRefresh = 'convex_refresh_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static String? _refreshToken;

  static Future<void> signIn({
    required String email,
    required String password,
    required bool signUp,
  }) async {
    if (!ConvexEnv.backendReady) {
      throw StateError('ConvexClient not ready');
    }
    final trimmedPass = password.trim();
    final u = email.trim();
    if (u.isEmpty) {
      throw ArgumentError('Укажите логин');
    }

    final raw = await ConvexClient.instance.action(
      name: 'auth:signIn',
      args: {
        'provider': 'password',
        'params': {
          'email': u,
          'password': trimmedPass,
          'flow': signUp ? 'signUp' : 'signIn',
        },
      },
    );
    final map = _parseActionJson(raw);
    await _applyTokensFromResponse(map);
  }

  static Future<void> _applyTokensFromResponse(Map<String, dynamic> map) async {
    final tokens = map['tokens'] as Map<String, dynamic>?;
    if (tokens == null) {
      throw Exception('Нет токена в ответе сервера');
    }
    final refresh = tokens['refreshToken'] as String?;
    final token = tokens['token'] as String?;
    if (refresh == null || token == null) {
      throw Exception('Некорректные токены');
    }
    _refreshToken = refresh;
    await _storage.write(key: _kRefresh, value: refresh);
    await ConvexClient.instance.setAuth(token: token);
    await ConvexClient.instance.setAuthWithRefresh(
      fetchToken: _fetchToken,
      onAuthChange: (_) {},
    );
  }

  static Future<String?> _fetchToken() async {
    final r = _refreshToken ?? await _storage.read(key: _kRefresh);
    if (r == null || r.isEmpty) {
      return null;
    }
    final raw = await ConvexClient.instance.action(
      name: 'auth:signIn',
      args: {'refreshToken': r},
    );
    final map = _parseActionJson(raw);
    final tokens = map['tokens'] as Map<String, dynamic>?;
    if (tokens == null) {
      return null;
    }
    final refresh = tokens['refreshToken'] as String?;
    final token = tokens['token'] as String?;
    if (refresh == null || token == null) {
      return null;
    }
    _refreshToken = refresh;
    await _storage.write(key: _kRefresh, value: refresh);
    return token;
  }

  static Future<bool> tryRestore() async {
    if (!ConvexEnv.backendReady) {
      return false;
    }
    final r = await _storage.read(key: _kRefresh);
    if (r == null || r.isEmpty) {
      return false;
    }
    _refreshToken = r;
    try {
      final jwt = await _fetchToken();
      if (jwt == null) {
        return false;
      }
      await ConvexClient.instance.setAuth(token: jwt);
      await ConvexClient.instance.setAuthWithRefresh(
        fetchToken: _fetchToken,
        onAuthChange: (_) {},
      );
      return true;
    } catch (e, st) {
      debugPrint('ConvexAuthSession.tryRestore: $e\n$st');
      await signOut();
      return false;
    }
  }

  static Map<String, dynamic> _parseActionJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is String) {
        throw Exception(decoded);
      }
      if (decoded is! Map) {
        throw Exception(raw);
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw Exception(raw);
    }
  }

  static Future<void> signOut() async {
    _refreshToken = null;
    await _storage.delete(key: _kRefresh);
    if (!ConvexEnv.backendReady) {
      return;
    }
    try {
      await ConvexClient.instance.action(name: 'auth:signOut', args: {});
    } catch (e, st) {
      debugPrint('auth:signOut: $e\n$st');
    }
    await ConvexClient.instance.clearAuth();
  }
}
