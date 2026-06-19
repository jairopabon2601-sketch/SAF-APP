import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _CachedEntry {
  final String body;
  final DateTime expiresAt;
  _CachedEntry(this.body, Duration ttl) : expiresAt = DateTime.now().add(ttl);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class ApiService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'https://www.jorgemario.co/ext/saf';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _lastEmailKey = 'last_login_email';
  static const String _bgTimestampKey = 'bg_timestamp';
  static const int _sessionTimeoutMs = 5 * 60 * 1000; // 5 minutos
  static const Duration _cacheTtl = Duration(minutes: 5);

  String _baseUrl = _defaultBaseUrl;

  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  String? _token;
  Map<String, dynamic>? _user;
  SharedPreferences? _prefs;
  String? _sessionCookie; // PHPSESSID para endpoints que usan session_start()

  static const String _sessionKey = 'php_session_cookie';

  // In-memory response cache
  final Map<String, _CachedEntry> _memCache = {};

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String get baseUrl => _baseUrl;

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> init() async {
    if (_token != null && _user != null) return; // already initialised
    final prefs = await _getPrefs();
    _token = prefs.getString(_tokenKey);
    _sessionCookie = prefs.getString(_sessionKey);
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
      // Captura el PHPSESSID para endpoints que usan session_start()
      final setCookie = response.headers['set-cookie'] ?? '';
      final m = RegExp(r'PHPSESSID=[^;,\s]+').firstMatch(setCookie);
      if (m != null) _sessionCookie = m.group(0);

      final data = _parseResponse(response);

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
        await _saveSession();
        final prefs = await _getPrefs();
        await prefs.setString(_lastEmailKey, email);
      }

      final msg = data['mensaje']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString() ??
          (response.body.contains('<')
              ? 'Error del servidor (respuesta no es JSON)'
              : 'Error desconocido');

      return {'success': success, 'token': _token, 'user': _user, 'message': msg};
    } catch (e, st) {
      debugPrint('ApiService.login error: $e\n$st');
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _sessionCookie = null;
    _memCache.clear();
    final prefs = await _getPrefs();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_sessionKey);
    await prefs.remove(_bgTimestampKey);
  }

  Future<String?> getLastEmail() async {
    final prefs = await _getPrefs();
    return prefs.getString(_lastEmailKey);
  }

  Future<void> saveBackgroundTimestamp() async {
    if (_token == null) return;
    final prefs = await _getPrefs();
    await prefs.setInt(_bgTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns true if the session expired (> 5 min in background) and was cleared.
  Future<bool> checkAndHandleSessionTimeout() async {
    if (_token == null) return false;
    final prefs = await _getPrefs();
    final ts = prefs.getInt(_bgTimestampKey);
    if (ts == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - ts;
    await prefs.remove(_bgTimestampKey);
    if (elapsed > _sessionTimeoutMs) {
      await logout();
      return true;
    }
    return false;
  }

  /// POST with optional in-memory cache (use for read-only queries).
  Future<http.Response> cachedPost(
    String endpoint,
    Map<String, dynamic> body, {
    Duration ttl = _cacheTtl,
  }) async {
    final key = '$endpoint|${jsonEncode(body)}';
    final cached = _memCache[key];
    if (cached != null && cached.isValid) {
      return http.Response(cached.body, 200);
    }
    final response = await post(endpoint, body);
    if (response.statusCode == 200) {
      _memCache[key] = _CachedEntry(response.body, ttl);
    }
    return response;
  }

  void invalidateCache([String? endpointPrefix]) {
    if (endpointPrefix == null) {
      _memCache.clear();
    } else {
      _memCache.removeWhere((k, _) => k.startsWith(endpointPrefix));
    }
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    if (_sessionCookie != null) headers['Cookie'] = _sessionCookie!;
    return http.post(
      uri,
      headers: headers,
      body: body.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{'Accept': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    if (_sessionCookie != null) headers['Cookie'] = _sessionCookie!;
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
    final prefs = await _getPrefs();
    if (_token != null) await prefs.setString(_tokenKey, _token!);
    if (_user != null) await prefs.setString(_userKey, jsonEncode(_user));
    if (_sessionCookie != null) await prefs.setString(_sessionKey, _sessionCookie!);
  }

  // ── Local data cache helpers ──────────────────────────────────────

  Future<void> saveLocalData(String key, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString('cache_$key', jsonEncode(data));
      await prefs.setInt('cache_${key}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Returns cached list if it exists and is younger than [maxAge].
  Future<List<Map<String, dynamic>>?> loadLocalData(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    try {
      final prefs = await _getPrefs();
      final ts = prefs.getInt('cache_${key}_ts');
      if (ts == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > maxAge.inMilliseconds) return null;
      final raw = prefs.getString('cache_$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await _getPrefs();
    await prefs.setString(_baseUrlKey, url);
  }
}
