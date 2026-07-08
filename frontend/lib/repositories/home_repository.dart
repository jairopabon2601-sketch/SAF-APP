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
      api.saveLocalData(key, data);

  Future<List<Map<String, dynamic>>?> loadLocalData(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) =>
      api.loadLocalData(key, maxAge: maxAge);
}
