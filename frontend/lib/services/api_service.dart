import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'https://safenlinea.com';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  String _baseUrl = _defaultBaseUrl;

  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _baseUrl = _defaultBaseUrl;
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      try {
        final decoded = jsonDecode(userData);
        if (decoded is Map) {
          _user = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('Error parsing saved session: $e');
      }
    }
  }

  Future<bool> isLoggedIn() async {
    if (_token == null) return false;
    try {
      final response = await get('/auth/verify');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await post('/api/usuarios/login.php', {
        'email': email,
        'password': password,
      });

      final data = _parseResponse(response);

      if (response.statusCode == 200 && data['resultado'] == 1) {
        _token = data['token']?.toString();
        // Try every common key the API might use for the user object
        final raw = data['usuario'] ?? data['user'] ?? data['data'] ??
            data['info'] ?? data['perfil'];
        if (raw is Map) {
          _user = Map<String, dynamic>.from(raw);
        } else if (raw == null) {
          // Some APIs return the user fields at the top level alongside token
          final topLevel = Map<String, dynamic>.from(data)
            ..remove('token')
            ..remove('resultado')
            ..remove('mensaje')
            ..remove('message');
          _user = topLevel.isNotEmpty ? topLevel : null;
        } else {
          _user = null;
        }
        debugPrint('[SAF API] user keys: ${_user?.keys.toList()}');
        debugPrint('[SAF API] user: $_user');
        await _saveSession();
      }

      return {
        'success': data['resultado'] == 1,
        'token': data['token'],
        'user': data['usuario'],
        'message': data['mensaje'] ?? 'Error desconocido',
      };
    } catch (e, stackTrace) {
      debugPrint('ApiService.login error: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return http.get(
      uri,
      headers: await _headers(),
    );
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    return http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'success': false, 'message': 'Error al conectar con el servidor'};
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_tokenKey, _token!);
    }
    if (_user != null) {
      await prefs.setString(_userKey, jsonEncode(_user));
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }
}
