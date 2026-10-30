import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../services/api_service.dart';

/// Punto de acceso a los datos utilizados por la pantalla principal.
///
/// Mantiene `ApiService` fuera de los widgets y permite reemplazarlo en
/// pruebas o migrar endpoints sin acoplar la interfaz a la implementación.
class HomeRepository {
  HomeRepository({ApiService? api}) : api = api ?? ApiService();

  final ApiService api;

  Map<String, dynamic>? get user => api.user;

  // ── "Ver como…" ───────────────────────────────────────────────────────
  Map<String, dynamic>? get viewAsUser => api.viewAsUser;
  set viewAsUser(Map<String, dynamic>? value) => api.viewAsUser = value;

  String get ownUserCode => (user?['codigo_usuario'] ?? '').toString();

  /// true cuando un administrador está consultando a otro usuario.
  bool get isViewingAs {
    final v = api.viewAsUser;
    if (v == null) return false;
    if ((user?['codigo_perfil'] ?? '').toString() != '6') return false;
    final code = (v['codigo_usuario'] ?? '').toString();
    return code.isNotEmpty && code != ownUserCode;
  }

  /// Usuario cuyas cuentas/movimientos se piden al servidor.
  String get dataUserCode => isViewingAs
      ? (api.viewAsUser!['codigo_usuario'] ?? '').toString()
      : ownUserCode;

  // La copia local (SharedPreferences) se separa por usuario consultado para
  // que los saldos de "Negocios" nunca pisen los del administrador.
  String _scopedKey(String key) =>
      isViewingAs ? '${key}__as_$dataUserCode' : key;

  Future<void> init() => api.init();

  Future<void> logout() => api.logout();

  Future<void> persistUser() => api.persistUser();

  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) =>
      api.post(endpoint, body);

  Future<http.Response> cachedPost(
    String endpoint,
    Map<String, dynamic> body, {
    Duration ttl = const Duration(minutes: 5),
  }) =>
      api.cachedPost(endpoint, body, ttl: ttl);

  void invalidateCache([String? endpointPrefix]) {
    api.invalidateCache(endpointPrefix);
  }

  Future<void> saveLocalData(
    String key,
    List<Map<String, dynamic>> data,
  ) =>
      api.saveLocalData(_scopedKey(key), data);

  Future<List<Map<String, dynamic>>?> loadLocalData(
    String key, {
    Duration maxAge = const Duration(days: 30),
  }) =>
      api.loadLocalData(_scopedKey(key), maxAge: maxAge);

  Future<void> saveImageCache(String key, Uint8List bytes) =>
      api.saveImageCache(key, bytes);

  Future<Uint8List?> loadImageCache(String key) => api.loadImageCache(key);

  Uint8List? getMemImageCache(String key) => api.getMemImageCache(key);
}
