import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Portal de clientes (deudores): sesión propia, separada del personal SAF.
/// Solo consulta — el cliente ve sus créditos, cuotas y próximo pago.
class PortalService {
  static final PortalService _instance = PortalService._();
  factory PortalService() => _instance;
  PortalService._();

  /// ID de cliente OAuth de Google tipo "Aplicación web" — el MISMO que se
  /// configura en `_portal_helper.php` y en VITE_GOOGLE_CLIENT_ID de la web.
  /// Mientras esté vacío el botón "Continuar con Google" no se muestra.
  static const String googleServerClientId =
      '743517892586-5gehfr8jp96r75e6h8p4u5mhpkft6pss.apps.googleusercontent.com';

  /// ID de cliente OAuth tipo "iOS" (solo iPhone). Además hay que agregar su
  /// "REVERSED_CLIENT_ID" como URL Scheme en ios/Runner/Info.plist.
  static const String googleIosClientId =
      '743517892586-l08lgtd1k2698i8t6la3ae48rp973d3u.apps.googleusercontent.com';

  static bool get googleHabilitado =>
      googleServerClientId.isNotEmpty &&
      (defaultTargetPlatform != TargetPlatform.iOS ||
          googleIosClientId.isNotEmpty);

  static const _tokenKey = 'portal_token';
  static const _clienteKey = 'portal_cliente';

  String? _token;
  Map<String, dynamic>? _cliente;
  bool _loaded = false;

  String? get token => _token;
  Map<String, dynamic>? get cliente => _cliente;
  bool get isLoggedIn => (_token ?? '').isNotEmpty;

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_clienteKey);
    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) _cliente = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    _loaded = true;
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, String> body,
      {bool auth = false}) async {
    final uri = Uri.parse('${ApiService().baseUrl}/ajax/$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };
    final data = Map<String, String>.from(body);
    final t = _token;
    if (auth && t != null) {
      headers['X-Portal-Token'] = t;
      data['token'] = t;
    }
    final r = await http
        .post(uri, headers: headers, body: data)
        .timeout(const Duration(seconds: 25));
    final decoded = jsonDecode(r.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Respuesta inválida');
  }

  Future<Map<String, dynamic>> _guardarSiExito(Map<String, dynamic> d) async {
    final t = (d['token'] ?? '').toString();
    final c = d['cliente'];
    if (d['success'] == true && t.isNotEmpty && c is Map) {
      _token = t;
      _cliente = Map<String, dynamic>.from(c);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, t);
      await prefs.setString(_clienteKey, jsonEncode(_cliente));
    }
    return d;
  }

  Future<Map<String, dynamic>> login(String email, String clave) async =>
      _guardarSiExito(await _post('portal_login.php', {
        'email': email.trim(),
        'clave': clave,
      }));

  Future<Map<String, dynamic>> registro({
    required String documento,
    required String telefono,
    required String email,
    required String clave,
  }) async =>
      _guardarSiExito(await _post('portal_registro.php', {
        'documento': documento,
        'telefono': telefono,
        'email': email.trim(),
        'clave': clave,
      }));

  Future<Map<String, dynamic>> google(String idToken,
          {String documento = '', String telefono = ''}) async =>
      _guardarSiExito(await _post('portal_google.php', {
        'id_token': idToken,
        'documento': documento,
        'telefono': telefono,
      }));

  /// Abre el selector de cuentas de Google y devuelve el idToken, o null si
  /// el usuario lo canceló.
  Future<String?> obtenerIdTokenGoogle() async {
    final gs = GoogleSignIn(
      scopes: const ['email'],
      serverClientId: googleServerClientId,
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? googleIosClientId
          : null,
    );
    // Siempre deja elegir cuenta (no reutiliza la última en silencio).
    try {
      await gs.signOut();
    } catch (_) {}
    final cuenta = await gs.signIn();
    if (cuenta == null) return null;
    final auth = await cuenta.authentication;
    return auth.idToken;
  }

  Future<Map<String, dynamic>> misCreditos() =>
      _post('portal_mis_creditos.php', {}, auth: true);

  Future<void> logout() async {
    try {
      if (isLoggedIn) await _post('portal_logout.php', {}, auth: true);
    } catch (_) {}
    _token = null;
    _cliente = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_clienteKey);
  }
}
