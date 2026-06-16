import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'https://www.jorgemario.co/ext/saf';
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
      final response = await get('/api/usuarios/perfil.php');
      if (response.statusCode != 200) return false;
      final data = _parseResponse(response);
      return data['resultado'] == 1 || data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await post('/ajax/login.php', {
        'usuario': email,
        'pass': password,
      });

      final data = _parseResponse(response);

      debugPrint('[SAF login] status: ${response.statusCode}');
      debugPrint('[SAF login] body: ${response.body}');

      // Web version: resultado==0 means failure, resultado==1 means success
      final resultado = data['resultado'];
      final success = resultado != null && resultado != 0 && resultado != '0' ||
          data['success'] == true;

      if (success) {
        _token = (data['token'] ?? data['access_token'] ?? data['jwt'])?.toString();
        final raw = data['usuario'] ?? data['user'] ?? data['data'] ??
            data['info'] ?? data['perfil'];
        if (raw is Map) {
          _user = Map<String, dynamic>.from(raw);
        } else {
          final topLevel = Map<String, dynamic>.from(data)
            ..remove('token')
            ..remove('access_token')
            ..remove('jwt')
            ..remove('resultado')
            ..remove('success')
            ..remove('status')
            ..remove('mensaje')
            ..remove('message');
          _user = topLevel.isNotEmpty ? topLevel : null;
        }
        debugPrint('[SAF API] user keys: ${_user?.keys.toList()}');
        await _saveSession();
      }

      final msg = data['mensaje']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString() ??
          (response.body.contains('<') ? 'Error del servidor (respuesta no es JSON)' : 'Error desconocido');

      return {
        'success': success,
        'token': _token,
        'user': _user,
        'message': msg,
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

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return http.post(
      uri,
      headers: headers,
      body: body.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{'Accept': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return http.get(uri, headers: headers);
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
