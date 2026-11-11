import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import 'models.dart';

/// Login, registration and session persistence.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;
  static const _tokenKey = 'auth_token';

  /// Returns the user if a saved token is still valid.
  Future<User?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return null;
    _api.token = token;
    try {
      final data = await _api.get('/me');
      return User.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await logout();
      return null;
    }
  }

  Future<User> login(String email, String password) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  Future<User> register(String name, String email, String password) =>
      _authenticate('/auth/register', {'name': name, 'email': email, 'password': password});

  Future<User> _authenticate(String path, Map<String, dynamic> body) async {
    final data = (await _api.post(path, body)) as Map<String, dynamic>;
    final token = data['token'] as String;
    _api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    _api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
