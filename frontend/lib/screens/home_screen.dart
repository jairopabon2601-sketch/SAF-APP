import 'dart:async';
import 'dart:convert';
import 'dart:math' show min, pi;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../widgets/saf_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  // ── Services & controllers ──────────────────────────────────────
  final _api = ApiService();

  // ── UI state ────────────────────────────────────────────────────
  bool _balanceVisible = true;
  int _selectedIndex = 0;
  int _movSubTab = 0; // 0=Cuentas 1=Movimientos
  int _creditoSubTab = 0; // 0=Aprobados 1=Pendientes 2=Simular 3=Estadística

  // Estadísticas (8 sub-pestañas)
  int _estSubTab = 6; // arranca en "Mejor Scoring" como la web
  final Map<String, String> _estFiltros = {}; // clave columna → texto filtro
  bool _estLoading = false;
  List<Map<String, dynamic>> _estData = [];
  int _estPage = 0; // página actual (0-based)
  static const int _estPorPagina = 10;
  Timer? _filterDebounce;

  // Filtros movimientos
  String _filterCuenta = '';
  String _filterTipo = '';
  DateTime? _filterDesde;
  DateTime? _filterHasta;

  // Totales del servidor (últimos 30 días, via listado_json_campos.php)
  double _srvGastos = 0.0;
  double _srvIngresos = 0.0;
  bool _srvTotalesLoaded = false;
  double _filtGastos = 0.0;
  double _filtIngresos = 0.0;
  bool _filtTotalesLoaded = false;

  // Filtros créditos
  String _creditoFiltroEstado = '';
  String _creditoFiltroAsesor = '';
  bool _creditoConsultando = false;
  int _creditoPagina = 1;
  int _creditosTotal = 0;
  double _creditosTotalPagado = 0;
  double _creditosTotalPendiente = 0;
  static const int _creditosPorPagina = 20;

  // Pendientes (solicitudes)
  List<Map<String, dynamic>> _pendientesLista = [];
  int _pendientesPagina = 1;
  int _pendientesTotal = 0;
  bool _pendientesLoading = false;
  bool _pendientesLoaded = false;

  // Listas para diálogos
  List<Map<String, dynamic>> _deudoresLista = [];
  List<Map<String, dynamic>> _tasasLista = [];
  List<Map<String, dynamic>> _fuentesLista = [];
  List<Map<String, dynamic>> _asesoresLista = [];

  // Filtros de Estadística por Fuente
  String _statEstado =
      ''; // '' = Todos, '1' = Activos, '2' = Pagados, '3' = Pendientes
  DateTime? _statFechaDesde;
  DateTime? _statFechaHasta;
  String _statFuente = '0'; // '0' = Todos, o codigo de tbl_cuentas
  bool _statLoading = false;

  // Simulador crédito
  double _simMeses = 12;
  double _simMonto = 1000000;
  double _simTasa = 10;
  DateTime? _simDesde;
  DateTime? _simHasta;

  // ── Data state ──────────────────────────────────────────────────
  bool _loadingData = true;
  List<Map<String, dynamic>> _cuentas = [];
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _ahorradores = []; // Lista completa del año
  List<Map<String, dynamic>> _creditos =
      []; // Estadística por fuente (get_estadistica_fuente.php)
  String _ahorFilterAnio = DateTime.now().year.toString();
  String _ahorFilterAsesor = '0'; // '0' = Todos; o la sigla (DT, JP, …)
  List<Map<String, dynamic>> _creditosLista = []; // Aprobados/Pendientes
  final Set<String> _expandedCreditos = {};

  // ── Memoisation caches ──────────────────────────────────────────
  double? _cachedTotalSaldo;
  double? _cachedTotalIngresos;
  double? _cachedTotalEgresos;
  List<Map<String, dynamic>>? _cachedAhorradoresFiltrados;
  String? _cachedAhorFilterAsesor;

  void _invalidateComputedCache() {
    _cachedTotalSaldo = null;
    _cachedTotalIngresos = null;
    _cachedTotalEgresos = null;
    _cachedAhorradoresFiltrados = null;
  }

  // Mapa sigla → nombre completo del asesor (igual que el select de la web)
  static const Map<String, String> _asesorNombres = {
    'AH': 'Angie Hernandez',
    'DT': 'Duvan Tapias',
    'JP': 'Jairo Pabón',
    'MD': 'Manuel De la Cruz',
    'RV': 'Rafael Vanegas',
    'SAF': 'SAF .',
    'VB': 'Victor Barros',
  };

  String _nombreAsesor(String sigla) =>
      _asesorNombres[sigla.toUpperCase()] ?? sigla;

  // Ahorradores tras aplicar el filtro de asesor (memoizado)
  List<Map<String, dynamic>> get _ahorradoresFiltrados {
    if (_cachedAhorFilterAsesor == _ahorFilterAsesor &&
        _cachedAhorradoresFiltrados != null) {
      return _cachedAhorradoresFiltrados!;
    }
    _cachedAhorFilterAsesor = _ahorFilterAsesor;
    if (_ahorFilterAsesor == '0') {
      _cachedAhorradoresFiltrados = _ahorradores;
    } else {
      _cachedAhorradoresFiltrados = _ahorradores
          .where((a) =>
              (a['asesor'] ?? '').toString().trim().toUpperCase() ==
              _ahorFilterAsesor.toUpperCase())
          .toList();
    }
    return _cachedAhorradoresFiltrados!;
  }

  // ── Computed (memoized) ─────────────────────────────────────────
  double get _totalSaldo {
    _cachedTotalSaldo ??= _cuentas.fold<double>(
        0.0,
        (s, c) =>
            s + _num(c['saldo_actual'] ?? c['saldo'] ?? c['balance'] ?? 0));
    return _cachedTotalSaldo!;
  }

  double get _totalIngresos {
    if (_srvTotalesLoaded) return _srvIngresos;
    _cachedTotalIngresos ??= _movimientos.where((m) {
      final t = (m['tipo_movimiento'] ?? '').toString();
      return t == '3' || t == '1';
    }).fold<double>(0.0, (s, m) => s + _num(m['valor'] ?? 0));
    return _cachedTotalIngresos!;
  }

  double get _totalEgresos {
    if (_srvTotalesLoaded) return _srvGastos;
    _cachedTotalEgresos ??= _movimientos
        .where((m) => (m['tipo_movimiento'] ?? '').toString() == '2')
        .fold<double>(0.0, (s, m) => s + _num(m['valor'] ?? 0));
    return _cachedTotalEgresos!;
  }

  // ── Theme ───────────────────────────────────────────────────────
  static const _navy = Color(0xFF0D1B4B);
  static const _accent1 = Color(0xFF4361EE);
  static const _accent2 = Color(0xFF00D2FF);
  static const _bg = Color(0xFFF0F2FA);

  // Nav tab colors — each DISTINCT, readable on dark navy
  static const _navColors = [
    Color(0xFF60A5FA), // Inicio     – blue
    Color(0xFF34D399), // Créditos   – emerald
    Color(0xFFA78BFA), // Ahorros    – violet
    Color(0xFF38BDF8), // Movimientos– sky
    Color(0xFFFBBF24), // Estadística– amber
  ];

  // ── Lifecycle ───────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _filterDebounce?.cancel();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────
  Future<void> _loadData() async {
    await _api.init();
    final u = _api.user;
    final codigoUsuario = u?['codigo_usuario']?.toString() ?? '';
    final anio = DateTime.now().year.toString();

    // Show cached data immediately so the screen isn't blank
    final cachedCuentas = await _api.loadLocalData('cuentas');
    final cachedMovs = await _api.loadLocalData('movimientos');
    final cachedAhorradores = await _api.loadLocalData('ahorradores');
    final cachedCreditos = await _api.loadLocalData('creditos');
    final cachedCreditosLista = await _api.loadLocalData('creditos_lista');

    if (cachedCuentas != null) {
      _cuentas = cachedCuentas;
      _invalidateComputedCache();
    }
    if (cachedMovs != null) {
      _movimientos = cachedMovs;
      _invalidateComputedCache();
    }
    if (cachedAhorradores != null) _ahorradores = cachedAhorradores;
    if (cachedCreditos != null) _creditos = cachedCreditos;
    if (cachedCreditosLista != null) _creditosLista = cachedCreditosLista;

    final hasCachedData = cachedCuentas != null;
    if (hasCachedData && mounted) setState(() => _loadingData = false);

    // Fetch fresh data from network
    await _fetchCuentas(codigoUsuario);
    // Primero cargar créditos y ahorradores (fuentes del fallback de deudores)
    // Filtro por defecto: últimos 30 días (igual que el web)
    final now = DateTime.now();
    _filterDesde ??= now.subtract(const Duration(days: 31));
    _filterHasta ??= now;

    await Future.wait([
      _fetchMovimientosTodasCuentas(codigoUsuario),
      _fetchAhorradores(anio),
      _fetchCreditos(codigoUsuario),
      _fetchTotalesResumen(codigoUsuario),
    ]);
    // Totales de créditos van después para no ser sobreescritos por _fetchCreditos
    await _fetchTotalesCreditos();
    // Con _creditosLista ya cargada, construir deudores al instante
    _tryBuildDeudoresFromLocal();
    // Tasas y fuentes en paralelo; deudores via API en background (no bloquea)
    unawaited(_fetchDeudores());
    await Future.wait([_fetchTasas(), _fetchFuentes(), _fetchAsesores()]);

    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _fetchCuentas(String filtro) async {
    try {
      final r = await _api
          .cachedPost('/ajax/listar_cuentas_gasto.php', {'filtro': filtro});
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        List<dynamic>? list;
        if (d is List) {
          list = d;
        } else if (d is Map) {
          for (final k in ['cuentas', 'datos', 'data', 'resultado_datos']) {
            if (d[k] is List) {
              list = d[k] as List;
              break;
            }
          }
        }
        if (list != null) {
          _cuentas = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _invalidateComputedCache();
          unawaited(_api.saveLocalData('cuentas', _cuentas));
        }
      }
    } catch (e) {
      debugPrint('[SAF] cuentas: $e');
    }
  }

  Future<void> _fetchMovimientosTodasCuentas(String usuario) async {
    final all = <Map<String, dynamic>>[];
    // Process in batches of 3 to avoid saturating the network
    const batchSize = 3;
    for (var i = 0; i < _cuentas.length; i += batchSize) {
      final batch = _cuentas.skip(i).take(batchSize);
      await Future.wait(batch.map((cuenta) async {
        final codigo = cuenta['codigo']?.toString() ?? '';
        if (codigo.isEmpty) return;
        try {
          final r = await _api.cachedPost('/ajax/listar_movimientos_cuenta.php',
              {'codigo_cuenta': codigo, 'pagina': '1', 'usuario': usuario});
          if (r.statusCode == 200) {
            final d = _json(r.body);
            final list = d['movimientos'];
            if (list is List) {
              for (final m in list) {
                if (m is Map) {
                  final mov = Map<String, dynamic>.from(m);
                  mov['cuenta_nombre'] = cuenta['nombre'];
                  mov['cuenta_color'] = cuenta['color'];
                  all.add(mov);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[SAF] mov cuenta $codigo: $e');
        }
      }));
    }
    all.sort((a, b) {
      // Normalize to date-only (first 10 chars) so timestamps don't affect grouping
      final fechaA = (a['fecha'] ?? '').toString();
      final fechaB = (b['fecha'] ?? '').toString();
      final dA = fechaA.length >= 10 ? fechaA.substring(0, 10) : fechaA;
      final dB = fechaB.length >= 10 ? fechaB.substring(0, 10) : fechaB;
      final cmpFecha = dB.compareTo(dA); // date DESC
      if (cmpFecha != 0) return cmpFecha;
      // Within same date: ASC by codigo (matches web order)
      final idA =
          int.tryParse((a['codigo'] ?? a['codigo_movimiento'] ?? a['id'] ?? '0').toString()) ??
              0;
      final idB =
          int.tryParse((b['codigo'] ?? b['codigo_movimiento'] ?? b['id'] ?? '0').toString()) ??
              0;
      return idA.compareTo(idB);
    });
    _movimientos = all;
    _invalidateComputedCache();
    unawaited(_api.saveLocalData('movimientos', _movimientos));
  }

  Future<void> _fetchTotalesFiltrados() async {
    final usuario = (_api.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    String pad2(int n) => n.toString().padLeft(2, '0');
    final desde =
        _filterDesde ?? DateTime.now().subtract(const Duration(days: 31));
    final hasta = _filterHasta ?? DateTime.now();
    final dStr = '${desde.year}-${pad2(desde.month)}-${pad2(desde.day)}';
    final hStr = '${hasta.year}-${pad2(hasta.month)}-${pad2(hasta.day)}';
    String filtro =
        'm.usuario="$usuario" and m.fecha between "$dStr" and "$hStr"';
    if (_filterTipo.isNotEmpty) filtro += ' and m.tipo_movimiento=$_filterTipo';
    if (_filterCuenta.isNotEmpty) {
      final cuenta = _cuentas.firstWhere(
          (c) => (c['nombre'] ?? '') == _filterCuenta,
          orElse: () => {});
      final cod = (cuenta['codigo'] ?? '').toString();
      if (cod.isNotEmpty) filtro += ' and m.codigo_cuenta=$cod';
    }
    try {
      final r = await _api.post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_gastos_ingresos',
        'filtro': filtro,
        'agrupacion': '',
      });
      if (r.statusCode == 200) {
        final d = _json(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          double g = 0.0, ing = 0.0;
          for (final k in row.keys) {
            final kl = k.toString().toLowerCase();
            if (kl.contains('gasto')) g = _num(row[k]);
            if (kl.contains('ingreso')) ing = _num(row[k]);
          }
          if (mounted) {
            setState(() {
              _filtGastos = g;
              _filtIngresos = ing;
              _filtTotalesLoaded = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotalesFiltrados: $e');
    }
  }

  Future<void> _fetchTotalesResumen(String usuario) async {
    final now = DateTime.now();
    final desde = now.subtract(const Duration(days: 31));
    String pad2(int n) => n.toString().padLeft(2, '0');
    final dStr = '${desde.year}-${pad2(desde.month)}-${pad2(desde.day)}';
    final hStr = '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
    final filtro =
        'm.usuario="$usuario" and m.fecha between "$dStr" and "$hStr"';
    try {
      final r = await _api.post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_gastos_ingresos',
        'filtro': filtro,
        'agrupacion': '',
      });
      if (r.statusCode == 200) {
        final d = _json(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          double g = 0.0, ing = 0.0;
          for (final k in row.keys) {
            final kl = k.toString().toLowerCase();
            if (kl.contains('gasto')) g = _num(row[k]);
            if (kl.contains('ingreso')) ing = _num(row[k]);
          }
          if (mounted) {
            setState(() {
              _srvGastos = g;
              _srvIngresos = ing;
              _srvTotalesLoaded = true;
              _invalidateComputedCache();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotales: $e');
    }
  }

  Future<void> _fetchTotalesCreditos() async {
    try {
      final r = await _api.post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_creditos_valores',
        'filtro': '',
        'agrupacion': '',
      });
      if (r.statusCode == 200) {
        final d = _json(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          // Los valores vienen formateados: "$388,207,190" o "$388.207.190"
          double parseFmt(dynamic v) {
            final s = v.toString().replaceAll(RegExp(r'[^\d]'), '');
            return double.tryParse(s) ?? 0.0;
          }

          final pagado = parseFmt(row['pagado'] ?? row['total_pagado'] ?? 0);
          final pendiente =
              parseFmt(row['pendiente'] ?? row['total_pendiente'] ?? 0);
          if (mounted && (pagado > 0 || pendiente > 0)) {
            setState(() {
              _creditosTotalPagado = pagado;
              _creditosTotalPendiente = pendiente;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotalesCreditos: $e');
    }
  }

  Future<void> _fetchAhorradores([String? anio, String? asesor]) async {
    try {
      final r = await _api.cachedPost('/ajax/listado_ahorros.php', {
        'anio_ahorro': anio ?? _ahorFilterAnio,
        'filtro_asesor': asesor ?? _ahorFilterAsesor,
      });
      if (r.statusCode == 200) {
        final d = _json(r.body);
        final list = d['ahorradores'];
        if (list is List) {
          _ahorradores = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _cachedAhorradoresFiltrados = null;
          unawaited(_api.saveLocalData('ahorradores', _ahorradores));
        }
      }
    } catch (e) {
      debugPrint('[SAF] ahorradores: $e');
    }
  }

  Future<void> _reloadAhorradores() async {
    setState(() => _loadingData = true);
    await _fetchAhorradores();
    setState(() => _loadingData = false);
  }

  Future<void> _fetchCreditos(String filtro) async {
    // Lista de créditos — endpoint dedicado con JSON + paginación
    try {
      final r = await _api.post('/ajax/get_creditos_lista.php', {
        'estado': _creditoFiltroEstado,
        'asesor': _creditoFiltroAsesor,
        'pagina': _creditoPagina.toString(),
        'por_pagina': _creditosPorPagina.toString(),
      });
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['datos'] is List) {
          _creditosTotal =
              int.tryParse(decoded['total']?.toString() ?? '0') ?? 0;
          _creditosTotalPagado = double.tryParse(
                  decoded['total_pagado_global']?.toString() ?? '0') ??
              0;
          _creditosTotalPendiente = double.tryParse(
                  decoded['total_pendiente_global']?.toString() ?? '0') ??
              0;
          _creditosLista = (decoded['datos'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          unawaited(_api.saveLocalData('creditos_lista', _creditosLista));
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos lista: $e');
    }

    // Estadística por fuente — endpoint dedicado con campos fijos
    try {
      final r = await _api.cachedPost('/ajax/get_estadistica_fuente.php', {},
          ttl: const Duration(minutes: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && decoded.isNotEmpty) {
          _creditos = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          unawaited(_api.saveLocalData('creditos', _creditos));
          return;
        }
      }
      debugPrint(
          '[SAF] get_estadistica_fuente status=${r.statusCode} body=${r.body.substring(0, r.body.length.clamp(0, 300))}');
    } catch (e) {
      debugPrint('[SAF] estadistica fuente: $e');
    }

    // Fallback 1: calcular desde _creditosLista ya cargada
    final local = _buildEstadisticaFromLocal();
    if (local.isNotEmpty) {
      _creditos = local;
      return;
    }

    // Fallback 2: query original json_total_creditos_valores (campos variables pero nunca vacío)
    try {
      final r = await _api.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_total_creditos_valores', 'filtro': filtro});
      if (r.statusCode == 200) {
        final d = _json(r.body);
        final list = d['datos'];
        if (list is List && list.isNotEmpty) {
          final raw = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          debugPrint(
              '[SAF] json_total_creditos_valores keys: ${raw.first.keys.toList()}');
          debugPrint('[SAF] json_total_creditos_valores first: ${raw.first}');
          _creditos = raw;
          unawaited(_api.saveLocalData('creditos', _creditos));
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos stat fallback: $e');
    }
  }

  /// Llama get_estadistica_fuente.php con los filtros activos y actualiza _creditos.
  Future<void> _aplicarFiltrosEstadistica() async {
    if (!mounted) return;
    setState(() => _statLoading = true);
    String fmt(DateTime? d) => d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      _api.invalidateCache('/ajax/get_estadistica_fuente.php');
      final r = await _api.post('/ajax/get_estadistica_fuente.php', {
        'estado': _statEstado,
        'fecha_desde': fmt(_statFechaDesde),
        'fecha_hasta': fmt(_statFechaHasta),
        'fuente': _statFuente,
      }).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && mounted) {
          setState(() {
            _creditos = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            _statLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[SAF] aplicarFiltros: $e');
    }
    if (mounted) setState(() => _statLoading = false);
  }

  /// Agrega _creditosLista por fuente para obtener salidas. Entradas = 0 (sin data de pagos).
  List<Map<String, dynamic>> _buildEstadisticaFromLocal() {
    if (_creditosLista.isEmpty) return [];
    const fuenteKeys = [
      'fuente',
      'nombre_fuente',
      'cuenta',
      'nombre_cuenta',
      'origen',
      'nombre_origen',
      'nombre',
      'fuente_nombre',
    ];
    const valorKeys = [
      'monto',
      'valor_prestamo',
      'valor_credito',
      'valor',
      'prestado',
      'total'
    ];
    final first = _creditosLista.first;
    final allKeys = first.keys.toList();
    debugPrint('[SAF] creditosLista keys: $allKeys  first: $first');

    final fk =
        fuenteKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    // Intenta campo de valor conocido; si no, usa el primero con valor numérico > 0
    var vk = valorKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    if (vk.isEmpty) {
      vk = allKeys.firstWhere((k) => _num(first[k]) > 0, orElse: () => '');
    }
    if (vk.isEmpty) return [];

    final mapa = <String, double>{};
    for (final c in _creditosLista) {
      final fuente = fk.isNotEmpty
          ? (c[fk] ?? 'Sin fuente').toString().trim()
          : 'Sin fuente';
      mapa[fuente] = (mapa[fuente] ?? 0) + _num(c[vk]);
    }
    final result = mapa.entries
        .map((e) =>
            {'fuente': e.key, 'total_salidas': e.value, 'total_entradas': 0.0})
        .toList();
    result.sort((a, b) =>
        (b['total_salidas'] as double).compareTo(a['total_salidas'] as double));
    debugPrint(
        '[SAF] fallback estadistica: ${result.length} fuentes, total=${result.fold(0.0, (s, r) => s + (r["total_salidas"] as double))}');
    return result;
  }

  // Carga la estadística de la sub-pestaña activa.
  Future<void> _fetchEstadistica() async {
    final codigo = _estTabs[_estSubTab].$2;
    setState(() {
      _estLoading = true;
      _estData = [];
    });
    try {
      final r = await _api.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': codigo, 'filtro': '', 'agrupacion': ''},
          ttl: const Duration(minutes: 10));
      if (r.statusCode == 200) {
        final d = _json(r.body);
        final list = d['datos'] ?? d['resultado_datos'] ?? d['data'];
        if (list is List) {
          _estData = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] estadistica: $e');
    } finally {
      if (mounted) setState(() => _estLoading = false);
    }
  }

  // Construye _deudoresLista desde datos ya en memoria (sin red).
  void _tryBuildDeudoresFromLocal() {
    if (_deudoresLista.isNotEmpty) return;

    // Campos de nombre conocidos, en orden de preferencia
    const nameKeys = [
      'cliente',
      'deudor',
      'etiqueta',
      'nombre_deudor',
      'deudor_nombre',
      'nombre_completo',
      'fullname',
      'nombre',
      'nombres',
    ];
    // Valores que claramente NO son nombres de persona
    final notName = RegExp(
        r'^(activ|pagad|pendient|inactiv|mensual|quincenal|semanal|diario|fijo|variable|\d)',
        caseSensitive: false);

    String extractName(Map<String, dynamic> c) {
      // 1. Campos conocidos
      for (final k in nameKeys) {
        final v = c[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      // 2. Nombres + apellidos concatenados
      final n =
          '${c['nombres'] ?? c['nombre'] ?? ''} ${c['apellidos'] ?? c['apellido'] ?? ''}'
              .trim();
      if (n.isNotEmpty) return n;
      // 3. Escanear todos los strings: buscar el más largo que parezca nombre
      String best = '';
      for (final v in c.values) {
        if (v is! String) continue;
        final s = v.trim();
        if (s.length > best.length &&
            s.contains(' ') &&
            s.length > 5 &&
            !notName.hasMatch(s) &&
            !s.contains('<') &&
            !s.contains('/')) {
          best = s;
        }
      }
      return best;
    }

    for (final source in [_creditosLista, _ahorradores]) {
      if (source.isEmpty) continue;
      final seen = <String>{};
      final lista = <Map<String, dynamic>>[];
      for (final c in source) {
        final label = extractName(c);
        final id = (c['valor'] ??
                c['codigo_deudor'] ??
                c['id_deudor'] ??
                c['codigo'] ??
                c['id'] ??
                label)
            .toString();
        if (label.isNotEmpty && seen.add(id)) {
          lista.add({'valor': id, 'etiqueta': label});
        }
      }
      if (lista.isNotEmpty) {
        lista.sort((a, b) =>
            a['etiqueta'].toString().compareTo(b['etiqueta'].toString()));
        _deudoresLista = lista;
        debugPrint(
            '[SAF] deudores desde local: ${lista.length} — primer item: ${lista.first}');
        return;
      }
    }
    debugPrint(
        '[SAF] _tryBuildDeudoresFromLocal: creditosLista=${_creditosLista.length}, ahorradores=${_ahorradores.length}');
    if (_creditosLista.isNotEmpty) {
      debugPrint(
          '[SAF] creditosLista[0] keys: ${_creditosLista.first.keys.toList()}');
    }
  }

  Future<void> _fetchDeudores() async {
    try {
      final r = await _api
          .cachedPost('/ajax/get_deudores.php', {},
              ttl: const Duration(minutes: 10))
          .timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        List<dynamic>? list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          for (final k in [
            'datos',
            'data',
            'resultado',
            'resultado_datos',
            'items',
            'deudores'
          ]) {
            if (decoded[k] is List) {
              list = decoded[k] as List;
              break;
            }
          }
        }
        if (list != null && list.isNotEmpty) {
          _deudoresLista = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          return;
        }
      }
      debugPrint(
          '[SAF] get_deudores.php status=${r.statusCode} body=${r.body.substring(0, r.body.length.clamp(0, 200))}');
    } catch (e) {
      debugPrint('[SAF] deudores fetch: $e');
    }

    // Fallback: extraer desde creditosLista (campo real: 'cliente')
    if (_deudoresLista.isEmpty && _creditosLista.isNotEmpty) {
      final seen = <String>{};
      final lista = <Map<String, dynamic>>[];
      for (final c in _creditosLista) {
        final label = [
              c['cliente'],
              c['nombre_deudor'],
              c['deudor_nombre'],
              c['nombre_completo'],
              c['deudor'],
              c['nombre'],
              c['nombres']
            ]
                .firstWhere((v) => v != null && v.toString().trim().isNotEmpty,
                    orElse: () => null)
                ?.toString()
                .trim() ??
            '';
        final id = (c['codigo_deudor'] ??
                c['id_deudor'] ??
                c['codigo'] ??
                c['id'] ??
                label)
            .toString();
        if (label.isNotEmpty && seen.add(id)) {
          lista.add({'valor': id, 'etiqueta': label});
        }
      }
      if (lista.isNotEmpty) {
        lista.sort((a, b) =>
            a['etiqueta'].toString().compareTo(b['etiqueta'].toString()));
        _deudoresLista = lista;
      }
    }
  }

  Future<void> _fetchTasas() async {
    try {
      final r = await _api.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_tasas', 'filtro': '', 'agrupacion': ''},
          ttl: const Duration(hours: 1));
      if (r.statusCode == 200) {
        final d = _json(r.body);
        final list = d['datos'] ?? d['data'] ?? d['tasas'];
        if (list is List) {
          _tasasLista = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] tasas: $e');
    }
  }

  Future<void> _fetchFuentes() async {
    try {
      final r = await _api.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_fuentes', 'filtro': '', 'agrupacion': ''},
          ttl: const Duration(hours: 1));
      if (r.statusCode == 200) {
        final d = _json(r.body);
        final list = d['datos'] ?? d['data'] ?? d['fuentes'];
        if (list is List) {
          _fuentesLista = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] fuentes: $e');
    }
  }

  Future<void> _fetchPendientes() async {
    if (mounted) setState(() => _pendientesLoading = true);
    try {
      final r = await _api.post('/ajax/get_pendientes_lista.php', {
        'asesor': _creditoFiltroAsesor,
        'estado': _creditoFiltroEstado,
        'pagina': _pendientesPagina.toString(),
        'por_pagina': _creditosPorPagina.toString(),
      });
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['datos'] is List) {
          _pendientesTotal =
              int.tryParse(decoded['total']?.toString() ?? '0') ?? 0;
          _pendientesLista = (decoded['datos'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] pendientes lista: $e');
    } finally {
      if (mounted) {
        setState(() {
          _pendientesLoading = false;
          _pendientesLoaded = true;
        });
      }
    }
  }

  Future<void> _fetchAsesores() async {
    try {
      final r = await _api.cachedPost('/ajax/get_asesores.php', {},
          ttl: const Duration(hours: 1));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && decoded.isNotEmpty) {
          _asesoresLista = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] asesores: $e');
    }
  }

  // ── User helpers ────────────────────────────────────────────────
  String get _fullName {
    final u = _api.user;
    if (u == null) return 'Usuario';
    // Buscar en el objeto perfil primero (tbl_asesores, tbl_deudores, etc.)
    final p = u['perfil'];
    final perfil =
        p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
    for (final src in [perfil, u]) {
      final nombres = (src['nombres'] ?? src['nombre'] ?? '').toString().trim();
      final apellidos =
          (src['apellidos'] ?? src['apellido'] ?? '').toString().trim();
      if (nombres.isNotEmpty && apellidos.isNotEmpty) {
        return '$nombres $apellidos';
      }
      for (final k in [
        'nombre_completo',
        'fullname',
        'name',
        'nombres',
        'nombre'
      ]) {
        final v = (src[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
    }
    final email = (u['usuario'] ?? u['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    if (email.isNotEmpty) return email;
    return 'Usuario';
  }

  String get _photoUrl {
    final u = _api.user;
    if (u == null) return '';
    final p = u['perfil'];
    final perfil =
        p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
    for (final src in [perfil, u]) {
      for (final k in [
        'foto',
        'imagen',
        'avatar',
        'photo',
        'fotografia',
        'foto_perfil',
        'imagen_perfil',
        'picture',
        'img'
      ]) {
        final raw = (src[k] ?? '').toString().trim();
        if (raw.isNotEmpty && raw != 'null') {
          if (raw.startsWith('http')) return raw;
          return 'https://www.jorgemario.co/ext/saf/img/icons/$raw';
        }
      }
    }
    return '';
  }

  // ── Actions ─────────────────────────────────────────────────────
  void _logout() async {
    await _api.logout();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  void _showProfileSheet() {
    final u = _api.user;
    final email = (u?['email'] ?? u?['correo'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _profileSheet(email),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsuariosAdmin(
      {bool forceRefresh = false}) async {
    if (forceRefresh) _api.invalidateCache('/ajax/gestion_usuarios.php');
    final response = await _api.cachedPost(
        '/ajax/gestion_usuarios.php',
        {
          'accion': 'listar',
        },
        ttl: const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw Exception('El servidor no respondió correctamente');
    }
    final decoded = _json(response.body);
    if (decoded.isEmpty) {
      final raw = response.body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      throw Exception(
        raw.isEmpty ? 'El servidor devolvió una respuesta vacía' : raw,
      );
    }
    if (decoded['success'] != true && decoded['resultado'] != 1) {
      throw Exception(
          decoded['mensaje']?.toString() ?? 'No se pudieron cargar usuarios');
    }
    final raw = decoded['datos'];
    if (raw is! List) {
      throw Exception('No fue posible leer el listado de usuarios');
    }
    final lista = raw.whereType<Map>().map((e) {
      // Normaliza claves: minúsculas + guión bajo en lugar de espacios
      // El SQL en tbl_conf_consultas usa aliases como "Tipo Usuario" con mayúsculas y espacios
      final m = <String, dynamic>{};
      for (final entry in e.entries) {
        final k = entry.key.toString().toLowerCase().replaceAll(' ', '_');
        m[k] = entry.value;
      }
      return m;
    }).toList();
    return lista;
  }

  void _showUsersManagement() {
    List<Map<String, dynamic>> usuarios = [];
    bool loading = true;
    bool started = false;
    String error = '';
    String query = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (!started) {
            started = true;
            _fetchUsuariosAdmin().then<void>((data) {
              if (ctx.mounted) {
                setS(() {
                  usuarios = data;
                  loading = false;
                });
              }
            }).catchError((Object e) {
              if (ctx.mounted) {
                setS(() {
                  error = e.toString().replaceFirst('Exception: ', '');
                  loading = false;
                });
              }
            });
          }

          final filtrados = usuarios.where((user) {
            if (query.isEmpty) return true;
            final text = user.values.join(' ').toLowerCase();
            return text.contains(query.toLowerCase());
          }).toList();

          return Dialog.fullscreen(
            backgroundColor: const Color(0xFFF5F7FC),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 12, 12),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.manage_accounts_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gestión de usuarios',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Administración · Acceso restringido',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final saved = await _showUserForm();
                                if (saved && ctx.mounted) {
                                  setS(() {
                                    loading = true;
                                    error = '';
                                  });
                                  try {
                                    final data = await _fetchUsuariosAdmin(
                                        forceRefresh: true);
                                    if (ctx.mounted) {
                                      setS(() {
                                        usuarios = data;
                                        loading = false;
                                      });
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setS(() {
                                        error = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                        loading = false;
                                      });
                                    }
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_add_alt_1_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Nuevo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      onChanged: (value) => setS(() => query = value.trim()),
                      style: const TextStyle(color: _navy, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario, perfil o estado',
                        hintStyle: const TextStyle(color: Color(0xFFB0BBCC)),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF8899BB)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: _accent1, width: 1.5),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _accent1),
                          )
                        : error.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.cloud_off_rounded,
                                        size: 44,
                                        color: Color(0xFF8899BB),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        error,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : filtrados.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No se encontraron usuarios',
                                      style:
                                          TextStyle(color: Color(0xFF8899BB)),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 24),
                                    itemCount: filtrados.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, index) => _adminUserCard(
                                      filtrados[index],
                                      () async {
                                        final saved = await _showUserForm(
                                            filtrados[index]);
                                        if (saved && ctx.mounted) {
                                          setS(() {
                                            loading = true;
                                            error = '';
                                          });
                                          try {
                                            final data =
                                                await _fetchUsuariosAdmin(
                                                    forceRefresh: true);
                                            if (ctx.mounted) {
                                              setS(() {
                                                usuarios = data;
                                                loading = false;
                                              });
                                            }
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              setS(() {
                                                error = e
                                                    .toString()
                                                    .replaceFirst(
                                                        'Exception: ', '');
                                                loading = false;
                                              });
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _usuariosRequest(
      Map<String, dynamic> body) async {
    final response = await _api.post('/ajax/gestion_usuarios.php', body);
    if (response.statusCode != 200) {
      throw Exception('El servidor no respondió correctamente');
    }
    final decoded = _json(response.body);
    if (decoded.isEmpty) {
      final raw = response.body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      throw Exception(
        raw.isEmpty ? 'El servidor devolvió una respuesta vacía' : raw,
      );
    }
    if (decoded['success'] != true && decoded['resultado'] != 1) {
      throw Exception(
          decoded['mensaje']?.toString() ?? 'Operación no completada');
    }
    return decoded;
  }

  Future<bool> _showUserForm([Map<String, dynamic>? listadoUser]) async {
    final codigoUsuario = (listadoUser?['codigo_usuario'] ??
            listadoUser?['codigo'] ??
            listadoUser?['cod'] ??
            '')
        .toString();
    final editing = codigoUsuario.isNotEmpty;
    if (!mounted) return false;

    // Estado mutable dentro del StatefulBuilder
    bool loadingData = true;
    String loadError = '';
    List<Map<String, dynamic>> perfiles = [];
    List<Map<String, dynamic>> tipos = [];
    final emailCtrl = TextEditingController();
    String perfil = '';
    String tipo = '';
    String origen = '';
    List<Map<String, dynamic>> origenes = [];
    bool loadingOrigenes = false;
    bool saving = false;
    bool initStarted = false;

    Future<List<Map<String, dynamic>>> loadOrigins(
        String tipoCodigo, StateSetter setS) async {
      if (tipoCodigo.isEmpty) return [];
      final response = await _usuariosRequest({
        'accion': 'origenes',
        'codigo_tipo_usuario': tipoCodigo,
      });
      final raw = response['datos'];
      return raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Inicializar datos la primera vez que se renderiza
          if (!initStarted) {
            initStarted = true;
            Future.microtask(() async {
              try {
                final cats = await _usuariosRequest({'accion': 'catalogos'});
                final data = cats['datos'] is Map
                    ? Map<String, dynamic>.from(cats['datos'] as Map)
                    : <String, dynamic>{};
                final loadedPerfiles =
                    (data['perfiles'] is List ? data['perfiles'] as List : [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                final loadedTipos =
                    (data['tipos'] is List ? data['tipos'] as List : [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                Map<String, dynamic> detail = {};
                if (editing) {
                  final resp = await _usuariosRequest({
                    'accion': 'detalle',
                    'codigo_usuario': codigoUsuario,
                  });
                  if (resp['datos'] is Map) {
                    detail = Map<String, dynamic>.from(resp['datos'] as Map);
                  }
                }

                final initEmail = (detail['usuario'] ??
                        listadoUser?['usuario'] ??
                        listadoUser?['email'] ??
                        '')
                    .toString();
                final initPerfil = (detail['codigo_perfil'] ?? '').toString();
                final initTipo =
                    (detail['codigo_tipo_usuario'] ?? '').toString();
                final initOrigen = (detail['codigo_origen'] ?? '').toString();

                List<Map<String, dynamic>> loadedOrigenes = [];
                if (initTipo.isNotEmpty) {
                  try {
                    loadedOrigenes = await loadOrigins(initTipo, setS);
                  } catch (_) {}
                }

                if (ctx.mounted) {
                  setS(() {
                    perfiles = loadedPerfiles;
                    tipos = loadedTipos;
                    emailCtrl.text = initEmail;
                    perfil = initPerfil;
                    tipo = initTipo;
                    origen = initOrigen;
                    origenes = loadedOrigenes;
                    loadingData = false;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setS(() {
                    loadError = e.toString().replaceFirst('Exception: ', '');
                    loadingData = false;
                  });
                }
              }
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0D1B4B),
                    Color(0xFF1E40AF),
                    Color(0xFF0EA5E9)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      editing
                          ? Icons.manage_accounts_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editing ? 'Editar usuario' : 'Crear usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          editing
                              ? 'Modifica los datos del usuario'
                              : 'Registra un nuevo acceso',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            content: loadingData
                ? const SizedBox(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _accent1),
                          SizedBox(height: 16),
                          Text('Cargando datos...',
                              style: TextStyle(
                                  color: Color(0xFF8899BB), fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : loadError.isNotEmpty
                    ? SizedBox(
                        height: 100,
                        child: Center(
                          child: Text(loadError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFDC2626))),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SizedBox(
                          width: 440,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              TextField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: _navy),
                                decoration: _userInputDecoration(
                                  'Email usuario',
                                  Icons.alternate_email_rounded,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: perfil.isEmpty ? null : perfil,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                style:
                                    const TextStyle(color: _navy, fontSize: 14),
                                decoration: _userInputDecoration(
                                  'Perfil',
                                  Icons.admin_panel_settings_outlined,
                                ),
                                items: perfiles
                                    .map((item) => DropdownMenuItem(
                                          value:
                                              (item['codigo'] ?? '').toString(),
                                          child: Text(
                                            (item['nombre'] ?? '').toString(),
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(color: _navy),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (value) =>
                                        setS(() => perfil = value ?? ''),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: tipo.isEmpty ? null : tipo,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                style:
                                    const TextStyle(color: _navy, fontSize: 14),
                                decoration: _userInputDecoration(
                                  'Tipo de usuario',
                                  Icons.badge_outlined,
                                ),
                                items: tipos
                                    .map((item) => DropdownMenuItem(
                                          value:
                                              (item['codigo'] ?? '').toString(),
                                          child: Text(
                                            (item['nombre'] ?? '').toString(),
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(color: _navy),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (value) async {
                                        final selected = value ?? '';
                                        setS(() {
                                          tipo = selected;
                                          origen = '';
                                          origenes = [];
                                          loadingOrigenes = selected.isNotEmpty;
                                        });
                                        if (selected.isEmpty) return;
                                        try {
                                          final result =
                                              await loadOrigins(selected, setS);
                                          if (ctx.mounted) {
                                            setS(() {
                                              origenes = result;
                                              loadingOrigenes = false;
                                            });
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            setS(() => loadingOrigenes = false);
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(e
                                                    .toString()
                                                    .replaceFirst(
                                                        'Exception: ', '')),
                                                backgroundColor:
                                                    const Color(0xFFDC2626),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              ),
                              const SizedBox(height: 12),
                              // Usuario asociado — searchable picker
                              GestureDetector(
                                onTap: (saving ||
                                        loadingOrigenes ||
                                        origenes.isEmpty)
                                    ? null
                                    : () async {
                                        final searchCtrl =
                                            TextEditingController();
                                        List<Map<String, dynamic>> filtered =
                                            List.from(origenes);
                                        final picked = await showDialog<
                                            Map<String, dynamic>>(
                                          context: ctx,
                                          builder: (dCtx) => StatefulBuilder(
                                              builder: (dCtx, setSrch) {
                                            return Dialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              insetPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 60),
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          16, 16, 16, 12),
                                                      decoration:
                                                          const BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                                colors: [
                                                              Color(0xFF0D1B4B),
                                                              Color(0xFF1E40AF),
                                                              Color(0xFF0EA5E9)
                                                            ]),
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                                top: Radius
                                                                    .circular(
                                                                        16)),
                                                      ),
                                                      child: Row(children: [
                                                        const Icon(
                                                            Icons
                                                                .person_search_rounded,
                                                            color: Colors.white,
                                                            size: 20),
                                                        const SizedBox(
                                                            width: 10),
                                                        const Expanded(
                                                            child: Text(
                                                                'Seleccionar Usuario',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        15))),
                                                        GestureDetector(
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                    dCtx),
                                                            child: const Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                color: Colors
                                                                    .white70,
                                                                size: 20)),
                                                      ]),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          12, 12, 12, 4),
                                                      child: TextField(
                                                        controller: searchCtrl,
                                                        autofocus: true,
                                                        decoration:
                                                            InputDecoration(
                                                          hintText:
                                                              'Buscar usuario...',
                                                          prefixIcon: const Icon(
                                                              Icons
                                                                  .search_rounded,
                                                              size: 18,
                                                              color: Color(
                                                                  0xFF6B7280)),
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 10),
                                                          border: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFFD1D5DB))),
                                                          enabledBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFFD1D5DB))),
                                                          focusedBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFF4361EE))),
                                                        ),
                                                        onChanged: (q) =>
                                                            setSrch(() {
                                                          filtered = origenes
                                                              .where((item) => (item[
                                                                          'nombre'] ??
                                                                      '')
                                                                  .toString()
                                                                  .toLowerCase()
                                                                  .contains(q
                                                                      .toLowerCase()))
                                                              .toList();
                                                        }),
                                                      ),
                                                    ),
                                                    Flexible(
                                                      child: ListView.builder(
                                                        shrinkWrap: true,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 4),
                                                        itemCount:
                                                            filtered.length,
                                                        itemBuilder: (_, i) {
                                                          final item =
                                                              filtered[i];
                                                          final nom =
                                                              (item['nombre'] ??
                                                                      '')
                                                                  .toString();
                                                          final cod =
                                                              (item['codigo'] ??
                                                                      '')
                                                                  .toString();
                                                          final isSelected =
                                                              cod == origen;
                                                          return InkWell(
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                    dCtx, item),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          16,
                                                                      vertical:
                                                                          12),
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFFEEF2FF)
                                                                  : null,
                                                              child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                        child: Text(
                                                                            nom,
                                                                            style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: isSelected ? const Color(0xFF4361EE) : const Color(0xFF374151),
                                                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400))),
                                                                    if (isSelected)
                                                                      const Icon(
                                                                          Icons
                                                                              .check_rounded,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              Color(0xFF4361EE)),
                                                                  ]),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                  ]),
                                            );
                                          }),
                                        );
                                        if (picked != null) {
                                          setS(() {
                                            origen = (picked['codigo'] ?? '')
                                                .toString();
                                          });
                                        }
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFFD1D5DB)),
                                    borderRadius: BorderRadius.circular(10),
                                    color: (saving || loadingOrigenes)
                                        ? const Color(0xFFF9FAFB)
                                        : Colors.white,
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.person_search_outlined,
                                        size: 18,
                                        color: origen.isNotEmpty
                                            ? const Color(0xFF4361EE)
                                            : const Color(0xFF9CA3AF)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(
                                      loadingOrigenes
                                          ? 'Cargando usuarios...'
                                          : origen.isNotEmpty
                                              ? (origenes.firstWhere(
                                                          (e) =>
                                                              (e['codigo'] ??
                                                                      '')
                                                                  .toString() ==
                                                              origen,
                                                          orElse: () => {
                                                                'nombre':
                                                                    'Usuario seleccionado'
                                                              })['nombre'] ??
                                                      '')
                                                  .toString()
                                              : 'Usuario asociado',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: origen.isNotEmpty &&
                                                  !loadingOrigenes
                                              ? const Color(0xFF0D1B4B)
                                              : const Color(0xFF9CA3AF)),
                                    )),
                                    Icon(
                                        loadingOrigenes
                                            ? Icons.hourglass_empty_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: const Color(0xFF6B7280)),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            actions: loadingData || loadError.isNotEmpty
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cerrar'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8899BB)),
                      child: const Text('Cancelar'),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: saving
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: saving
                            ? null
                            : [
                                BoxShadow(
                                  color: _accent1.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                final email = emailCtrl.text.trim();
                                if (!email.contains('@') ||
                                    perfil.isEmpty ||
                                    tipo.isEmpty ||
                                    origen.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Complete todos los campos.'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }
                                setS(() => saving = true);
                                try {
                                  await _usuariosRequest({
                                    'accion': 'guardar',
                                    'codigo_usuario': codigoUsuario,
                                    'usuario': email,
                                    'codigo_perfil': perfil,
                                    'codigo_tipo_usuario': tipo,
                                    'codigo_origen': origen,
                                  });
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, true);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setS(() => saving = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(e
                                            .toString()
                                            .replaceFirst('Exception: ', '')),
                                        backgroundColor:
                                            const Color(0xFFDC2626),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(saving ? 'Guardando...' : 'Guardar'),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
    emailCtrl.dispose();
    return saved == true;
  }

  InputDecoration _userInputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _accent1, size: 20),
        filled: true,
        fillColor: const Color(0xFFF0F2FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE2F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent1, width: 1.5),
        ),
      );

  Widget _adminUserCard(Map<String, dynamic> user, VoidCallback onEdit) {
    final email = (user['usuario'] ??
            user['email'] ??
            user['correo'] ??
            'Usuario sin correo')
        .toString();
    final tipo = (user['tipo_usuario'] ?? user['tipo'] ?? 'Usuario').toString();
    final perfil =
        (user['perfil'] ?? user['nombre_perfil'] ?? 'Sin perfil').toString();
    final estadoRaw = (user['estado'] ?? user['activo'] ?? '').toString();
    final activo = estadoRaw.isEmpty ||
        estadoRaw == '1' ||
        estadoRaw.toLowerCase() == 'activo' ||
        estadoRaw.toLowerCase() == 'true';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Borde izquierdo de color
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activo
                    ? [const Color(0xFF0D1B4B), const Color(0xFF1E3A8A)]
                    : [const Color(0xFFCBD5E1), const Color(0xFFCBD5E1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: activo
                  ? const LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: activo ? null : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _userBadge(tipo, const Color(0xFF4361EE)),
                      _userBadge(perfil, const Color(0xFF4361EE)),
                      _userBadge(
                        activo ? 'Activo' : 'Inactivo',
                        activo
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Botón editar
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _accent1.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: _accent1,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 18
            ? 'Buenas tardes'
            : 'Buenas noches';
    final firstName = _fullName.split(' ').first;

    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _buildTabContent(greeting, firstName),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() => SliverAppBar(
        expandedHeight: 0,
        floating: true,
        snap: true,
        automaticallyImplyLeading: false,
        backgroundColor: _navy,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const _AnimatedSafLogo(),
            const SizedBox(width: 10),
            const Text('SAF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 1.2,
                )),
            const Spacer(),
            GestureDetector(
              onTap: _showProfileSheet,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _accent2.withValues(alpha: 0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: _accent1.withValues(alpha: 0.35), blurRadius: 8)
                  ],
                ),
                child: ClipOval(
                  child: _photoUrl.isNotEmpty
                      ? Image.network(_photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _avatarFallback(_fullName.split(' ').first))
                      : _avatarFallback(_fullName.split(' ').first),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );

  // ── Tab router ───────────────────────────────────────────────────
  Widget _buildTabContent(String greeting, String firstName) {
    switch (_selectedIndex) {
      case 0:
        return _dashboardTab(greeting, firstName);
      case 1:
        return _creditosTab();
      case 2:
        return _ahorradoresTab();
      case 3:
        return _movimientosTab();
      case 4:
        return _estadisticaTab();
      default:
        return const SizedBox();
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  DASHBOARD TAB
  // ══════════════════════════════════════════════════════════════
  Widget _dashboardTab(String greeting, String firstName) {
    if (_loadingData || !_srvTotalesLoaded) return _dashboardSkeleton();

    final ingresos = _totalIngresos;
    final egresos = _totalEgresos;
    final balance = ingresos - egresos;
    final recent = _movimientos.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Balance card ──────────────────────────────────────
        _buildBalanceCard(greeting, firstName),
        const SizedBox(height: 22),

        // ── Summary ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardSectionHeader(
                icon: Icons.insights_rounded,
                title: 'Resumen del mes',
                subtitle: 'Indicadores financieros consolidados',
                gradient: const [Color(0xFF10B981), Color(0xFF059669)],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _summaryCard(
                            icon: Icons.trending_up_rounded,
                            label: 'Total ingresos',
                            value: _cop(ingresos),
                            color: const Color(0xFF059669),
                            bgColor: const Color(0xFF6EE7B7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            icon: Icons.trending_down_rounded,
                            label: 'Total gastos',
                            value: _cop(egresos),
                            color: const Color(0xFFDC2626),
                            bgColor: const Color(0xFFFCA5A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _summaryCard(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Balance neto',
                            value: _cop(balance),
                            color: _accent1,
                            bgColor: const Color(0xFF93C5FD),
                            badge: '${_cuentas.length} cuentas',
                            valueColor: balance < 0
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF6EE7B7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            icon: Icons.groups_rounded,
                            label: 'Ahorradores',
                            value: _ahorradores.length.toString(),
                            color: const Color(0xFF7C3AED),
                            bgColor: const Color(0xFFDDD6FE),
                            badge: 'activos',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Cuentas horizontal list ───────────────────────────
        if (_cuentas.isNotEmpty) ...[
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _dashboardSectionHeader(
              icon: Icons.account_balance_rounded,
              title: 'Mis cuentas',
              subtitle: '${_cuentas.length} fuentes registradas',
              action: 'Ver todas',
              onAction: () => setState(() => _selectedIndex = 3),
              gradient: const [Color(0xFF4361EE), Color(0xFF00D2FF)],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _cuentas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _cuentaChip(_cuentas[i], index: i),
            ),
          ),
        ],

        // ── Recent activity ───────────────────────────────────
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardSectionHeader(
                icon: Icons.receipt_long_rounded,
                title: 'Actividad reciente',
                subtitle: '${recent.length} movimientos más recientes',
                action: 'Ver todos',
                onAction: () => setState(() => _selectedIndex = 3),
                gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              const SizedBox(height: 14),
              if (_loadingData)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: _accent1),
                ))
              else if (recent.isEmpty)
                _emptyActivity()
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFF4F7FF),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFDDE3F0)),
                    boxShadow: [
                      BoxShadow(
                        color: _accent1.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: recent
                        .asMap()
                        .entries
                        .map((e) => _movimientoItemReal(e.value,
                            divider: e.key < recent.length - 1))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  CRÉDITOS TAB
  // ══════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════
  //  CRÉDITOS TAB — Gestión de Créditos
  // ══════════════════════════════════════════════════════════════
  Widget _creditosTab() {
    if (_loadingData) return _loadingView();

    // Totales globales (todos los registros del filtro, no solo la página actual)
    final totalPagado = _creditosTotalPagado;
    final totalPendiente = _creditosTotalPendiente;

    final creditosFiltrados = _creditosLista;

    // ── Cálculo del simulador (igual que web: tasa mensual simple) ──
    final meses = _simMeses.round();
    // Interés mensual = monto × tasa% (tasa es mensual)
    final interesMensual = _simMonto * (_simTasa / 100);
    // Amortización mensual = monto / meses
    final amortizacionMensual = meses > 0 ? _simMonto / meses : 0.0;
    // Cuota mensual = amortización + interés
    final cuotaMensual = amortizacionMensual + interesMensual;
    final cuotaQuincenal = cuotaMensual / 2;
    // Valor total a pagar
    final valorAPagar = cuotaMensual * meses;
    // Valor diario = interés mensual / 30
    final valorDiario = interesMensual / 30;
    // Si hay fechas, calcular intereses por días exactos
    final dias = (_simDesde != null && _simHasta != null)
        ? _simHasta!.difference(_simDesde!).inDays.clamp(0, 100000)
        : 0;
    final valorTotalDiario = dias > 0 ? _simMonto + (valorDiario * dias) : 0.0;
    final cuotaReal = cuotaMensual;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header ──────────────────────────────────────────────
      Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF3B3B8A), Color(0xFF5252B4)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Icon(Icons.credit_card_rounded,
                      color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text('Gestión de Créditos',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ]),
                SizedBox(height: 6),
                Text(
                    'Administra solicitudes, créditos aprobados y simulaciones',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Sistema de Créditos',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
            SizedBox(height: 2),
            Text('SAF',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ]),
        ]),
      ),

      // ── Sub-tabs scrollables ────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _creditoTabBtn(
                  0, 'Aprobados', Icons.check_circle_outline_rounded),
              _creditoTabBtn(1, 'Pendientes', Icons.schedule_rounded),
              _creditoTabBtn(2, 'Simular crédito', Icons.calculate_outlined),
              _creditoTabBtn(
                  3, 'Estadística por fuente', Icons.bar_chart_rounded),
            ]),
          ),
        ),
      ),

      // ── Contenido por sub-tab ───────────────────────────────
      if (_creditoSubTab == 0 || _creditoSubTab == 1) ...[
        // ── Botones acción (solo en Aprobados) ───────────────────
        if (_creditoSubTab == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              Expanded(
                  child: _actionBtn(
                      label: 'Agregar Deudor',
                      color: const Color(0xFF4338CA),
                      icon: Icons.person_add_rounded,
                      onTap: _showCrearDeudorDialog)),
              const SizedBox(width: 10),
              Expanded(
                  child: _actionBtn(
                      label: 'Agregar Crédito',
                      color: const Color(0xFF0D9488),
                      icon: Icons.add_card_rounded,
                      onTap: _showCrearCreditoDialog)),
            ]),
          ),

        // ── Stats card ──────────────────────────────────────────
        if (_creditoSubTab == 0)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Color(0xFF1E1B6A),
                Color(0xFF3B3B8A),
                Color(0xFF5252B4)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF3B3B8A).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Stack(children: [
              // Decoración fondo
              Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  )),
              Positioned(
                  right: 30,
                  bottom: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  )),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Row(children: [
                  // Pagado
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.white70,
                                size: 14),
                          ),
                          const SizedBox(width: 6),
                          const Text('TOTAL PAGADO',
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ]),
                        const SizedBox(height: 8),
                        Text(_cop(totalPagado),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ])),
                  Container(
                      width: 1,
                      height: 44,
                      color: Colors.white.withValues(alpha: 0.15)),
                  // Pendiente
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.schedule_rounded,
                                  color: Colors.white70, size: 14),
                            ),
                            const SizedBox(width: 6),
                            const Text('TOTAL PENDIENTE',
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ]),
                          const SizedBox(height: 8),
                          Text(_cop(totalPendiente),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                        ]),
                  )),
                ]),
              ),
            ]),
          ),

        // ── Filtros (solo en Aprobados) ─────────────────────────
        if (_creditoSubTab == 0)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Filtrar resultados',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8899BB),
                      letterSpacing: 0.3)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Asesor',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _navy)),
                      const SizedBox(height: 4),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _creditoFiltroAsesor.isEmpty
                                ? null
                                : _creditoFiltroAsesor,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            hint: const Text('Todos',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF8899BB))),
                            style: const TextStyle(fontSize: 12, color: _navy),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: Color(0xFF8899BB)),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos',
                                      style: TextStyle(color: _navy))),
                              ..._asesoresLista.map((a) {
                                final sigla = (a['sigla'] ??
                                        a['codigo_asesor'] ??
                                        a['codigo'] ??
                                        '')
                                    .toString();
                                final nombre = ([a['nombres'], a['apellidos']]
                                        .where((x) =>
                                            x != null &&
                                            x.toString().isNotEmpty)
                                        .join(' '))
                                    .trim();
                                final display =
                                    nombre.isNotEmpty ? nombre : sigla;
                                return DropdownMenuItem(
                                    value: sigla,
                                    child: Text(display,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: _navy)));
                              }),
                            ],
                            onChanged: (v) =>
                                setState(() => _creditoFiltroAsesor = v ?? ''),
                          ),
                        ),
                      ),
                    ])),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Estado',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _navy)),
                      const SizedBox(height: 4),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _creditoFiltroEstado.isEmpty
                                ? null
                                : _creditoFiltroEstado,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            hint: const Text('Todos',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF8899BB))),
                            style: const TextStyle(fontSize: 12, color: _navy),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: Color(0xFF8899BB)),
                            items: const [
                              DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos',
                                      style: TextStyle(color: _navy))),
                              DropdownMenuItem(
                                  value: '1',
                                  child: Text('Activo',
                                      style: TextStyle(color: _navy))),
                              DropdownMenuItem(
                                  value: '2',
                                  child: Text('Pagado',
                                      style: TextStyle(color: _navy))),
                            ],
                            onChanged: (v) =>
                                setState(() => _creditoFiltroEstado = v ?? ''),
                          ),
                        ),
                      ),
                    ])),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _creditoConsultando
                    ? null
                    : () async {
                        setState(() => _creditoConsultando = true);
                        try {
                          if (_creditoSubTab == 0) {
                            setState(() => _creditoPagina = 1);
                            await _fetchCreditos('');
                          } else {
                            setState(() => _pendientesPagina = 1);
                            await _fetchPendientes();
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _creditoConsultando = false);
                          }
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: _creditoConsultando
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF4338CA), Color(0xFF2D2A9E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    color: _creditoConsultando ? const Color(0xFFE2E8F0) : null,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _creditoConsultando
                        ? null
                        : [
                            BoxShadow(
                                color: const Color(0xFF4338CA)
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                  ),
                  child: Center(
                    child: _creditoConsultando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4338CA))))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.search_rounded,
                                color: Colors.white, size: 15),
                            SizedBox(width: 7),
                            Text('Consultar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3)),
                          ]),
                  ),
                ),
              ),
            ]),
          ),
        // ── Lista Aprobados ──
        if (_creditoSubTab == 0) ...[
          if (creditosFiltrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _emptyActivity(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                  children:
                      creditosFiltrados.map((c) => _creditoCard(c)).toList()),
            ),
          if (_creditosTotal > _creditosPorPagina)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                _pgBtn(Icons.chevron_left_rounded, _creditoPagina > 1,
                    () async {
                  setState(() => _creditoPagina--);
                  await _fetchCreditos('');
                  if (mounted) setState(() {});
                }),
                const SizedBox(width: 8),
                Expanded(
                    child: Center(
                        child: Text(
                  'Pág $_creditoPagina de ${((_creditosTotal - 1) ~/ _creditosPorPagina) + 1}  ·  $_creditosTotal registros',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF8899BB)),
                ))),
                const SizedBox(width: 8),
                _pgBtn(Icons.chevron_right_rounded,
                    _creditoPagina * _creditosPorPagina < _creditosTotal,
                    () async {
                  setState(() => _creditoPagina++);
                  await _fetchCreditos('');
                  if (mounted) setState(() {});
                }),
              ]),
            ),
        ],
        // ── Lista Pendientes ──
        if (_creditoSubTab == 1) ...[
          if (_pendientesLoading || !_pendientesLoaded)
            _pendientesSkeleton()
          else if (_pendientesLista.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _emptyActivity(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                  children:
                      _pendientesLista.map((p) => _pendienteCard(p)).toList()),
            ),
          if (_pendientesTotal > _creditosPorPagina)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                _pgBtn(Icons.chevron_left_rounded, _pendientesPagina > 1,
                    () async {
                  setState(() => _pendientesPagina--);
                  await _fetchPendientes();
                  if (mounted) setState(() {});
                }),
                const SizedBox(width: 8),
                Expanded(
                    child: Center(
                        child: Text(
                  'Pág $_pendientesPagina de ${((_pendientesTotal - 1) ~/ _creditosPorPagina) + 1}  ·  $_pendientesTotal solicitudes',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF8899BB)),
                ))),
                const SizedBox(width: 8),
                _pgBtn(Icons.chevron_right_rounded,
                    _pendientesPagina * _creditosPorPagina < _pendientesTotal,
                    () async {
                  setState(() => _pendientesPagina++);
                  await _fetchPendientes();
                  if (mounted) setState(() {});
                }),
              ]),
            ),
        ],
      ] else if (_creditoSubTab == 2) ...[
        // ── SIMULAR CRÉDITO ──────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _simLabel('Tiempo en Meses: ${_simMeses.round()}'),
            Slider(
              value: _simMeses,
              min: 1,
              max: 24,
              divisions: 23,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => setState(() => _simMeses = v),
            ),
            const SizedBox(height: 8),
            _simLabel('Monto solicitado: ${_cop(_simMonto)}'),
            Slider(
              value: _simMonto,
              min: 100000,
              max: 3000000,
              divisions: 29,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => setState(() => _simMonto = v),
            ),
            const SizedBox(height: 8),
            _simLabel('Tasa interés: ${_simTasa.round()}'),
            Slider(
              value: _simTasa,
              min: 5,
              max: 20,
              divisions: 15,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => setState(() => _simTasa = v),
            ),
            const SizedBox(height: 16),

            // ── Fecha Desde / Hasta ──────────────────────────
            Row(children: [
              Expanded(
                child: _simDateField('Fecha Desde', _simDesde, (d) {
                  setState(() => _simDesde = d);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _simDateField('Fecha Hasta', _simHasta, (d) {
                  setState(() => _simHasta = d);
                }),
              ),
            ]),
            if (_simDesde != null && _simHasta != null) ...[
              const SizedBox(height: 8),
              Text('Días del período: $dias',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
            ],

            const SizedBox(height: 20),

            // ── Resultado principal: Cuota mensual ───────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B3B8A), Color(0xFF5252B4)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calculate_rounded,
                    color: Colors.white70, size: 24),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Cuota mensual estimada',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(_cop(cuotaReal),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ]),
              ]),
            ),

            const SizedBox(height: 14),

            // ── Desglose completo ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(children: [
                _simResultRow('Valor Diaria', _cop(valorDiario)),
                if (dias > 0)
                  _simResultRow('Valor total con intereses diarios',
                      _cop(valorTotalDiario)),
                _simResultRow(
                    '$meses Cuota(s) Mensual(es)', _cop(cuotaMensual)),
                _simResultRow('${meses * 2} Cuota(s) Quincenal(es)',
                    _cop(cuotaQuincenal)),
                _simResultRow('Valor a Pagar', _cop(valorAPagar),
                    destacado: true),
              ]),
            ),
          ]),
        ),
      ] else ...[
        // ── ESTADÍSTICA POR FUENTE ───────────────────────────
        _estadisticaCreditosWidget(),
      ],
    ]);
  }

  // ── Estadística por Fuente — filtros + barras horizontales ──────
  Widget _estadisticaCreditosWidget() {
    String labelOf(Map<String, dynamic> d) => (d['fuente'] ?? '?').toString();
    double salidasOf(Map<String, dynamic> d) => _num(d['total_salidas']);
    double entradasOf(Map<String, dynamic> d) => _num(d['total_entradas']);

    String fmtDate(DateTime? d) => d == null
        ? 'dd/mm/aaaa'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    // Fuentes = cuentas registradas (igual que la web)
    final fuenteItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '0', child: Text('Todas las fuentes')),
      ..._cuentas.map((c) {
        final label  = (c['nombre'] ?? '').toString();
        final codigo = (c['codigo'] ?? '0').toString();
        return DropdownMenuItem(
            value: codigo, child: Text(label, overflow: TextOverflow.ellipsis));
      }),
    ];

    Future<void> pickDate(bool isDesde) async {
      final picked = await showDatePicker(
        context: context,
        initialDate:
            (isDesde ? _statFechaDesde : _statFechaHasta) ?? DateTime.now(),
        firstDate: DateTime(2015),
        lastDate: DateTime(2035),
      );
      if (picked != null && mounted) {
        setState(() {
          if (isDesde) {
            _statFechaDesde = picked;
          } else {
            _statFechaHasta = picked;
          }
        });
      }
    }

    // helpers de estilo local
    const borderCol = Color(0xFFE2E8F0);
    const bgField   = Color(0xFFF8F9FC);
    const hintCol   = Color(0xFF94A3B8);

    InputDecoration fieldDeco(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: hintCol),
      prefixIcon: Icon(icon, size: 16, color: hintCol),
      filled: true, fillColor: bgField,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderCol)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderCol)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _navy, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

    Widget datePicker(String label, DateTime? val, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bgField,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderCol),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 15, color: hintCol),
            const SizedBox(width: 8),
            Expanded(child: Text(fmtDate(val),
                style: TextStyle(fontSize: 13,
                    color: val == null ? hintCol : _navy))),
            if (val != null)
              GestureDetector(
                onTap: () => setState(() {
                  if (label.contains('desde')) { _statFechaDesde = null; }
                  else { _statFechaHasta = null; }
                }),
                child: const Icon(Icons.close, size: 14, color: hintCol)),
          ]),
        ),
      );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0D1B4B), Color(0xFF1A3170)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Balance por Fuente',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Créditos otorgados vs cuotas recibidas',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Card de filtros ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Estado
            DropdownButtonFormField<String>(
              initialValue: _statEstado.isEmpty ? '' : _statEstado,
              decoration: fieldDeco('Estado', Icons.filter_list_rounded),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: hintCol),
              style: const TextStyle(fontSize: 13, color: _navy),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(value: '1', child: Text('Activos')),
                DropdownMenuItem(value: '2', child: Text('Pagados')),
                DropdownMenuItem(value: '3', child: Text('Pendientes')),
              ],
              onChanged: (v) {
                setState(() => _statEstado = v ?? '');
                _aplicarFiltrosEstadistica();
              },
            ),
            const SizedBox(height: 10),

            // Fechas
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Desde', style: TextStyle(fontSize: 11, color: hintCol, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                datePicker('desde', _statFechaDesde, () => pickDate(true)),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Hasta', style: TextStyle(fontSize: 11, color: hintCol, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                datePicker('hasta', _statFechaHasta, () => pickDate(false)),
              ])),
            ]),
            const SizedBox(height: 10),

            // Fuente
            DropdownButtonFormField<String>(
              initialValue: _statFuente,
              decoration: fieldDeco('Fuente', Icons.account_balance_outlined),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: hintCol),
              style: const TextStyle(fontSize: 13, color: _navy),
              items: fuenteItems,
              onChanged: (v) {
                setState(() => _statFuente = v ?? '0');
                _aplicarFiltrosEstadistica();
              },
            ),
            const SizedBox(height: 14),

            // Botón
            GestureDetector(
              onTap: _statLoading ? null : _aplicarFiltrosEstadistica,
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1A3170)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: _navy.withValues(alpha: 0.35),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Center(child: _statLoading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.bar_chart_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Mostrar Gráficos',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ])),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Gráficas ───────────────────────────────────────────
        if (_creditos.isEmpty)
          _emptyActivity()
        else ...[
          _barChartSection(
            title: 'Salidas por fuente (Créditos otorgados)',
            barColor: const Color(0xFF3B3B8A),
            data: _creditos,
            labelFn: labelOf,
            valueFn: salidasOf,
            total: _creditos.fold(0.0, (s, d) => s + salidasOf(d)),
            totalLabel: 'Total salidas',
          ),
          const SizedBox(height: 20),
          _barChartSection(
            title: 'Entradas por fuente (Cuotas pagadas)',
            barColor: const Color(0xFF16A34A),
            data: _creditos,
            labelFn: labelOf,
            valueFn: entradasOf,
            total: _creditos.fold(0.0, (s, d) => s + entradasOf(d)),
            totalLabel: 'Total entradas',
          ),
        ],
      ]),
    );
  }

  Widget _barChartSection({
    required String title,
    required Color barColor,
    required List<Map<String, dynamic>> data,
    required String Function(Map<String, dynamic>) labelFn,
    required double Function(Map<String, dynamic>) valueFn,
    required double total,
    required String totalLabel,
  }) {
    final sorted = [...data]..sort((a, b) => valueFn(b).compareTo(valueFn(a)));
    final maxVal = sorted.isEmpty
        ? 1.0
        : (valueFn(sorted.first) == 0 ? 1.0 : valueFn(sorted.first));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Leyenda
        Row(children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: barColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _navy))),
        ]),
        const SizedBox(height: 12),
        // Barras horizontales con color por fuente
        ...sorted.map((d) {
          final val = valueFn(d);
          final pct = val / maxVal;
          final name = labelFn(d);
          final rowColor = _hexColor(
              d['color']?.toString() ?? barColor.toARGB32().toRadixString(16));
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(
                width: 90,
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8899BB))),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 18, color: const Color(0xFFF0F2FA)),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: rowColor,
                            borderRadius: BorderRadius.circular(4),
                          )),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 82,
                child: Text(_cop(val),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
              ),
            ]),
          );
        }),
        const Divider(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$totalLabel:',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
          Text(_cop(total),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: barColor)),
        ]),
      ]),
    );
  }

  Widget _creditoTabBtn(int index, String label, IconData icon) {
    final active = _creditoSubTab == index;
    const dur = Duration(milliseconds: 180);
    const activeColor = Colors.white;
    const inactiveColor = Color(0xFF8899BB);
    return GestureDetector(
      onTap: () {
        setState(() => _creditoSubTab = index);
        if (index == 1 && !_pendientesLoaded && !_pendientesLoading) {
          _fetchPendientes();
        }
      },
      child: Stack(children: [
        // ── Fondo (primero = detrás) ──────────────────────
        Positioned.fill(
          child: AnimatedOpacity(
            duration: dur,
            opacity: active ? 1.0 : 0.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0D1B4B), Color(0xFF1A3170)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF0D1B4B).withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
            ),
          ),
        ),
        // ── Contenido (encima) ────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: dur,
              child: Icon(icon,
                  size: 14,
                  key: ValueKey(active),
                  color: active ? activeColor : inactiveColor),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: dur,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? activeColor : inactiveColor),
              child: Text(label),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _simLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D1B4B))),
      );

  // Campo de fecha (Desde/Hasta) del simulador.
  Widget _simDateField(
      String label, DateTime? value, ValueChanged<DateTime> onPick) {
    const navy = Color(0xFF0D1B4B);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: navy)),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          final hoy = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? hoy,
            firstDate: DateTime(2015),
            lastDate: DateTime(hoy.year + 5),
          );
          if (d != null) onPick(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                value == null
                    ? 'dd/mm/aaaa'
                    : '${value.day.toString().padLeft(2, '0')}/'
                        '${value.month.toString().padLeft(2, '0')}/${value.year}',
                style: TextStyle(
                    fontSize: 13,
                    color: value == null ? const Color(0xFF94A3B8) : navy),
              ),
            ),
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: Color(0xFF8899BB)),
          ]),
        ),
      ),
    ]);
  }

  // Fila de resultado del simulador.
  Widget _simResultRow(String label, String valor, {bool destacado = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: destacado ? 14 : 13,
                      fontWeight: destacado ? FontWeight.w800 : FontWeight.w500,
                      color: destacado
                          ? const Color(0xFF0D1B4B)
                          : const Color(0xFF64748B))),
            ),
            const SizedBox(width: 12),
            Text(valor,
                style: TextStyle(
                    fontSize: destacado ? 16 : 14,
                    fontWeight: FontWeight.w800,
                    color: destacado
                        ? const Color(0xFF3B3B8A)
                        : const Color(0xFF0D1B4B))),
          ],
        ),
      );

  // ── Diálogo Configurar Ahorro ────────────────────────────────────
  Future<void> _showConfigurarAhorroDialog() async {
    final formKey = GlobalKey<FormState>();
    final anioCtrl =
        TextEditingController(text: DateTime.now().year.toString());
    final tiempoCtrl = TextEditingController();
    DateTime? fechaInicio;
    DateTime? fechaFinal;
    String? selectedTipo;
    bool saving = false;

    final tipos = ['Fijo', 'Variable'];

    String fmtDisplay(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    String fmtApi(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(480, MediaQuery.of(ctx).size.width - 40),
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Configurar Ahorro',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Text('Nuevo período de ahorro',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Campos
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Año
                          _ahorrField(
                            ctrl: anioCtrl,
                            label: 'Año',
                            icon: Icons.calendar_today_outlined,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingrese el año'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Fecha Inicio
                          _ahorrFieldLabel('Fecha Inicio'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: fechaInicio ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                builder: (c, child) => Theme(
                                  data: Theme.of(c).copyWith(
                                      colorScheme: const ColorScheme.light(
                                          primary: _navy)),
                                  child: child!,
                                ),
                              );
                              if (d != null) setS(() => fechaInicio = d);
                            },
                            child: _dateContainer(
                                fechaInicio != null
                                    ? fmtDisplay(fechaInicio!)
                                    : null,
                                'dd/mm/aaaa'),
                          ),
                          const SizedBox(height: 14),

                          // Fecha Final
                          _ahorrFieldLabel('Fecha Final'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    fechaFinal ?? fechaInicio ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                builder: (c, child) => Theme(
                                  data: Theme.of(c).copyWith(
                                      colorScheme: const ColorScheme.light(
                                          primary: _navy)),
                                  child: child!,
                                ),
                              );
                              if (d != null) setS(() => fechaFinal = d);
                            },
                            child: _dateContainer(
                                fechaFinal != null
                                    ? fmtDisplay(fechaFinal!)
                                    : null,
                                'dd/mm/aaaa'),
                          ),
                          const SizedBox(height: 14),

                          // Tiempo en Mes
                          _ahorrField(
                            ctrl: tiempoCtrl,
                            label: 'Tiempo en Mes',
                            icon: Icons.timelapse_rounded,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingrese el tiempo en meses'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Tipo
                          _ahorrFieldLabel('Tipo'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDialog<String>(
                                context: ctx,
                                builder: (dCtx) => SimpleDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('Seleccionar Tipo',
                                      style: TextStyle(
                                          color: _navy,
                                          fontWeight: FontWeight.w700)),
                                  children: tipos
                                      .map((t) => SimpleDialogOption(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, t),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      color: _navy,
                                                      fontSize: 14)),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              );
                              if (picked != null) {
                                setS(() => selectedTipo = picked);
                              }
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedTipo != null
                                      ? _accent1.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Icon(Icons.category_outlined,
                                    size: 18,
                                    color: selectedTipo != null
                                        ? _accent1
                                        : const Color(0xFF9CA3AF)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    selectedTipo ?? '[Seleccione una Opción]',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: selectedTipo != null
                                          ? _navy
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.expand_more_rounded,
                                    color: Color(0xFF9CA3AF), size: 20),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botones
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8899BB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDDE3EF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cerrar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1B4B),
                                      Color(0xFF1E3A8A)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            color: saving ? const Color(0xFFCBD5E1) : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: saving
                                ? null
                                : [
                                    BoxShadow(
                                      color: _navy.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (fechaInicio == null) {
                                      ScaffoldMessenger.of(ctx)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Seleccione la fecha inicio'),
                                        backgroundColor: Color(0xFFDC2626),
                                      ));
                                      return;
                                    }
                                    if (fechaFinal == null) {
                                      ScaffoldMessenger.of(ctx)
                                          .showSnackBar(const SnackBar(
                                        content:
                                            Text('Seleccione la fecha final'),
                                        backgroundColor: Color(0xFFDC2626),
                                      ));
                                      return;
                                    }
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    if (selectedTipo == null) {
                                      ScaffoldMessenger.of(ctx)
                                          .showSnackBar(const SnackBar(
                                        content: Text('Seleccione el tipo'),
                                        backgroundColor: Color(0xFFDC2626),
                                      ));
                                      return;
                                    }
                                    setS(() => saving = true);
                                    try {
                                      final r = await _api.post(
                                        '/ajax/registrar_conf_cuota.php',
                                        {
                                          'anio': anioCtrl.text.trim(),
                                          'fecha_inicio': fmtApi(fechaInicio!),
                                          'fecha_final': fmtApi(fechaFinal!),
                                          'tiempo_mes': tiempoCtrl.text.trim(),
                                          'tipo': selectedTipo ?? '',
                                        },
                                      );
                                      final body = r.body.trim();
                                      final ok = r.statusCode == 200 &&
                                          body.contains(
                                              'Configuración Registrada');
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => _resultDialog(
                                            ok
                                                ? 'Configuración registrada exitosamente'
                                                : body.isNotEmpty
                                                    ? body
                                                    : 'No se pudo registrar',
                                            ok,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                        ScaffoldMessenger.of(ctx)
                                            .showSnackBar(SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ));
                                      }
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(saving ? 'Guardando...' : 'Grabar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      anioCtrl.dispose();
      tiempoCtrl.dispose();
    });
  }

  Widget _dateContainer(String? value, String hint) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          border: Border.all(
            color: value != null
                ? _accent1.withValues(alpha: 0.6)
                : const Color(0xFFDDE3EF),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 18,
                color: value != null ? _accent1 : const Color(0xFF9CA3AF)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null ? _navy : const Color(0xFF6B7280),
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      );

  // ── Diálogo Crear Ahorro ─────────────────────────────────────────
  Future<void> _showCrearAhorroDialog() async {
    final formKey = GlobalKey<FormState>();
    String? selectedAhorrador;
    String ahorradorLabel = '';
    String? selectedAnioCodigo;
    DateTime? fechaIngreso;
    final valorCtrl = TextEditingController();
    bool saving = false;
    bool aniosLoaded = false;
    bool loadingAnios = false;
    List<Map<String, dynamic>> aniosOpts = [];

    // Usar _deudoresLista ya en memoria (construida desde _ahorradores)
    _tryBuildDeudoresFromLocal();
    final ahorradorOpts = List<Map<String, dynamic>>.from(_deudoresLista);

    Future<void> loadAnios(StateSetter setS) async {
      setS(() => loadingAnios = true);
      try {
        // Carga años desde tbl_ahorro_anyos
        // CHAR(124) = '|' evita comillas en SQL (compatibilidad con magic_quotes)
        final r = await _api.post('/ajax/listado_select.php', {
          'tabla': 'tbl_ahorro_anyos',
          'valor': 'codigo_ahorro_anyo',
          'etiqueta': 'concat(fecha_inicio,CHAR(124),fecha_fin)',
          'filtro': '1',
          'campos_orden': 'fecha_fin DESC',
        });
        if (r.statusCode == 200) {
          final raw = jsonDecode(r.body);
          if (raw is List) {
            aniosOpts = raw.whereType<Map>().map((e) {
              final m = Map<String, dynamic>.from(e);
              final raw2 = m.values.last.toString(); // "2025-11-05|2026-10-05"
              final parts = raw2.split('|');
              final year = parts.length == 2 && parts[1].length >= 4
                  ? parts[1].substring(0, 4)
                  : raw2;
              m['_label'] = parts.length == 2
                  ? '$year (${parts[0]} hasta ${parts[1]})'
                  : raw2;
              return m;
            }).toList();
          }
        }
      } catch (e, st) {
        debugPrint('[SAF] loadAnios ERROR: $e\n$st');
      }
      setS(() {
        loadingAnios = false;
        aniosLoaded = true;
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (!aniosLoaded && !loadingAnios) loadAnios(setS);
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(480, MediaQuery.of(ctx).size.width - 40),
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.savings_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Crear Ahorro',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text('Registrar nuevo ahorro',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ── Campos ───────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ahorrador — buscable
                          _ahorrFieldLabel('Ahorrador'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final result = await _showAhorradorPicker(
                                  ctx, ahorradorOpts);
                              if (result != null) {
                                setS(() {
                                  selectedAhorrador = result['valor'];
                                  ahorradorLabel = result['nombre'];
                                });
                              }
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedAhorrador != null
                                      ? _accent1.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_search_rounded,
                                      size: 18,
                                      color: selectedAhorrador != null
                                          ? _accent1
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ahorradorLabel.isNotEmpty
                                          ? ahorradorLabel
                                          : 'Seleccione un ahorrador...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: ahorradorLabel.isNotEmpty
                                            ? _navy
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Año de Ahorro
                          _ahorrFieldLabel('Año de Ahorro'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: loadingAnios || aniosOpts.isEmpty
                                ? null
                                : () async {
                                    final result =
                                        await _showAnioPicker(ctx, aniosOpts);
                                    if (result != null) {
                                      setS(() => selectedAnioCodigo =
                                          result['codigo']);
                                    }
                                  },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedAnioCodigo != null
                                      ? _accent1.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 18,
                                      color: selectedAnioCodigo != null
                                          ? _accent1
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: loadingAnios
                                        ? const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Color(0xFF9CA3AF)),
                                              ),
                                              SizedBox(width: 8),
                                              Text('Cargando...',
                                                  style: TextStyle(
                                                      color: Color(0xFF9CA3AF),
                                                      fontSize: 13)),
                                            ],
                                          )
                                        : Builder(builder: (_) {
                                            String label =
                                                'Seleccione un año...';
                                            if (selectedAnioCodigo != null) {
                                              final m = aniosOpts.firstWhere(
                                                (a) =>
                                                    (a['codigo_ahorro_anyo'] ??
                                                            a.values.first)
                                                        .toString() ==
                                                    selectedAnioCodigo,
                                                orElse: () =>
                                                    <String, dynamic>{},
                                              );
                                              label = m['_label']?.toString() ??
                                                  selectedAnioCodigo!;
                                            }
                                            return Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: selectedAnioCodigo !=
                                                        null
                                                    ? _navy
                                                    : const Color(0xFF6B7280),
                                              ),
                                            );
                                          }),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Fecha de Ingreso
                          _ahorrFieldLabel('Fecha de Ingreso'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: fechaIngreso ?? DateTime.now(),
                                firstDate: DateTime(2015),
                                lastDate: DateTime(2035),
                                builder: (c, child) => Theme(
                                  data: Theme.of(c).copyWith(
                                      colorScheme: const ColorScheme.light(
                                          primary: _navy)),
                                  child: child!,
                                ),
                              );
                              if (d != null) setS(() => fechaIngreso = d);
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: fechaIngreso != null
                                      ? _accent1.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined,
                                      size: 18,
                                      color: fechaIngreso != null
                                          ? _accent1
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      fechaIngreso != null
                                          ? '${fechaIngreso!.day.toString().padLeft(2, '0')}/${fechaIngreso!.month.toString().padLeft(2, '0')}/${fechaIngreso!.year}'
                                          : 'dd/mm/aaaa',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: fechaIngreso != null
                                            ? _navy
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.expand_more_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Valor Pactado
                          _ahorrField(
                            ctrl: valorCtrl,
                            label: 'Valor Pactado',
                            icon: Icons.attach_money_rounded,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Botones ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8899BB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDDE3EF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cerrar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1B4B),
                                      Color(0xFF1E3A8A)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            color: saving ? const Color(0xFFCBD5E1) : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: saving
                                ? null
                                : [
                                    BoxShadow(
                                      color: _navy.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (selectedAhorrador == null) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Seleccione un ahorrador'),
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                      return;
                                    }
                                    if (fechaIngreso == null) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Seleccione la fecha de ingreso'),
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                      return;
                                    }
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setS(() => saving = true);
                                    try {
                                      final fechaStr =
                                          '${fechaIngreso!.year}-${fechaIngreso!.month.toString().padLeft(2, '0')}-${fechaIngreso!.day.toString().padLeft(2, '0')}';
                                      final r = await _api.post(
                                        '/ajax/registrar_ahorro.php',
                                        {
                                          'codigo_ahorrador':
                                              selectedAhorrador!,
                                          'codigo_anio_ahorro':
                                              selectedAnioCodigo ?? '',
                                          'fecha_ingreso': fechaStr,
                                          'valor_pactado':
                                              valorCtrl.text.trim(),
                                        },
                                      );
                                      final ok = r.statusCode == 200 &&
                                          (r.body
                                                  .toLowerCase()
                                                  .contains('exitoso') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('registrado') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('creado') ||
                                              r.body
                                                  .contains('"resultado":1') ||
                                              r.body
                                                  .contains('"success":true'));
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => _resultDialog(
                                            ok
                                                ? 'Ahorro registrado exitosamente'
                                                : r.body.trim().isNotEmpty
                                                    ? r.body.trim()
                                                    : 'No se pudo registrar',
                                            ok,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor:
                                                const Color(0xFFDC2626),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(saving ? 'Guardando...' : 'Grabar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), valorCtrl.dispose);
  }

  Future<Map<String, dynamic>?> _showAnioPicker(
      BuildContext ctx, List<Map<String, dynamic>> lista) {
    return showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (aCtx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              decoration: const BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Año de Ahorro',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(aCtx),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white60, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            ...lista.map((a) {
              final codigo =
                  (a['codigo_ahorro_anyo'] ?? a.values.first).toString();
              final label = a['_label']?.toString() ?? codigo;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      Navigator.pop(aCtx, {'codigo': codigo, 'label': label}),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded,
                            color: _accent1, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label,
                              style: const TextStyle(
                                  color: _navy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1), size: 18),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showAhorradorPicker(
      BuildContext ctx, List<Map<String, dynamic>> lista) {
    String query = '';
    // El campo nombre en listado_select viene como "concat(nombres,' ',apellidos)"
    String nombre(Map<String, dynamic> e) {
      final keys = e.keys.where((k) =>
          k.toLowerCase().contains('concat') ||
          k.toLowerCase().contains('nombre') ||
          k.toLowerCase().contains('apellido'));
      for (final k in keys) {
        final v = e[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return e.values
          .lastWhere((v) => v != null && v.toString().isNotEmpty,
              orElse: () => '')
          .toString();
    }

    return showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (aCtx) => StatefulBuilder(
        builder: (aCtx, setA) {
          final filtered = lista.where((e) {
            if (query.isEmpty) return true;
            return nombre(e).toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(aCtx).size.height * 0.65,
                maxWidth: min(420, MediaQuery.of(aCtx).size.width - 40),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    decoration: const BoxDecoration(
                      color: _navy,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_search_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Seleccionar ahorrador (${lista.length})',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(aCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setA(() => query = v.trim()),
                      style: const TextStyle(color: _navy, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar ahorrador...',
                        hintStyle: const TextStyle(
                            color: Color(0xFFB0BBCC), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF8899BB), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FB),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: _accent1, width: 1.5)),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final n = nombre(e);
                        final id = (e['codigo'] ??
                                e['valor'] ??
                                e['codigo_deudor'] ??
                                n)
                            .toString();
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                Navigator.pop(aCtx, {'valor': id, 'nombre': n}),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _accent1.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Center(
                                      child: Text(
                                        n.isNotEmpty ? n[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: _accent1,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(n,
                                        style: const TextStyle(
                                          color: _navy,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFFCBD5E1), size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Diálogo Crear Ahorrador ──────────────────────────────────────
  Future<void> _showCrearAhorradorDialog() async {
    final formKey = GlobalKey<FormState>();
    String? selectedAsesor;
    String asesorLabel = '';
    final docCtrl = TextEditingController();
    final nombresCtrl = TextEditingController();
    final apellCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(480, MediaQuery.of(ctx).size.width - 40),
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header gradiente ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Crear Ahorrador',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text('Registrar nuevo ahorrador',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                )),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ── Formulario ────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Asesor — campo buscable
                          _ahorrFieldLabel('Asesor'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final result = await _showAsesorPicker(ctx);
                              if (result != null) {
                                setS(() {
                                  selectedAsesor = result['valor'];
                                  asesorLabel = result['nombre'];
                                });
                              }
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedAsesor != null
                                      ? _accent1.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_search_rounded,
                                      size: 18,
                                      color: selectedAsesor != null
                                          ? _accent1
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      asesorLabel.isNotEmpty
                                          ? asesorLabel
                                          : 'Seleccione un asesor...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: asesorLabel.isNotEmpty
                                            ? _navy
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // N° Documento
                          _ahorrField(
                            ctrl: docCtrl,
                            label: 'N° Documento',
                            icon: Icons.badge_outlined,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Nombres + Apellidos en fila
                          Row(
                            children: [
                              Expanded(
                                child: _ahorrField(
                                  ctrl: nombresCtrl,
                                  label: 'Nombres',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ahorrField(
                                  ctrl: apellCtrl,
                                  label: 'Apellidos',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Dirección
                          _ahorrField(
                            ctrl: dirCtrl,
                            label: 'Dirección',
                            icon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 12),

                          // Teléfono
                          _ahorrField(
                            ctrl: telCtrl,
                            label: 'Teléfono',
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Botones ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8899BB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDDE3EF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cerrar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1B4B),
                                      Color(0xFF1E3A8A)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            color: saving ? const Color(0xFFCBD5E1) : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: saving
                                ? null
                                : [
                                    BoxShadow(
                                      color: _navy.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (selectedAsesor == null) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('Seleccione un asesor'),
                                          backgroundColor: Color(0xFFDC2626),
                                        ),
                                      );
                                      return;
                                    }
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setS(() => saving = true);
                                    try {
                                      final r = await _api.post(
                                        '/ajax/registrar_ahorrador.php',
                                        {
                                          'codigo_asesor': selectedAsesor!,
                                          'documento': docCtrl.text.trim(),
                                          'nombres': nombresCtrl.text.trim(),
                                          'apellidos': apellCtrl.text.trim(),
                                          'direccion': dirCtrl.text.trim(),
                                          'telefono': telCtrl.text.trim(),
                                        },
                                      );
                                      final ok = r.statusCode == 200 &&
                                          (r.body
                                                  .toLowerCase()
                                                  .contains('exitoso') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('registrado') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('creado') ||
                                              r.body
                                                  .contains('"resultado":1') ||
                                              r.body
                                                  .contains('"success":true'));
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => _resultDialog(
                                            ok
                                                ? 'Ahorrador registrado exitosamente'
                                                : r.body.trim().isNotEmpty
                                                    ? r.body.trim()
                                                    : 'No se pudo registrar',
                                            ok,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor:
                                                const Color(0xFFDC2626),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(saving ? 'Guardando...' : 'Grabar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      docCtrl.dispose();
      nombresCtrl.dispose();
      apellCtrl.dispose();
      dirCtrl.dispose();
      telCtrl.dispose();
    });
  }

  Widget _ahorrFieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: _navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _ahorrField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: _navy, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8899BB), fontSize: 13),
          prefixIcon: Icon(icon, color: _accent1, size: 18),
          filled: true,
          fillColor: const Color(0xFFF5F7FB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent1, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          ),
        ),
      );

  Future<Map<String, dynamic>?> _showAsesorPicker(BuildContext ctx) {
    String query = '';
    return showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (aCtx) => StatefulBuilder(
        builder: (aCtx, setA) {
          final all = _asesoresLista.map((a) {
            final sigla = (a['sigla'] ?? a['codigo_asesor'] ?? '').toString();
            final nombre = [a['nombres'], a['apellidos']]
                .where((x) => x != null && x.toString().isNotEmpty)
                .join(' ')
                .trim();
            return {
              'valor': sigla,
              'nombre': nombre.isNotEmpty ? nombre : sigla
            };
          }).toList();

          final filtered = query.isEmpty
              ? all
              : all
                  .where((a) =>
                      a['nombre']!.toLowerCase().contains(query.toLowerCase()))
                  .toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(aCtx).size.height * 0.6,
                maxWidth: min(420, MediaQuery.of(aCtx).size.width - 40),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    decoration: const BoxDecoration(
                      color: _navy,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_search_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Seleccionar asesor',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(aCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setA(() => query = v.trim()),
                      style: const TextStyle(color: _navy, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar asesor...',
                        hintStyle: const TextStyle(
                            color: Color(0xFFB0BBCC), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF8899BB), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FB),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: _accent1, width: 1.5)),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final a = filtered[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.pop(aCtx, a),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _accent1.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Center(
                                      child: Text(
                                        a['nombre']!.isNotEmpty
                                            ? a['nombre']![0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: _accent1,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(a['nombre']!,
                                        style: const TextStyle(
                                          color: _navy,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFFCBD5E1), size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  AHORRADORES TAB
  // ══════════════════════════════════════════════════════════════
  Widget _ahorradoresTab() {
    if (_loadingData) return _loadingView();

    const navy = Color(0xFF0D1B4B);

    // Años disponibles: solo 2025 y año actual
    final currentYear = DateTime.now().year;
    final anios = ({currentYear.toString(), '2025'}).toList()
      ..sort((a, b) => b.compareTo(a));

    // Asesores: todos los conocidos (igual que la web) + cualquiera presente
    // en los datos, ordenados por nombre completo.
    final asesorSet = <String>{..._asesorNombres.keys};
    for (final a in _ahorradores) {
      final v = (a['asesor'] ?? '').toString().trim().toUpperCase();
      if (v.isNotEmpty) asesorSet.add(v);
    }
    final asesorOrdenados = asesorSet.toList()
      ..sort((a, b) => _nombreAsesor(a)
          .toLowerCase()
          .compareTo(_nombreAsesor(b).toLowerCase()));
    final asesores = ['0', ...asesorOrdenados];

    final lista = _ahorradoresFiltrados;
    final total = lista.fold(
        0.0,
        (s, a) =>
            s +
            _num(a['total_ahorrado'] ?? a['valor_pactado'] ?? a['monto'] ?? 0));

    final enMoraCount = lista.where((a) {
      final cuotas = a['ahorros'];
      if (cuotas is! List) return false;
      final hoy = _hoyColombia();
      return cuotas.whereType<Map>().any((m) {
        final pagado = (m['estado_pago'] ?? '').toString().toLowerCase().contains('pagado');
        if (pagado) return false;
        final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
        if (fc == null) return false;
        return !DateTime(fc.year, fc.month, fc.day).isAfter(hoy);
      });
    }).length;
    final alDiaCount = lista.length - enMoraCount;

    Widget dropFilter({
      required String label, required IconData icon,
      required String value, required List<DropdownMenuItem<String>> items,
      required ValueChanged<String?> onChanged,
    }) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: const Color(0xFF8899BB)),
        const SizedBox(width: 6),
        Expanded(child: DropdownButton<String>(
          value: value, isExpanded: true,
          underline: const SizedBox(), dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF8899BB)),
          style: const TextStyle(color: navy, fontWeight: FontWeight.w600, fontSize: 13),
          items: items,
          onChanged: onChanged,
        )),
      ]),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Botones de acción ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _actionBtn(
                icon: Icons.person_add_rounded,
                label: 'Agregar Ahorrador',
                color: navy,
                onTap: () => _showCrearAhorradorDialog()),
            _actionBtn(
                icon: Icons.savings_rounded,
                label: 'Agregar Ahorro',
                color: navy,
                onTap: () => _showCrearAhorroDialog()),
            _actionBtn(
                icon: Icons.settings_rounded,
                label: 'Configurar Ahorro',
                color: navy,
                onTap: () => _showConfigurarAhorroDialog()),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Banner hero ───────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3730A3), Color(0xFF4361EE), Color(0xFF6366F1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: const Color(0xFF4361EE).withValues(alpha: 0.45),
              blurRadius: 24, offset: const Offset(0, 8),
            )],
          ),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${lista.length} Ahorradores',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 20)),
                Text('Total: ${_cop(total)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 14),
            // Mini stats row
            Row(children: [
              _ahorMiniStat(Icons.check_circle_outline_rounded,
                  'Al día', '$alDiaCount', const Color(0xFF6EE7B7)),
              Container(width: 1, height: 30,
                  color: Colors.white.withValues(alpha: 0.2)),
              _ahorMiniStat(Icons.warning_amber_rounded,
                  'En mora', '$enMoraCount', const Color(0xFFFCA5A5)),
              Container(width: 1, height: 30,
                  color: Colors.white.withValues(alpha: 0.2)),
              _ahorMiniStat(Icons.calendar_today_outlined,
                  'Año', _ahorFilterAnio, Colors.white),
            ]),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Filtros ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            dropFilter(
              label: 'Año', icon: Icons.calendar_today_outlined,
              value: _ahorFilterAnio,
              items: anios.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _ahorFilterAnio = v);
                _reloadAhorradores();
              },
            ),
            const SizedBox(width: 10),
            dropFilter(
              label: 'Asesor', icon: Icons.person_outline_rounded,
              value: asesores.contains(_ahorFilterAsesor) ? _ahorFilterAsesor : '0',
              items: asesores.map((s) => DropdownMenuItem(
                value: s,
                child: Text(s == '0' ? 'Todos' : _nombreAsesor(s),
                    overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _ahorFilterAsesor = v);
              },
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Lista ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Expanded(child: Text('Lista de Ahorradores',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: navy))),
            if (lista.isNotEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4361EE).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text('${lista.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Color(0xFF4361EE)))),
          ]),
        ),
        const SizedBox(height: 10),

        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text(
                'No hay ahorradores para los filtros seleccionados',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8899BB)))),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ahoradorCard(lista[i]),
          ),
      ],
    );
  }

  // ── Ahorros helpers ──────────────────────────────────────────
  static DateTime _hoyColombia() {
    final n = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    return DateTime(n.year, n.month, n.day);
  }

  Widget _ahorMiniStat(
          IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ]),
      );

  // ══════════════════════════════════════════════════════════════
  //  MOVIMIENTOS TAB — Gestión de Gastos (2 sub-tabs)
  // ══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get _movimientosFiltrados {
    return _movimientos.where((m) {
      if (_filterCuenta.isNotEmpty &&
          (m['cuenta_nombre'] ?? '') != _filterCuenta) {
        return false;
      }
      if (_filterTipo.isNotEmpty &&
          (m['tipo_movimiento'] ?? '').toString() != _filterTipo) {
        return false;
      }
      final rawFecha = (m['fecha'] ?? '').toString();
      if (rawFecha.length >= 10) {
        final fecha = DateTime.tryParse(rawFecha.substring(0, 10));
        if (fecha != null) {
          if (_filterDesde != null && fecha.isBefore(_filterDesde!)) {
            return false;
          }
          if (_filterHasta != null && fecha.isAfter(_filterHasta!)) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  Widget _movimientosTab() {
    if (_loadingData) return _loadingView();

    final filtrados = _movimientosFiltrados;

    // Check if dates differ from the 31-day defaults
    final now = DateTime.now();
    final defaultDesde = now.subtract(const Duration(days: 31));
    final datesAreDefault = _filterDesde == null ||
        (_filterDesde!.difference(defaultDesde).inDays.abs() <= 1 &&
            (_filterHasta == null ||
                _filterHasta!.difference(now).inDays.abs() <= 1));
    final hasUserFilter =
        _filterCuenta.isNotEmpty || _filterTipo.isNotEmpty || !datesAreDefault;

    // Server totals: default range → _srvGastos/_srvIngresos; filtered → _filtGastos/_filtIngresos
    final gastos = hasUserFilter
        ? (_filtTotalesLoaded
            ? _filtGastos
            : filtrados
                .where((m) => (m['tipo_movimiento'] ?? '').toString() == '2')
                .fold(0.0, (s, m) => s + _num(m['valor'] ?? 0)))
        : (_srvTotalesLoaded ? _srvGastos : 0.0);
    final ingresos = hasUserFilter
        ? (_filtTotalesLoaded
            ? _filtIngresos
            : filtrados.where((m) {
                final t = (m['tipo_movimiento'] ?? '').toString();
                return t == '3' || t == '1';
              }).fold(0.0, (s, m) => s + _num(m['valor'] ?? 0)))
        : (_srvTotalesLoaded ? _srvIngresos : 0.0);
    final balance = ingresos - gastos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sub-tab switcher ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _subTab(0, 'Cuentas'),
              _subTab(1, 'Movimientos'),
            ]),
          ),
        ),

        if (_movSubTab == 0) ...[
          // ── CUENTAS: botones de acción ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(children: [
              _actionBtn(
                label: '+ Nueva Cuenta/Fuente',
                color: const Color(0xFF10B981),
                onTap: () => _showNuevaCuentaDialog(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _actionBtn(
                  label: '⇄ Movimientos',
                  color: _navy,
                  onTap: () => _showRegistrarMovimientoDialog(),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: _actionBtn(
                  label: '⇄ Transferir',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _showTransferirDialog(),
                )),
              ]),
            ]),
          ),
          // Total saldo card
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B4B), Color(0xFF1A3A9F)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 28),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total de Saldos',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                    _cop(_cuentas.fold(
                        0.0, (s, c) => s + _num(c['saldo_actual'] ?? 0))),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
          // Lista de cuentas
          if (_cuentas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _emptyActivity(),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _cuentas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _cuentaRowReal(_cuentas[i]),
            ),
        ] else ...[
          // ── HERO BANNER ────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - t)),
              child: Opacity(opacity: t, child: child),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B4B), Color(0xFF1E40AF), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF1E40AF).withValues(alpha: 0.40),
                    blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Stack(children: [
                Positioned(right: -55, top: -55,
                  child: Container(width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07)))),
                Positioned(right: -20, top: -20,
                  child: Container(width: 90, height: 90,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06)))),
                Positioned(left: -30, bottom: -30,
                  child: Container(width: 100, height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: balance >= 0
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFFCA5A5),
                          boxShadow: [BoxShadow(
                            color: (balance >= 0
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFFCA5A5)).withValues(alpha: 0.7),
                            blurRadius: 6, spreadRadius: 1)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Balance del período',
                          style: TextStyle(color: Colors.white60,
                              fontSize: 11, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text('${filtrados.length} mov.',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    (hasUserFilter && !_filtTotalesLoaded)
                        ? Container(width: 170, height: 34,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8)))
                        : TweenAnimationBuilder<double>(
                            key: ValueKey(balance),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutQuart,
                            builder: (_, t, __) => Text(
                              _cop(balance * t),
                              style: TextStyle(
                                  color: balance >= 0
                                      ? Colors.white
                                      : const Color(0xFFFCA5A5),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1),
                            ),
                          ),
                    const SizedBox(height: 18),
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _heroStat(
                        label: 'GASTOS',
                        value: (hasUserFilter && !_filtTotalesLoaded) ? null : _cop(gastos),
                        icon: Icons.arrow_upward_rounded,
                        color: const Color(0xFFFCA5A5),
                      )),
                      Container(width: 1, height: 44,
                          color: Colors.white.withValues(alpha: 0.18)),
                      Expanded(child: _heroStat(
                        label: 'INGRESOS',
                        value: (hasUserFilter && !_filtTotalesLoaded) ? null : _cop(ingresos),
                        icon: Icons.arrow_downward_rounded,
                        color: const Color(0xFF6EE7B7),
                        alignEnd: true,
                      )),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
          // ── Botones de acción ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showRegistrarMovimientoDialog(),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: 0.35),
                          blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 7),
                      Text('Nuevo Movimiento',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showTransferirDialog(),
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
                        blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ]),
          ),
          // ── Filtros ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF4361EE).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(children: [
              // Gradient header bar
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B4B), Color(0xFF1A3170)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tune_rounded,
                        size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text('Filtros',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700, color: Colors.white)),
                  if (hasUserFilter) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF6EE7B7).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('activo',
                          style: TextStyle(fontSize: 9,
                              color: Color(0xFF6EE7B7), fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  if (hasUserFilter)
                    GestureDetector(
                      onTap: () => setState(() {
                        _filterCuenta = '';
                        _filterTipo = '';
                        _filterDesde = null;
                        _filterHasta = null;
                        _filtTotalesLoaded = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                        child: const Row(children: [
                          Icon(Icons.close_rounded, size: 11, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('Limpiar',
                              style: TextStyle(fontSize: 10,
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(children: [
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _filterDropdown<String>(
                  label: 'Cuenta',
                  value: _filterCuenta.isEmpty ? null : _filterCuenta,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ..._cuentas.map((c) => DropdownMenuItem(
                          value: (c['nombre'] ?? '').toString(),
                          child: Text((c['nombre'] ?? '').toString(),
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _filterCuenta = v ?? '';
                      _filtTotalesLoaded = false;
                    });
                    unawaited(_fetchTotalesFiltrados());
                  },
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _filterDropdown<String>(
                  label: 'Tipo',
                  value: _filterTipo.isEmpty ? null : _filterTipo,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: '2', child: Text('Gasto')),
                    DropdownMenuItem(value: '3', child: Text('Ingreso')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _filterTipo = v ?? '';
                      _filtTotalesLoaded = false;
                    });
                    unawaited(_fetchTotalesFiltrados());
                  },
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _filterDate(
                  label: 'Desde',
                  value: _filterDesde,
                  onPick: (d) {
                    setState(() {
                      _filterDesde = d;
                      _filtTotalesLoaded = false;
                    });
                    unawaited(_fetchTotalesFiltrados());
                  },
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _filterDate(
                  label: 'Hasta',
                  value: _filterHasta,
                  onPick: (d) {
                    setState(() {
                      _filterHasta = d;
                      _filtTotalesLoaded = false;
                    });
                    unawaited(_fetchTotalesFiltrados());
                  },
                )),
              ]),
              const SizedBox(height: 4),
            ]),
          ),
          // closes outer Column + Container
          ]),
          ),
          // ── Lista movimientos header ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF4361EE), Color(0xFF0EA5E9)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Movimientos',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1B4B))),
                ]),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${filtrados.length} registros',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4361EE),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          if (filtrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _emptyActivity(),
            )
          else
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: filtrados
                    .asMap()
                    .entries
                    .map((e) => _movimientoItemReal(e.value,
                        divider: e.key < filtrados.length - 1))
                    .toList(),
              ),
            ),
        ],
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final colorDark = Color.lerp(color, Colors.black, 0.22) ?? color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, colorDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: colorDark.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 5)),
            BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8899BB))),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
              dropdownColor: Colors.white,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0D1B4B),
                  fontFamily: 'sans-serif'),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Color(0xFF8899BB)),
            ),
          ),
        ),
      ]);

  Widget _filterDate({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8899BB))),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: Color(0xFF0D1B4B))),
                child: child!,
              ),
            );
            onPick(picked);
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Color(0xFF8899BB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value != null
                      ? '${value.day.toString().padLeft(2, '0')}/'
                          '${value.month.toString().padLeft(2, '0')}/'
                          '${value.year}'
                      : 'DD/MM/AAAA',
                  style: TextStyle(
                      fontSize: 12,
                      color: value != null
                          ? const Color(0xFF0D1B4B)
                          : const Color(0xFF8899BB)),
                ),
              ),
            ]),
          ),
        ),
      ]);

  // ── Diálogo Crear Deudor ─────────────────────────────────────────
  void _showCrearDeudorDialog() {
    final formKey = GlobalKey<FormState>();
    String? selectedAsesor;
    final docCtrl = TextEditingController();
    final nombresCtrl = TextEditingController();
    final apellidosCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Future<void> grabar() async {
          if (!formKey.currentState!.validate()) return;
          setS(() => saving = true);
          try {
            final r = await _api.post('/ajax/registrar_deudor.php', {
              'codigo_asesor': selectedAsesor ?? '',
              'num_documento': docCtrl.text.trim(),
              'nombres': nombresCtrl.text.trim(),
              'apellidos': apellidosCtrl.text.trim(),
              'direccion': direccionCtrl.text.trim(),
              'telefono': telefonoCtrl.text.trim(),
            });
            final ok = r.statusCode == 200 &&
                r.body.toLowerCase().contains('registrado');
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              showDialog(
                context: context,
                builder: (_) => _resultDialog(
                  ok ? 'Deudor creado exitosamente' : r.body.trim(),
                  ok,
                ),
              );
              if (ok) {
                _api.invalidateCache('/ajax/listado_json_campos.php');
                final u = _api.user;
                await _fetchCreditos(u?['codigo_usuario']?.toString() ?? '');
                if (mounted) setState(() {});
              }
            }
          } catch (e) {
            setS(() => saving = false);
            if (ctx.mounted) {
              showDialog(
                context: ctx,
                builder: (_) => _resultDialog('Error de conexión: $e', false),
              );
            }
          }
        }

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: min(460, MediaQuery.of(ctx).size.width - 40),
                maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Título
                  Row(children: [
                    const Expanded(
                        child: Text('Crear Deudor',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D1B4B)))),
                    IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints()),
                  ]),
                  const Divider(height: 20),
                  // Asesor
                  _dRow(
                    'Asesor',
                    _dDropdown<String>(
                      value: selectedAsesor,
                      items: _asesorNombres.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setS(() => selectedAsesor = v),
                      validator: (v) =>
                          v == null ? 'Seleccione un asesor' : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _dRow(
                      'N° Documento',
                      _dField(docCtrl,
                          required: true, keyboard: TextInputType.number)),
                  const SizedBox(height: 8),
                  _dRow('Nombres', _dField(nombresCtrl, required: true)),
                  const SizedBox(height: 8),
                  _dRow('Apellidos', _dField(apellidosCtrl, required: true)),
                  const SizedBox(height: 8),
                  _dRow('Dirección', _dField(direccionCtrl)),
                  const SizedBox(height: 8),
                  _dRow('Telefono',
                      _dField(telefonoCtrl, keyboard: TextInputType.phone)),
                  const SizedBox(height: 20),
                  // Botones
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280)),
                        child: const Text('Cerrar')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: saving ? null : grabar,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D1B4B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Grabar')),
                  ]),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Buscador de deudor ───────────────────────────────────────────
  Future<Map<String, dynamic>?> _showDeudorPicker(BuildContext ctx) {
    String query = '';
    return showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) {
          final allFiltered = _deudoresLista.where((d) {
            if (query.isEmpty) return true;
            final label = (d['etiqueta'] ?? d['nombres'] ?? d['nombre'] ?? '')
                .toString()
                .toLowerCase();
            return label.contains(query.toLowerCase());
          }).toList();
          // Limitar a 100 para no saturar el render si hay cientos
          final filtered = allFiltered.length > 100
              ? allFiltered.sublist(0, 100)
              : allFiltered;

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dCtx).size.height * 0.75,
                maxWidth: min(480, MediaQuery.of(dCtx).size.width - 32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_search_rounded,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Buscar deudor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Buscador
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setD(() => query = v.trim()),
                      style: const TextStyle(color: _navy, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Nombre del deudor... (${_deudoresLista.length} registrados)',
                        hintStyle: const TextStyle(
                            color: Color(0xFFB0BBCC), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF8899BB), size: 20),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    color: Color(0xFF8899BB), size: 18),
                                onPressed: () => setD(() => query = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF5F7FB),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFDDE3EF)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFDDE3EF)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _accent1, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Contador
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        filtered.isEmpty
                            ? 'Sin resultados'
                            : allFiltered.length > 100
                                ? 'Mostrando 100 de ${allFiltered.length} — escribe para filtrar'
                                : '${filtered.length} resultado${filtered.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Color(0xFF8899BB), fontSize: 11),
                      ),
                    ),
                  ),
                  // Lista
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 40, color: Color(0xFFCBD5E1)),
                                SizedBox(height: 10),
                                Text('No se encontró ningún deudor',
                                    style: TextStyle(color: Color(0xFF8899BB))),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (_, i) {
                              final d = filtered[i];
                              final label = (d['etiqueta'] ??
                                      d['nombres'] ??
                                      d['nombre'] ??
                                      '')
                                  .toString()
                                  .trim();
                              final id = (d['valor'] ??
                                      d['codigo'] ??
                                      d['id'] ??
                                      label)
                                  .toString();
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => Navigator.pop(dCtx, {
                                    'valor': id,
                                    'etiqueta': label,
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color:
                                                _accent1.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              label.isNotEmpty
                                                  ? label[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: _accent1,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            label.isNotEmpty ? label : id,
                                            style: const TextStyle(
                                              color: _navy,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: Color(0xFFCBD5E1), size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Diálogo Crear Crédito ────────────────────────────────────────
  void _showCrearCreditoDialog() {
    final formKey = GlobalKey<FormState>();
    String? selectedDeudor;
    String deudorLabel = '';
    String? selectedTiempoC = 'Mensual';
    String? selectedTipoInt = 'fijo';
    String? selectedTasa;
    String? selectedFuente;
    DateTime? fechaPrestamo;
    final valorCtrl = TextEditingController();
    final numCuotasCtrl = TextEditingController();
    double totalAPagar = 0;
    // Empieza cargando si no tenemos deudores aún
    bool loadingDeudores = _deudoresLista.isEmpty;
    bool listsStarted = false;

    // Opciones estáticas (según el sistema)
    const tiempoOpciones = [
      ('Mensual', 'Mensual'),
      ('Quincenal', 'Quincenal'),
      ('Semanal', 'Semanal'),
      ('Diario', 'Diario'),
    ];
    const tipoIntOpciones = [
      ('fijo', 'Interés Fijo'),
      ('variable', 'Interés Variable'),
    ];

    // Tasas: de la API o fallback
    List<String> tasaOpciones() {
      if (_tasasLista.isNotEmpty) {
        return _tasasLista
            .map((t) =>
                (t['tasa'] ?? t['valor'] ?? t['nombre'] ?? '').toString())
            .where((t) => t.isNotEmpty)
            .toList();
      }
      return ['0%', '8%', '10%', '15%', '17.5%', '18%', '20%'];
    }

    // Fuentes: de la API o fallback
    List<String> fuenteOpciones() {
      if (_fuentesLista.isNotEmpty) {
        return _fuentesLista
            .map((f) =>
                (f['fuente'] ?? f['nombre'] ?? f['name'] ?? '').toString())
            .where((f) => f.isNotEmpty)
            .toList();
      }
      return [
        'Davivienda',
        'Bancolombia',
        'Daviplata',
        'Nequi',
        'Efectivo',
        'Préstamos',
        'SAF Ahorros',
        'Cámaras',
        'Dínamo Jr',
      ];
    }

    void recalcTotal(void Function(void Function()) setS) {
      final valor = double.tryParse(
              valorCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
      final cuotas = int.tryParse(numCuotasCtrl.text) ?? 0;
      final tasaStr = (selectedTasa ?? '0').replaceAll('%', '').trim();
      final tasa = double.tryParse(tasaStr) ?? 0;
      final diasPorCuota = {
            'Mensual': 30,
            'Quincenal': 15,
            'Semanal': 7,
            'Diario': 1
          }[selectedTiempoC ?? 'Mensual'] ??
          30;
      final totalDias = cuotas * diasPorCuota;
      final tasaDiaria = tasa / 100 / 30;
      final total = valor + (valor * tasaDiaria * totalDias);
      setS(() => totalAPagar = total);
    }

    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        // Arranca fetch la primera vez que el builder corre
        if (!listsStarted) {
          listsStarted = true;
          Future(() async {
            // Mostrar datos locales de inmediato (sin red)
            _tryBuildDeudoresFromLocal();
            if (ctx.mounted) {
              setS(() => loadingDeudores = _deudoresLista.isEmpty);
            }

            // Siempre refrescar desde API para obtener la lista completa
            await Future.wait([
              _fetchDeudores(),
              if (_tasasLista.isEmpty) _fetchTasas(),
              if (_fuentesLista.isEmpty) _fetchFuentes(),
            ]);
            if (ctx.mounted) setS(() => loadingDeudores = false);
          });
        }

        Future<void> grabar() async {
          if (!formKey.currentState!.validate()) return;
          if (fechaPrestamo == null) {
            showDialog(
                context: ctx,
                builder: (_) =>
                    _resultDialog('Seleccione la fecha de préstamo', false));
            return;
          }
          setS(() => saving = true);
          try {
            final r = await _api.post('/ajax/registrar_credito.php', {
              'codigo_deudor': selectedDeudor ?? '',
              'fecha_prestamo':
                  '${fechaPrestamo!.year}-${fechaPrestamo!.month.toString().padLeft(2, '0')}-${fechaPrestamo!.day.toString().padLeft(2, '0')}',
              'valor_prestamo': valorCtrl.text.trim(),
              'tiempo_cuota': selectedTiempoC ?? '',
              'num_cuotas': numCuotasCtrl.text.trim(),
              'tipo_interes': selectedTipoInt ?? '',
              'codigo_tasa_interes_reg': selectedTasa ?? '',
              'fuente_credito_reg': selectedFuente ?? '',
              'total_pagar': totalAPagar.toStringAsFixed(0),
            });
            final ok =
                r.statusCode == 200 && r.body.toLowerCase().contains('creado');
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              showDialog(
                context: context,
                builder: (_) => _resultDialog(
                  ok ? 'Crédito creado exitosamente' : r.body.trim(),
                  ok,
                ),
              );
              if (ok) {
                _api.invalidateCache('/ajax/listado_json_campos.php');
                final u = _api.user;
                await _fetchCreditos(u?['codigo_usuario']?.toString() ?? '');
                if (mounted) setState(() {});
              }
            }
          } catch (e) {
            setS(() => saving = false);
            if (ctx.mounted) {
              showDialog(
                  context: ctx,
                  builder: (_) =>
                      _resultDialog('Error de conexión: $e', false));
            }
          }
        }

        final tasas = tasaOpciones();
        final fuentes = fuenteOpciones();

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: min(460, MediaQuery.of(ctx).size.width - 40),
                maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Título
                  Row(children: [
                    const Expanded(
                        child: Text('Crear Crédito',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D1B4B)))),
                    IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints()),
                  ]),
                  const Divider(height: 20),
                  // Deudor — campo buscable
                  _dRow(
                    'Deudor:',
                    GestureDetector(
                      onTap: loadingDeudores
                          ? null
                          : () async {
                              final result = await _showDeudorPicker(ctx);
                              if (result != null) {
                                setS(() {
                                  selectedDeudor = result['valor'];
                                  deudorLabel = result['etiqueta'] ?? '';
                                });
                              }
                            },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FB),
                          border: Border.all(
                            color: selectedDeudor != null
                                ? _accent1.withValues(alpha: 0.5)
                                : const Color(0xFFDDE3EF),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: loadingDeudores
                                  ? Row(children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF9CA3AF)),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Cargando deudores...',
                                          style: TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 13)),
                                    ])
                                  : Text(
                                      deudorLabel.isNotEmpty
                                          ? deudorLabel
                                          : 'Toca para buscar deudor...',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: deudorLabel.isNotEmpty
                                            ? const Color(0xFF0D1B4B)
                                            : const Color(0xFF9CA3AF),
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: selectedDeudor != null
                                  ? _accent1
                                  : const Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Fecha Préstamo
                  _dRow(
                    'Fecha de Préstamo',
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: fechaPrestamo ?? DateTime.now(),
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2035),
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                                colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF0D1B4B))),
                            child: child!,
                          ),
                        );
                        if (d != null) setS(() => fechaPrestamo = d);
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FB),
                            border: Border.all(color: const Color(0xFFDDE3EF)),
                            borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.centerLeft,
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              fechaPrestamo != null
                                  ? '${fechaPrestamo!.day.toString().padLeft(2, '0')}/${fechaPrestamo!.month.toString().padLeft(2, '0')}/${fechaPrestamo!.year}'
                                  : 'dd/mm/aaaa',
                              style: _dTextStyle.copyWith(
                                  color: fechaPrestamo != null
                                      ? const Color(0xFF374151)
                                      : const Color(0xFF9CA3AF)),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: Color(0xFF9CA3AF)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Valor Préstamo
                  _dRow(
                    'Valor Préstamo',
                    TextFormField(
                      controller: valorCtrl,
                      decoration: _dInputDeco(),
                      keyboardType: TextInputType.number,
                      style: _dTextStyle,
                      onChanged: (_) => recalcTotal(setS),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingrese el valor'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tiempo Cuotas
                  _dRow(
                    'Tiempo Cuotas',
                    _dDropdown<String>(
                      value: selectedTiempoC,
                      hint: 'Seleccione',
                      items: tiempoOpciones
                          .map((o) =>
                              DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                          .toList(),
                      onChanged: (v) {
                        setS(() => selectedTiempoC = v);
                        recalcTotal(setS);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Número de Cuotas
                  _dRow(
                    'Número de Cuotas',
                    TextFormField(
                      controller: numCuotasCtrl,
                      decoration: _dInputDeco(),
                      keyboardType: TextInputType.number,
                      style: _dTextStyle,
                      onChanged: (_) => recalcTotal(setS),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingrese el número de cuotas'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tipo de Interés
                  _dRow(
                    'Tipo de Interés',
                    _dDropdown<String>(
                      value: selectedTipoInt,
                      hint: 'Seleccione',
                      items: tipoIntOpciones
                          .map((o) =>
                              DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                          .toList(),
                      onChanged: (v) => setS(() => selectedTipoInt = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tasa Interés
                  _dRow(
                    'Tasa interés',
                    _dDropdown<String>(
                      value: tasas.contains(selectedTasa) ? selectedTasa : null,
                      items: tasas
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        setS(() => selectedTasa = v);
                        recalcTotal(setS);
                      },
                      validator: (v) =>
                          v == null ? 'Seleccione una tasa' : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Fuente
                  _dRow(
                    'Fuente',
                    _dDropdown<String>(
                      value: fuentes.contains(selectedFuente)
                          ? selectedFuente
                          : null,
                      items: fuentes
                          .map(
                              (f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) => setS(() => selectedFuente = v),
                      validator: (v) =>
                          v == null ? 'Seleccione una fuente' : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Total a Pagar (read-only calculado)
                  _dRow(
                    'Total a Pagar',
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FB),
                          border: Border.all(color: const Color(0xFFDDE3EF)),
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        totalAPagar > 0 ? _cop(totalAPagar) : '',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0D1B4B),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Botones
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280)),
                        child: const Text('Cerrar')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: saving ? null : grabar,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D1B4B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Grabar')),
                  ]),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Diálogo de resultado (éxito / error) ─────────────────────────
  Widget _resultDialog(String msg, bool ok) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
              color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(ok ? 'Éxito' : 'Error',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1B4B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Aceptar')),
        ],
      );

  // ── Helpers de formulario ────────────────────────────────────────
  Widget _dRow(String label, Widget input) => LayoutBuilder(
        builder: (_, constraints) {
          final labelW = (constraints.maxWidth * 0.37).clamp(90.0, 130.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: labelW,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569))),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: input),
            ],
          );
        },
      );

  static const _dTextStyle = TextStyle(fontSize: 13, color: Color(0xFF374151));
  static const _dHintStyle = TextStyle(fontSize: 13, color: Color(0xFF9CA3AF));

  // Dropdown estilizado para los diálogos
  Widget _dDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    String? Function(T?)? validator,
    bool isExpanded = true,
  }) =>
      DropdownButtonFormField<T>(
        // ignore: deprecated_member_use
        value: value,
        isExpanded: isExpanded,
        decoration: _dInputDeco(),
        dropdownColor: Colors.white,
        style: _dTextStyle,
        hint: Text(hint ?? '[Seleccione]', style: _dHintStyle),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            size: 18, color: Color(0xFF9CA3AF)),
        items: items,
        onChanged: onChanged,
        validator: validator,
      );

  InputDecoration _dInputDeco() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF5F7FB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4361EE), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
      );

  Widget _dField(
    TextEditingController ctrl, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) =>
      TextFormField(
        controller: ctrl,
        decoration: _dInputDeco(),
        keyboardType: keyboard,
        obscureText: obscure,
        style: _dTextStyle,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
            : null,
      );

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  Widget _subTab(int index, String label) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _movSubTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _movSubTab == index ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: _movSubTab == index
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _movSubTab == index ? _navy : const Color(0xFF8899BB),
                )),
          ),
        ),
      );

  // ── Colores predefinidos para el picker de cuenta ────────────────
  static const _presetColors = [
    '#FF6B35',
    '#F7C59F',
    '#EFEFD0',
    '#004E89',
    '#1A936F',
    '#EF233C',
    '#8D99AE',
    '#2B2D42',
    '#F72585',
    '#7209B7',
    '#3A0CA3',
    '#4361EE',
    '#4CC9F0',
    '#06D6A0',
    '#FFD166',
    '#EF476F',
    '#118AB2',
    '#073B4C',
    '#E76F51',
    '#264653',
    '#2A9D8F',
    '#E9C46A',
    '#F4A261',
    '#D62828',
    '#023E8A',
  ];

  Future<void> _showAjustarSaldoDialog(Map<String, dynamic> cuenta) async {
    final codigoUsuario = (_api.user?['codigo_usuario'] ?? '').toString();
    final formKey = GlobalKey<FormState>();
    final nuevoSaldoCtrl = TextEditingController();
    final nombreCuenta = (cuenta['nombre'] ?? '').toString();
    final codigoCuenta = (cuenta['codigo'] ?? '').toString();

    // Saldo actual desde movimientos en memoria
    final saldoActual = _movimientos
        .where((m) =>
            (m['codigo_cuenta'] ?? m['cuenta_codigo'] ?? '').toString() ==
            codigoCuenta)
        .fold<double>(0.0, (sum, m) {
      final t = (m['tipo_movimiento'] ?? '').toString();
      final v = _num(m['valor'] ?? 0);
      if (t == '3' || t == '1') return sum + v;
      if (t == '2') return sum - v;
      return sum;
    });

    bool saving = false;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget gradBtn({
          required List<Color> colors,
          required VoidCallback? onPressed,
          required Widget child,
        }) =>
            GestureDetector(
              onTap: onPressed,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            );

        Widget readonlyField(String label, String value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF6B7280))),
                ),
              ],
            );

        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ajustar Saldo de Cuenta',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0D1B4B))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  readonlyField('Cuenta', nombreCuenta),
                  const SizedBox(height: 14),
                  readonlyField('Saldo Actual', _cop(saldoActual)),
                  const SizedBox(height: 14),
                  const Text('Nuevo Saldo',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nuevoSaldoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                      child: gradBtn(
                        colors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: gradBtn(
                        colors: saving
                            ? [Colors.grey, Colors.grey]
                            : const [Color(0xFF059669), Color(0xFF34D399)],
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setS(() => saving = true);
                                try {
                                  final nuevoSaldo = double.tryParse(
                                          nuevoSaldoCtrl.text
                                              .trim()
                                              .replaceAll('.', '')
                                              .replaceAll(',', '.')) ??
                                      0.0;
                                  final diferencia = nuevoSaldo - saldoActual;
                                  final now = DateTime.now();
                                  String pad2(int n) =>
                                      n.toString().padLeft(2, '0');
                                  final fecha =
                                      '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
                                  final r = await _api
                                      .post('/ajax/ajustar_saldo_cuenta.php', {
                                    'codigo_cuenta': codigoCuenta,
                                    'saldo_actual':
                                        saldoActual.toStringAsFixed(2),
                                    'nuevo_saldo':
                                        nuevoSaldo.toStringAsFixed(2),
                                    'diferencia': diferencia.toStringAsFixed(2),
                                    'fecha': fecha,
                                    'usuario': codigoUsuario,
                                  });
                                  if (r.statusCode == 200) {
                                    final d = _json(r.body);
                                    final ok = d['success'] == true ||
                                        d['resultado'] == 1;
                                    if (ctx.mounted) {
                                      final messenger =
                                          ScaffoldMessenger.of(ctx);
                                      Navigator.pop(ctx);
                                      messenger.showSnackBar(SnackBar(
                                        content: Text(ok
                                            ? 'Saldo ajustado correctamente.'
                                            : (d['msg'] ??
                                                    d['mensaje'] ??
                                                    'Error al ajustar')
                                                .toString()),
                                        backgroundColor: ok
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ));
                                      if (ok) unawaited(_loadData());
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('[SAF] ajustar saldo: $e');
                                } finally {
                                  if (ctx.mounted) setS(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar Ajuste',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showTransferirDialog() async {
    final codigoUsuario = (_api.user?['codigo_usuario'] ?? '').toString();
    final formKey = GlobalKey<FormState>();
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final now = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    String selectedFecha = '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
    String? origenCod;
    String? origenNom;
    String? destinoCod;
    String? destinoNom;
    bool saving = false;

    final List<Map<String, dynamic>> cuentasOpts =
        _cuentas.where((c) => (c['estado'] ?? '').toString() == '1').toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget gradBtn({
          required List<Color> colors,
          required VoidCallback? onPressed,
          required Widget child,
        }) =>
            GestureDetector(
              onTap: onPressed,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            );

        Widget cuentaPicker({
          required String label,
          required String? nombre,
          required ValueChanged<Map<String, dynamic>> onPicked,
        }) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  if (cuentasOpts.isEmpty) return;
                  final picked = await showDialog<Map<String, dynamic>>(
                    context: ctx,
                    builder: (dCtx) => SimpleDialog(
                      backgroundColor: Colors.white,
                      title: Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D1B4B))),
                      children: cuentasOpts
                          .map((c) => SimpleDialogOption(
                                onPressed: () => Navigator.pop(dCtx, c),
                                child: Text(
                                  (c['nombre'] ?? '').toString(),
                                  style: const TextStyle(
                                      color: Color(0xFF374151),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                ),
                              ))
                          .toList(),
                    ),
                  );
                  if (picked != null) onPicked(picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text(nombre ?? '[Seleccione]',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: nombre != null
                                    ? const Color(0xFF0D1B4B)
                                    : const Color(0xFF9CA3AF),
                                fontSize: 14))),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6B7280)),
                  ]),
                ),
              ),
            ]);

        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Transferir entre Cuentas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D1B4B)))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF6B7280)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  cuentaPicker(
                    label: 'Cuenta Origen',
                    nombre: origenNom,
                    onPicked: (c) => setS(() {
                      origenCod = (c['codigo'] ?? '').toString();
                      origenNom = (c['nombre'] ?? '').toString();
                    }),
                  ),
                  const SizedBox(height: 14),
                  cuentaPicker(
                    label: 'Cuenta Destino',
                    nombre: destinoNom,
                    onPicked: (c) => setS(() {
                      destinoCod = (c['codigo'] ?? '').toString();
                      destinoNom = (c['nombre'] ?? '').toString();
                    }),
                  ),
                  const SizedBox(height: 14),
                  const Text('Valor a Transferir',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: valorCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),
                  const Text('Fecha de Transferencia',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(selectedFecha) ?? now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, w) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: Color(0xFF0D1B4B)),
                          ),
                          child: w!,
                        ),
                      );
                      if (picked != null) {
                        setS(() {
                          selectedFecha =
                              '${picked.year}-${pad2(picked.month)}-${pad2(picked.day)}';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            () {
                              final p = selectedFecha.split('-');
                              return p.length == 3
                                  ? '${p[2]}/${p[1]}/${p[0]}'
                                  : selectedFecha;
                            }(),
                            style: const TextStyle(
                                color: Color(0xFF0D1B4B), fontSize: 14),
                          ),
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: Color(0xFF6B7280)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Descripción (opcional)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ej: Transferencia para gastos de oficina',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                      child: gradBtn(
                        colors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: gradBtn(
                        colors: saving
                            ? [Colors.grey, Colors.grey]
                            : const [Color(0xFF059669), Color(0xFF34D399)],
                        onPressed: saving
                            ? null
                            : () async {
                                if (origenCod == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Seleccione cuenta origen'),
                                          backgroundColor: Color(0xFFDC2626)));
                                  return;
                                }
                                if (destinoCod == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Seleccione cuenta destino'),
                                          backgroundColor: Color(0xFFDC2626)));
                                  return;
                                }
                                if (origenCod == destinoCod) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Origen y destino no pueden ser iguales'),
                                          backgroundColor: Color(0xFFDC2626)));
                                  return;
                                }
                                if (!formKey.currentState!.validate()) return;
                                setS(() => saving = true);
                                try {
                                  final r = await _api
                                      .post('/ajax/transferir_cuentas.php', {
                                    'cuenta_origen': origenCod!,
                                    'cuenta_destino': destinoCod!,
                                    'valor': valorCtrl.text.trim(),
                                    'fecha': selectedFecha,
                                    'descripcion': descCtrl.text.trim(),
                                    'usuario': codigoUsuario,
                                  });
                                  if (r.statusCode == 200) {
                                    final d = _json(r.body);
                                    final ok = d['success'] == true ||
                                        d['resultado'] == 1;
                                    if (ctx.mounted) {
                                      final messenger =
                                          ScaffoldMessenger.of(ctx);
                                      Navigator.pop(ctx);
                                      messenger.showSnackBar(SnackBar(
                                        content: Text(ok
                                            ? 'Transferencia realizada correctamente.'
                                            : (d['msg'] ??
                                                    d['mensaje'] ??
                                                    'Error al transferir')
                                                .toString()),
                                        backgroundColor: ok
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ));
                                      if (ok) unawaited(_loadData());
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('[SAF] transferir: $e');
                                } finally {
                                  if (ctx.mounted) setS(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Realizar Transferencia',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showRegistrarMovimientoDialog() async {
    final codigoUsuario = (_api.user?['codigo_usuario'] ?? '').toString();
    final formKey = GlobalKey<FormState>();
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final now = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    String selectedFecha = '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
    String? selectedCuenta;
    String? selectedCuentaNombre;
    String? selectedTipo;
    String? selectedTipoNombre;
    bool saving = false;

    // Cuentas activas disponibles desde el estado actual
    final List<Map<String, dynamic>> cuentasOpts =
        _cuentas.where((c) => (c['estado'] ?? '').toString() == '1').toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget gradBtn({
          required List<Color> colors,
          required VoidCallback? onPressed,
          required Widget child,
        }) =>
            GestureDetector(
              onTap: onPressed,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            );

        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Registrar Movimiento',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0D1B4B))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Cuenta ──────────────────────────────────
                  const Text('Cuenta',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      if (cuentasOpts.isEmpty) return;
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: ctx,
                        builder: (dCtx) => SimpleDialog(
                          backgroundColor: Colors.white,
                          title: const Text('Seleccionar Cuenta',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1B4B))),
                          children: cuentasOpts
                              .map((c) => SimpleDialogOption(
                                    onPressed: () => Navigator.pop(dCtx, c),
                                    child: Text(
                                      (c['nombre'] ?? '').toString(),
                                      style: const TextStyle(
                                          color: Color(0xFF374151),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ))
                              .toList(),
                        ),
                      );
                      if (picked != null) {
                        setS(() {
                          selectedCuenta = (picked['codigo'] ?? '').toString();
                          selectedCuentaNombre =
                              (picked['nombre'] ?? '').toString();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedCuentaNombre ?? '[Seleccione]',
                              style: TextStyle(
                                  color: selectedCuenta != null
                                      ? const Color(0xFF0D1B4B)
                                      : const Color(0xFF9CA3AF),
                                  fontSize: 14)),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF6B7280)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Tipo de movimiento ───────────────────────
                  const Text('Tipo de movimiento',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final tiposM = [
                        {'codigo': '2', 'nombre': 'Gasto'},
                        {'codigo': '3', 'nombre': 'Ingreso'},
                      ];
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: ctx,
                        builder: (dCtx) => SimpleDialog(
                          backgroundColor: Colors.white,
                          title: const Text('Tipo de movimiento',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1B4B))),
                          children: tiposM
                              .map((t) => SimpleDialogOption(
                                    onPressed: () => Navigator.pop(dCtx, t),
                                    child: Text(
                                      (t['nombre'] ?? '').toString(),
                                      style: const TextStyle(
                                          color: Color(0xFF374151),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ))
                              .toList(),
                        ),
                      );
                      if (picked != null) {
                        setS(() {
                          selectedTipo = picked['codigo'];
                          selectedTipoNombre = picked['nombre'];
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedTipoNombre ?? '[Seleccione]',
                              style: TextStyle(
                                  color: selectedTipo != null
                                      ? const Color(0xFF0D1B4B)
                                      : const Color(0xFF9CA3AF),
                                  fontSize: 14)),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF6B7280)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Valor ────────────────────────────────────
                  const Text('Valor',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: valorCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Fecha ────────────────────────────────────
                  const Text('Fecha',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(selectedFecha) ?? now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, w) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: Color(0xFF0D1B4B)),
                          ),
                          child: w!,
                        ),
                      );
                      if (picked != null) {
                        setS(() {
                          selectedFecha =
                              '${picked.year}-${pad2(picked.month)}-${pad2(picked.day)}';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            () {
                              final p = selectedFecha.split('-');
                              return p.length == 3
                                  ? '${p[2]}/${p[1]}/${p[0]}'
                                  : selectedFecha;
                            }(),
                            style: const TextStyle(
                                color: Color(0xFF0D1B4B), fontSize: 14),
                          ),
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: Color(0xFF6B7280)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Descripción ──────────────────────────────
                  const Text('Descripción',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Botones ──────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: gradBtn(
                        colors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: gradBtn(
                        colors: saving
                            ? [Colors.grey, Colors.grey]
                            : const [Color(0xFF059669), Color(0xFF34D399)],
                        onPressed: saving
                            ? null
                            : () async {
                                if (selectedCuenta == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Seleccione una cuenta'),
                                          backgroundColor: Color(0xFFDC2626)));
                                  return;
                                }
                                if (selectedTipo == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Seleccione el tipo de movimiento'),
                                          backgroundColor: Color(0xFFDC2626)));
                                  return;
                                }
                                if (!formKey.currentState!.validate()) return;
                                setS(() => saving = true);
                                try {
                                  final r = await _api
                                      .post('/ajax/guardar_movimiento.php', {
                                    'codigo_cuenta': selectedCuenta!,
                                    'tipo_movimiento': selectedTipo!,
                                    'valor': valorCtrl.text.trim(),
                                    'fecha': selectedFecha,
                                    'descripcion': descCtrl.text.trim(),
                                    'usuario': codigoUsuario,
                                  });
                                  if (r.statusCode == 200) {
                                    final d = _json(r.body);
                                    final ok = d['success'] == true ||
                                        d['resultado'] == 1;
                                    if (ctx.mounted) {
                                      final messenger =
                                          ScaffoldMessenger.of(ctx);
                                      Navigator.pop(ctx);
                                      messenger.showSnackBar(SnackBar(
                                        content: Text(ok
                                            ? 'Movimiento registrado correctamente.'
                                            : (d['msg'] ??
                                                    d['mensaje'] ??
                                                    'Error al guardar')
                                                .toString()),
                                        backgroundColor: ok
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ));
                                      if (ok) {
                                        unawaited(_loadData());
                                      }
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('[SAF] guardar movimiento: $e');
                                } finally {
                                  if (ctx.mounted) setS(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showNuevaCuentaDialog() async {
    final codigoUsuario = (_api.user?['codigo_usuario'] ?? '').toString();
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    String selectedHex = '#3B3B8A';
    String? selectedTipo;
    String? selectedTipoNombre;
    bool saving = false;
    // Tipos con fallback hardcodeado — se cargan en background dentro del dialog
    List<Map<String, dynamic>> tipos = [
      {'codigo': '2', 'nombre': 'Gasto'},
      {'codigo': '3', 'nombre': 'Ingreso'},
    ];

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        // Carga real en background (solo una vez)
        if (tipos.length == 2 && tipos[0]['_loaded'] == null) {
          tipos[0]['_loaded'] = true;
          _api.post('/ajax/listado_select.php', {
            'tabla': 'tbl_cuentas_tipo',
            'valor': 'codigo',
            'etiqueta': 'nombre',
            'filtro': 'codigo=2 or codigo=3',
            'campos_orden': '',
          }).then((r) {
            if (r.statusCode == 200) {
              try {
                final raw = jsonDecode(r.body);
                final list = raw is List
                    ? raw
                    : (raw is Map && raw['datos'] is List
                        ? raw['datos']
                        : null);
                if (list != null && (list as List).isNotEmpty) {
                  if (ctx.mounted) {
                    setS(() {
                      tipos = (list)
                          .whereType<Map>()
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                    });
                  }
                }
              } catch (_) {}
            }
          });
        }
        Color parseHex(String hex) {
          try {
            return Color(
                int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
          } catch (_) {
            return const Color(0xFF3B3B8A);
          }
        }

        Widget gradBtn({
          required List<Color> colors,
          required VoidCallback? onPressed,
          required Widget child,
        }) =>
            GestureDetector(
              onTap: onPressed,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            );

        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(children: [
                    const Expanded(
                      child: Text('Nueva Cuenta/Fuente',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _navy)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20)),
                  ]),
                  const SizedBox(height: 16),

                  // Nombre
                  const Text('Nombre de la cuenta/fuente',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _navy)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej. Nequi, Efectivo...',
                      filled: true,
                      fillColor: const Color(0xFFF5F7FB),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),

                  // Color
                  const Text('Color (opcional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _navy)),
                  const SizedBox(height: 6),
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: parseHex(selectedHex),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetColors.map((hex) {
                      final sel = hex == selectedHex;
                      return GestureDetector(
                        onTap: () => setS(() => selectedHex = hex),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: parseHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: sel ? _navy : Colors.transparent,
                                width: 2),
                          ),
                          child: sel
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Tipo
                  const Text('Tipo de cuenta',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _navy)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: ctx,
                        builder: (dCtx) => SimpleDialog(
                          backgroundColor: Colors.white,
                          title: const Text('Seleccionar Tipo',
                              style: TextStyle(
                                  color: _navy, fontWeight: FontWeight.w700)),
                          children: tipos
                              .map((t) => SimpleDialogOption(
                                    onPressed: () => Navigator.pop(dCtx, t),
                                    child: Text(
                                      (t['nombre'] ?? '').toString(),
                                      style: const TextStyle(
                                        color: Color(0xFF374151),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      );
                      if (picked != null) {
                        setS(() {
                          selectedTipo = (picked['codigo'] ?? '').toString();
                          selectedTipoNombre =
                              (picked['nombre'] ?? '').toString();
                        });
                      }
                    },
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        border: Border.all(
                            color: selectedTipo != null
                                ? _accent1.withValues(alpha: 0.6)
                                : const Color(0xFFDDE3EF)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            selectedTipoNombre ?? '[Seleccione]',
                            style: TextStyle(
                                fontSize: 14,
                                color: selectedTipo != null
                                    ? _navy
                                    : const Color(0xFF6B7280)),
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            color: Color(0xFF9CA3AF), size: 20),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Botones
                  Row(children: [
                    Expanded(
                      child: gradBtn(
                        colors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: gradBtn(
                        colors: saving
                            ? [Colors.grey, Colors.grey]
                            : [
                                const Color(0xFF10B981),
                                const Color(0xFF059669)
                              ],
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }
                                if (selectedTipo == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Selecciona el tipo de cuenta')));
                                  return;
                                }
                                setS(() => saving = true);
                                try {
                                  final r = await _api
                                      .post('/ajax/guardar_cuenta_gasto.php', {
                                    'nombre': nombreCtrl.text.trim(),
                                    'color': selectedHex,
                                    'tipo_cuenta': selectedTipo!,
                                    'usuario': codigoUsuario,
                                  });
                                  final d = _json(r.body);
                                  if (d['success'] == true) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    unawaited(_fetchCuentas('1'));
                                    _snack(d['msg']?.toString() ??
                                        'Cuenta creada');
                                  } else {
                                    setS(() => saving = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  d['msg']?.toString() ??
                                                      'Error al guardar')));
                                    }
                                  }
                                } catch (e) {
                                  setS(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Guardar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      nombreCtrl.dispose();
    });
  }

  Future<void> _showEditarCuentaDialog(Map<String, dynamic> c) async {
    final codigoUsuario = (_api.user?['codigo_usuario'] ?? '').toString();
    final codigo = (c['codigo_cuenta'] ?? c['codigo'] ?? '').toString();
    final nombreCtrl =
        TextEditingController(text: (c['nombre'] ?? '').toString());
    String selectedHex =
        (c['color'] ?? '#4361EE').toString().replaceAll('#', '');
    if (selectedHex.length != 6) selectedHex = '4361EE';
    final colorCtrl = TextEditingController(text: selectedHex);

    String? selectedTipoCod = (c['codigo_tipo'] ?? c['tipo'] ?? '').toString();
    if (selectedTipoCod.isEmpty) selectedTipoCod = null;
    String selectedTipoNombre = (c['tipo_nombre'] ?? '').toString();
    bool tiposLoaded = false;
    bool loadingTipos = false;
    List<Map<String, dynamic>> tiposOpts = [];

    String selectedEstado = (c['estado']?.toString() == '1') ? '1' : '0';

    // Movimientos tab
    int activeTab = 0;
    bool movsLoaded = false;
    bool loadingMovs = false;
    List<Map<String, dynamic>> movsList = [];

    bool saving = false;

    Color parseHex(String hex) {
      try {
        final h = hex.replaceAll('#', '');
        if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      } catch (_) {}
      return _accent1;
    }

    Widget gradBtn({
      required List<Color> colors,
      required Widget child,
      required VoidCallback? onPressed,
    }) =>
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: onPressed == null
                ? null
                : LinearGradient(
                    colors: colors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
            color: onPressed == null ? const Color(0xFFCBD5E1) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: child,
          ),
        );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        // Cargar tipos
        if (!tiposLoaded && !loadingTipos) {
          loadingTipos = true;
          Future.microtask(() async {
            try {
              final r = await _api.post('/ajax/listado_select.php', {
                'tabla': 'tbl_tipos_cuentas',
                'valor': 'codigo_tipo',
                'etiqueta': 'nombre',
                'filtro': '1',
                'campos_orden': 'nombre ASC',
              });
              if (r.statusCode == 200) {
                final raw = jsonDecode(r.body);
                if (raw is List) {
                  tiposOpts = raw
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                }
              }
            } catch (_) {}
            setS(() {
              loadingTipos = false;
              tiposLoaded = true;
            });
          });
        }

        // Cargar movimientos cuando se cambia al tab 1
        if (activeTab == 1 && !movsLoaded && !loadingMovs) {
          loadingMovs = true;
          Future.microtask(() async {
            try {
              final r = await _api.post('/ajax/listar_movimientos_cuenta.php', {
                'codigo_cuenta': codigo,
                'pagina': '1',
                'usuario': codigoUsuario,
              });
              if (r.statusCode == 200) {
                final raw = jsonDecode(r.body);
                if (raw is List) {
                  movsList = raw
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                } else if (raw is Map) {
                  final d = raw['datos'] ?? raw['data'] ?? raw['movimientos'];
                  if (d is List) {
                    movsList = d
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                  }
                }
              }
            } catch (_) {}
            setS(() {
              loadingMovs = false;
              movsLoaded = true;
            });
          });
        }

        final previewColor = parseHex(colorCtrl.text);

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(480, MediaQuery.of(ctx).size.width - 40),
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Editar Cuenta/Fuente',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            Text('Modifica los datos de la cuenta',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    // Tabs dentro del header
                    Row(children: [
                      _editTab('Editar', 0, activeTab,
                          () => setS(() => activeTab = 0)),
                      _editTab('Movimientos', 1, activeTab,
                          () => setS(() => activeTab = 1)),
                    ]),
                  ]),
                ),

                // ── Contenido del tab ────────────────────────────────
                if (activeTab == 0) ...[
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ahorrField(
                            ctrl: nombreCtrl,
                            label: 'Nombre',
                            icon: Icons.label_outline_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingrese el nombre'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _ahorrFieldLabel('Color'),
                          const SizedBox(height: 6),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: previewColor,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFDDE3EF)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: previewColor,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFDDE3EF)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: colorCtrl,
                                style:
                                    const TextStyle(color: _navy, fontSize: 14),
                                decoration: InputDecoration(
                                  prefixText: '#',
                                  prefixStyle: const TextStyle(
                                      color: _accent1,
                                      fontWeight: FontWeight.bold),
                                  hintText: 'RRGGBB',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF9CA3AF), fontSize: 13),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F7FB),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFDDE3EF))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFDDE3EF))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: _accent1, width: 1.5)),
                                ),
                                maxLength: 6,
                                buildCounter: (_,
                                        {required currentLength,
                                        required isFocused,
                                        maxLength}) =>
                                    const SizedBox.shrink(),
                                onChanged: (v) => setS(() => selectedHex = v),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _presetColors.map((hex) {
                              final col = parseHex(hex);
                              final hx = hex.replaceAll('#', '').toUpperCase();
                              final active = colorCtrl.text.toUpperCase() == hx;
                              return GestureDetector(
                                onTap: () {
                                  colorCtrl.text = hx;
                                  setS(() => selectedHex = hx);
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: col,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          active ? _navy : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                          color: col.withValues(alpha: 0.4),
                                          blurRadius: 4)
                                    ],
                                  ),
                                  child: active
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 16)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          _ahorrFieldLabel('Tipo'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: !tiposLoaded
                                ? null
                                : () async {
                                    final picked =
                                        await showDialog<Map<String, dynamic>>(
                                      context: ctx,
                                      builder: (dCtx) => SimpleDialog(
                                        backgroundColor: Colors.white,
                                        title: const Text('Seleccionar Tipo',
                                            style: TextStyle(
                                                color: _navy,
                                                fontWeight: FontWeight.w700)),
                                        children: tiposOpts
                                            .map((t) => SimpleDialogOption(
                                                  onPressed: () =>
                                                      Navigator.pop(dCtx, t),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 4),
                                                    child: Text(
                                                      (t.values.last ?? '')
                                                          .toString(),
                                                      style: const TextStyle(
                                                          color: _navy,
                                                          fontSize: 14),
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    );
                                    if (picked != null) {
                                      setS(() {
                                        selectedTipoCod =
                                            picked.values.first.toString();
                                        selectedTipoNombre =
                                            picked.values.last.toString();
                                      });
                                    }
                                  },
                            child: _dateContainer(
                                selectedTipoNombre.isNotEmpty
                                    ? selectedTipoNombre
                                    : null,
                                '[Seleccione una Opción]'),
                          ),
                          const SizedBox(height: 16),
                          _ahorrFieldLabel('Estado'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDialog<String>(
                                context: ctx,
                                builder: (dCtx) => SimpleDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('Estado',
                                      style: TextStyle(
                                          color: _navy,
                                          fontWeight: FontWeight.w700)),
                                  children: [
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(dCtx, '1'),
                                      child: const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Activa',
                                              style: TextStyle(
                                                  color: _navy, fontSize: 14))),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(dCtx, '0'),
                                      child: const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Inactiva',
                                              style: TextStyle(
                                                  color: _navy, fontSize: 14))),
                                    ),
                                  ],
                                ),
                              );
                              if (picked != null) {
                                setS(() => selectedEstado = picked);
                              }
                            },
                            child: _dateContainer(
                                selectedEstado == '1' ? 'Activa' : 'Inactiva',
                                'Activa'),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  // Botones tab Editar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(children: [
                      gradBtn(
                        colors: const [Color(0xFFDC2626), Color(0xFFB91C1C)],
                        onPressed: saving
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (c2) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text('¿Desactivar cuenta?',
                                        style: TextStyle(color: _navy)),
                                    content: const Text(
                                        'La cuenta quedará inactiva.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c2, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c2, true),
                                        child: const Text('Desactivar',
                                            style: TextStyle(
                                                color: Color(0xFFDC2626))),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  setS(() => saving = true);
                                  final r = await _api.post(
                                    '/ajax/editar_cuenta_gasto.php',
                                    {
                                      'codigo': codigo,
                                      'nombre': nombreCtrl.text.trim(),
                                      'color':
                                          '#${colorCtrl.text.trim().toUpperCase()}',
                                      'tipo': selectedTipoCod ?? '',
                                      'estado': '0',
                                    },
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    bool ok = false;
                                    try {
                                      ok =
                                          jsonDecode(r.body)['success'] == true;
                                    } catch (_) {}
                                    showDialog(
                                      context: context,
                                      builder: (_) => _resultDialog(
                                          ok
                                              ? 'Cuenta desactivada'
                                              : 'No se pudo desactivar',
                                          ok),
                                    );
                                    if (ok) unawaited(_fetchCuentas('1'));
                                  }
                                }
                              },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.delete_outline_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Eliminar (Desactivar)',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      gradBtn(
                        colors: const [Color(0xFF16A34A), Color(0xFF15803D)],
                        onPressed: saving
                            ? null
                            : () async {
                                if (nombreCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ingrese el nombre'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }
                                setS(() => saving = true);
                                try {
                                  final r = await _api.post(
                                    '/ajax/editar_cuenta_gasto.php',
                                    {
                                      'codigo': codigo,
                                      'nombre': nombreCtrl.text.trim(),
                                      'color':
                                          '#${colorCtrl.text.trim().toUpperCase()}',
                                      'tipo': selectedTipoCod ?? '',
                                      'estado': selectedEstado,
                                    },
                                  );
                                  bool ok = false;
                                  String msg = 'No se pudo guardar';
                                  try {
                                    final j = jsonDecode(r.body.trim());
                                    ok = j['success'] == true;
                                    msg = (j['msg'] ?? msg).toString();
                                  } catch (_) {}
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => _resultDialog(
                                          ok ? 'Cambios guardados' : msg, ok),
                                    );
                                    if (ok) unawaited(_fetchCuentas('1'));
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setS(() => saving = false);
                                    ScaffoldMessenger.of(ctx)
                                        .showSnackBar(SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ));
                                  }
                                }
                              },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (saving)
                              const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                            else
                              const Icon(Icons.save_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(saving ? 'Guardando...' : 'Guardar Cambios'),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ] else ...[
                  // ── Tab Movimientos ────────────────────────────────
                  Flexible(
                    child: loadingMovs
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(color: _accent1),
                            ),
                          )
                        : movsList.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('Sin movimientos',
                                      style: TextStyle(
                                          color: Color(0xFF8899BB),
                                          fontSize: 14)),
                                ),
                              )
                            : Column(children: [
                                // Encabezado tabla
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  color: const Color(0xFFF5F7FB),
                                  child: Row(children: const [
                                    Expanded(
                                        flex: 3,
                                        child: Text('Fecha',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _navy))),
                                    Expanded(
                                        flex: 1,
                                        child: Text('Tipo',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _navy))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('Valor',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _navy))),
                                  ]),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount: movsList.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final m = movsList[i];
                                      final fecha = (m['fecha'] ??
                                              m['fecha_movimiento'] ??
                                              '')
                                          .toString();
                                      final tipo = (m['tipo'] ?? '').toString();
                                      final valor =
                                          _num(m['valor'] ?? m['monto'] ?? 0);
                                      final desc = (m['descripcion'] ??
                                              m['descripción'] ??
                                              '')
                                          .toString();
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                      fecha.split(' ').first,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: _navy))),
                                              Expanded(
                                                  flex: 1,
                                                  child: Text(tipo,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(
                                                              0xFF8899BB)))),
                                              Expanded(
                                                  flex: 2,
                                                  child: Text(_cop(valor),
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: valor >= 0
                                                              ? const Color(
                                                                  0xFF16A34A)
                                                              : const Color(
                                                                  0xFFDC2626)))),
                                            ]),
                                            if (desc.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Text(desc,
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Color(0xFF8899BB))),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: gradBtn(
                        colors: const [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      nombreCtrl.dispose();
      colorCtrl.dispose();
    });
  }

  Widget _editTab(String label, int index, int active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active == index ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active == index ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight: active == index ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      );

  Widget _cuentaRowReal(Map<String, dynamic> c) {
    final nombre = (c['nombre'] ?? 'Cuenta').toString();
    final tipo = (c['tipo_nombre'] ?? '').toString();
    final saldo = _num(c['saldo_actual'] ?? 0);
    final estado = c['estado']?.toString() == '1';
    final hexColor = (c['color'] ?? '#4361EE').toString();
    final color = _hexColor(hexColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14, color: _navy)),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                    child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tipo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 6),
                Text(estado ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                        color: estado
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF8899BB),
                        fontSize: 11)),
              ]),
            ],
          ),
        ),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_cop(saldo),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: saldo >= 0 ? _navy : const Color(0xFFDC2626))),
          const SizedBox(height: 6),
          Row(children: [
            _iconActionBtn(
              icon: Icons.edit_rounded,
              color: const Color(0xFF0EA5E9),
              onTap: () => _showEditarCuentaDialog(c),
            ),
            const SizedBox(width: 6),
            _iconActionBtn(
              icon: Icons.balance_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => _showAjustarSaldoDialog(c),
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _iconActionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      );

  Widget _movimientoItemReal(Map<String, dynamic> m, {bool divider = false}) {
    final desc = (m['descripcion'] ?? 'Movimiento').toString();
    final cuentaNom = (m['cuenta_nombre'] ?? '').toString();
    final hexColor = (m['cuenta_color'] ?? '#4361EE').toString();
    final color = _hexColor(hexColor);
    final tipo = (m['tipo_movimiento'] ?? '2').toString();
    // 2=Gasto, 3=Ingreso/Transferencia, 1=otro
    final isIngreso = tipo == '3' || tipo == '1';
    final valor = _num(m['valor'] ?? 0);
    final rawFecha = (m['fecha'] ?? '').toString();
    final fecha = rawFecha.length >= 10 ? rawFecha.substring(0, 10) : rawFecha;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      Color.lerp(color, Colors.white, 0.35)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  isIngreso
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              Positioned(
                left: -3,
                bottom: -3,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: _navy)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cuentaNom.isNotEmpty ? cuentaNom : 'Cuenta SAF',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF7181A6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFB6C0D5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      fecha,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF9AA7C2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${isIngreso ? '+' : '-'}${_cop(valor)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: isIngreso
                      ? const Color(0xFF0E9F6E)
                      : const Color(0xFFE02424),
                ),
              ),
              const SizedBox(height: 5),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isIngreso
                          ? [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)]
                          : [const Color(0xFFFFE4E6), const Color(0xFFFCA5A5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isIngreso
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFFFCA5A5),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isIngreso ? 'Ingreso' : 'Gasto',
                    style: TextStyle(
                      color: isIngreso
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _confirmEliminarMovimiento(m),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 14, color: Color(0xFFDC2626)),
                  ),
                ),
              ]),
            ],
          ),
        ]),
      ),
      if (divider)
        Divider(
            height: 1,
            thickness: 1,
            indent: 70,
            endIndent: 16,
            color: const Color(0xFFE9EDF5)),
    ]);
  }

  Future<void> _confirmEliminarMovimiento(Map<String, dynamic> m) async {
    final ctx = context;
    final desc = (m['descripcion'] ?? 'este movimiento').toString();
    // PK field is 'codigo' as returned by listar_movimientos_cuenta.php
    final cod = (m['codigo'] ??
            m['codigo_movimiento'] ??
            m['id'] ??
            '')
        .toString()
        .trim();

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('¿Eliminar movimiento?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1B4B))),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 6),
            const Text('Esta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dCtx, false),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: Color(0xFF374151))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dCtx, true),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                          blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Text('Eliminar',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed != true) return;
    debugPrint('[SAF] eliminar movimiento keys: ${m.keys.toList()} cod=$cod');
    if (cod.isEmpty) {
      debugPrint('[SAF] No se encontró el código del movimiento');
      return;
    }
    try {
      await _api.post('/ajax/actualizar_registro.php', {
        'tabla': 'tbl_movimientos',
        'filtro': 'codigo_movimiento=$cod',
        'modo': 'eliminar',
      });
      if (mounted) {
        setState(() {
          _movimientos.removeWhere(
              (x) => (x['codigo'] ?? x['codigo_movimiento'] ?? x['id'] ?? '')
                      .toString()
                      .trim() ==
                  cod);
        });
      }
    } catch (e) {
      debugPrint('[SAF] eliminar movimiento: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  ESTADÍSTICA TAB
  // ══════════════════════════════════════════════════════════════
  // Definición de las 8 sub-pestañas: (título, codigo_consulta, columnas)
  // Cada columna: (encabezado, clave en el JSON, alineadoDerecha)
  static const List<(String, String, List<(String, String, bool)>)> _estTabs = [
    (
      'Pagan Puntual',
      'json_est_pagan_puntual',
      [
        ('Cliente', 'cliente', false),
        ('Créditos', 'cantidad', true),
        ('A tiempo', 'puntuales', true),
        ('% Puntual', 'porcentaje', true),
      ]
    ),
    (
      'Más Créditos',
      'json_est_mas_creditos',
      [
        ('Cliente', 'cliente', false),
        ('Cantidad', 'cantidad', true),
        ('Monto Total', 'monto', true),
      ]
    ),
    (
      'Mayor Monto',
      'json_est_mayor_monto',
      [
        ('Cliente', 'cliente', false),
        ('Créditos', 'cantidad', true),
        ('Monto Total', 'monto', true),
      ]
    ),
    (
      'Mayor Antigüedad',
      'json_est_mayor_antiguedad',
      [
        ('Cliente', 'cliente', false),
        ('Primer Crédito', 'fecha', false),
        ('Antigüedad', 'antiguedad', true),
      ]
    ),
    (
      'Más Retrasos',
      'json_est_mas_retrasos',
      [
        ('Cliente', 'cliente', false),
        ('Créditos', 'cantidad', true),
        ('Retrasos', 'retrasos', true),
      ]
    ),
    (
      'Nuevos Clientes',
      'json_est_nuevos_clientes',
      [
        ('Cliente', 'cliente', false),
        ('Fecha Ingreso', 'fecha', false),
        ('Primer Monto', 'monto', true),
      ]
    ),
    (
      'Mejor Scoring',
      'listado_mejor_scoring',
      [
        ('Cliente', 'cliente', false),
        ('Cantidad de Créditos', 'cantidad_creditos', true),
        ('Puntaje Total', 'puntaje_total', true),
        ('Índice Promedio', 'indice_promedio', true),
      ]
    ),
    (
      'Pagos Anticipados',
      'json_est_pagos_anticipados',
      [
        ('Cliente', 'cliente', false),
        ('Créditos', 'cantidad', true),
        ('Anticipados', 'anticipados', true),
      ]
    ),
  ];

  Widget _estadisticaTab() {
    const navy = Color(0xFF0D1B4B);
    final cols = _estTabs[_estSubTab].$3;

    // Filtro independiente por cada columna (como la web)
    final filtrados = _estData.where((r) {
      for (final c in cols) {
        final f = (_estFiltros[c.$2] ?? '').trim().toLowerCase();
        if (f.isEmpty) continue;
        final val = (r[c.$2] ?? '').toString().toLowerCase();
        if (!val.contains(f)) return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text('Estadísticas',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
          ),
          const SizedBox(height: 14),

          // ── Grid de sub-pestañas (2 columnas) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_estTabs.length, (i) {
                final activo = i == _estSubTab;
                return GestureDetector(
                  onTap: () {
                    if (i == _estSubTab) return;
                    setState(() {
                      _estSubTab = i;
                      _estFiltros.clear();
                      _estPage = 0;
                    });
                    _fetchEstadistica();
                  },
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: activo ? navy : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: activo ? navy : const Color(0xFFCBD5E1),
                        width: 1.4,
                      ),
                      boxShadow: activo
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _estTabs[i].$1,
                            style: TextStyle(
                              color: activo
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontWeight:
                                  activo ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18,
                            color: activo
                                ? Colors.white70
                                : const Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 18),

          // ── Filtros por columna ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in cols)
                  SizedBox(
                    width: cols.length <= 2
                        ? double.infinity
                        : (MediaQuery.of(context).size.width - 50) / 2,
                    child: _estFiltroInput(c),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Tabla / Tarjetas ─────────────────────────────────
          if (_estLoading)
            const Padding(
              padding: EdgeInsets.all(50),
              child: Center(child: CircularProgressIndicator(color: navy)),
            )
          else if (filtrados.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  _estData.isEmpty
                      ? 'Sin datos para esta estadística'
                      : 'Sin resultados para los filtros aplicados',
                  style: const TextStyle(color: Color(0xFF8899BB)),
                ),
              ),
            )
          else
            _estListaPaginada(cols, filtrados),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Campo de filtro para una columna. El placeholder imita la web:
  // "Buscar cliente" para la 1ª, "Filtrar <columna>" para las demás.
  Widget _estFiltroInput((String, String, bool) col) {
    const navy = Color(0xFF0D1B4B);
    final esCliente = col.$2 == 'cliente';
    final hint =
        esCliente ? 'Buscar cliente' : 'Filtrar ${col.$1.toLowerCase()}';
    return TextField(
      // El key incluye la pestaña: al cambiar de sub-pestaña el campo se
      // recrea vacío (sin necesidad de un controller que haya que liberar).
      key: ValueKey('estfiltro_${_estSubTab}_${col.$2}'),
      keyboardType: col.$3 ? TextInputType.number : TextInputType.text,
      onChanged: (v) {
        _filterDebounce?.cancel();
        _filterDebounce = Timer(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() {
            if (v.isEmpty) {
              _estFiltros.remove(col.$2);
            } else {
              _estFiltros[col.$2] = v;
            }
            _estPage = 0;
          });
        });
      },
      style: const TextStyle(fontSize: 13, color: navy),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
        prefixIcon: esCliente
            ? const Icon(Icons.search_rounded,
                color: Color(0xFF8899BB), size: 18)
            : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
      ),
    );
  }

  // Lista de tarjetas compactas + controles de paginación.
  Widget _estListaPaginada(
      List<(String, String, bool)> cols, List<Map<String, dynamic>> rows) {
    final totalPaginas = (rows.length / _estPorPagina).ceil();
    final pagina = _estPage.clamp(0, totalPaginas - 1);
    final inicio = pagina * _estPorPagina;
    final fin = (inicio + _estPorPagina).clamp(0, rows.length);
    final visibles = rows.sublist(inicio, fin);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < visibles.length; i++)
                _estCard(cols, visibles[i], inicio + i + 1),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Contador "Mostrando X a Y de Z"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mostrando ${inicio + 1} a $fin de ${rows.length}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8899BB)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _estPaginacion(pagina, totalPaginas),
      ],
    );
  }

  Widget _estCard(
      List<(String, String, bool)> cols, Map<String, dynamic> row, int rank) {
    const navy = Color(0xFF0D1B4B);
    final cliente = (row[cols.first.$2] ?? '').toString().trim();
    final metricas = cols.skip(1).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: rank <= 3
                  ? Text(
                      rank == 1
                          ? '🥇'
                          : rank == 2
                              ? '🥈'
                              : '🥉',
                      style: const TextStyle(fontSize: 16))
                  : Text('$rank',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: navy)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(cliente,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: navy)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final c in metricas)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF8899BB),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text((row[c.$2] ?? '—').toString(),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4361EE))),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estPaginacion(int pagina, int totalPaginas) {
    const navy = Color(0xFF0D1B4B);
    if (totalPaginas <= 1) return const SizedBox.shrink();

    // Ventana de páginas a mostrar (máx 5 números alrededor de la actual)
    final List<int> numeros = [];
    int desde =
        (pagina - 2).clamp(0, (totalPaginas - 5).clamp(0, totalPaginas));
    int hasta = (desde + 5).clamp(0, totalPaginas);
    for (var p = desde; p < hasta; p++) {
      numeros.add(p);
    }

    Widget chip(String label, {VoidCallback? onTap, bool activo = false}) {
      final habilitado = onTap != null;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: activo ? navy : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: activo ? navy : const Color(0xFFCBD5E1), width: 1.2),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                color: activo
                    ? Colors.white
                    : habilitado
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1),
              )),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        chip('‹ Ant',
            onTap: pagina > 0
                ? () => setState(() => _estPage = pagina - 1)
                : null),
        if (desde > 0) ...[
          chip('1', onTap: () => setState(() => _estPage = 0)),
          if (desde > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: TextStyle(color: Color(0xFF8899BB))),
            ),
        ],
        for (final p in numeros)
          chip('${p + 1}',
              activo: p == pagina,
              onTap: p == pagina ? null : () => setState(() => _estPage = p)),
        if (hasta < totalPaginas) ...[
          if (hasta < totalPaginas - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: TextStyle(color: Color(0xFF8899BB))),
            ),
          chip('$totalPaginas',
              onTap: () => setState(() => _estPage = totalPaginas - 1)),
        ],
        chip('Sig ›',
            onTap: pagina < totalPaginas - 1
                ? () => setState(() => _estPage = pagina + 1)
                : null),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BOTTOM NAV — Dark premium style
  // ══════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Inicio'),
      (Icons.credit_card_rounded, Icons.credit_card_outlined, 'Créditos'),
      (Icons.savings_rounded, Icons.savings_outlined, 'Ahorros'),
      (Icons.swap_horiz_rounded, Icons.swap_horiz_outlined, 'Movimientos'),
      (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Estadística'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.55),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == _selectedIndex;
              final color = _navColors[i];
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    // Al entrar a Estadística por primera vez, cargar datos.
                    if (i == 4 && _estData.isEmpty && !_estLoading) {
                      _fetchEstadistica();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        width: 46,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(
                                  color: color.withValues(alpha: 0.3), width: 1)
                              : null,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            selected ? item.$1 : item.$2,
                            key: ValueKey('${i}_$selected'),
                            color: selected
                                ? color
                                : Colors.white.withValues(alpha: 0.38),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          color: selected
                              ? color
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: 9.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          letterSpacing: selected ? 0.2 : 0,
                        ),
                        child: Text(item.$3),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: selected ? 20 : 0,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.6),
                                      blurRadius: 6)
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BALANCE CARD
  // ══════════════════════════════════════════════════════════════
  Widget _buildBalanceCard(String greeting, String name) {
    final saldo = _totalSaldo;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF060E35),
            Color(0xFF0D1B6E),
            Color(0xFF1A3A9F),
            Color(0xFF0099CC),
          ],
          stops: [0.0, 0.4, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _accent1.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                          )),
                      const SizedBox(height: 2),
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  )),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00FF9D),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('Activo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Total de Saldos',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  )),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _balanceVisible
                        ? Text(_cop(saldo),
                            key: const ValueKey('v'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ))
                        : const Text('• • • • • •',
                            key: ValueKey('h'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            )),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _balanceVisible = !_balanceVisible),
                    child: Icon(
                      _balanceVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _balanceMini(
                      Icons.savings_rounded,
                      'Ahorros',
                      _cop(_ahorradores.fold(
                          0.0,
                          (s, a) =>
                              s +
                              _num(a['total_ahorrado'] ?? a['monto'] ?? 0)))),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 14)),
                  _balanceMini(Icons.credit_score_rounded, 'Créditos',
                      _creditos.length.toString()),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 14)),
                  _balanceMini(Icons.people_alt_rounded, 'Ahorradores',
                      _ahorradores.length.toString()),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _balanceMini(IconData icon, String label, String value) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 15),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _dashboardSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    String? action,
    VoidCallback? onAction,
    List<Color>? gradient,
  }) {
    final grad = gradient ?? [_accent1, _accent2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: grad,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: grad.first.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8899BB),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (action != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent1, _accent2],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _accent1.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 13, color: Colors.white),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    String? badge,
    Color? valueColor,
  }) {
    final c1 = color;
    final c2 = Color.lerp(color, Colors.black, 0.18)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(
        scale: 0.88 + 0.12 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        height: 130,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: c1.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(children: [
          // Large arc — top-right corner anchor
          Positioned(
            right: -45,
            top: -45,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          // Inner arc — inset from top-right
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Small dot — bottom left accent
          Positioned(
            left: -16,
            bottom: -16,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static const _cuentaPalette = [
    (Color(0xFF4361EE), Color(0xFF93C5FD)), // indigo → blue
    (Color(0xFF059669), Color(0xFF6EE7B7)), // emerald → mint
    (Color(0xFF4361EE), Color(0xFFC4B5FD)), // violet → lavender
    (Color(0xFFF59E0B), Color(0xFFFDE68A)), // amber → yellow
    (Color(0xFFDC2626), Color(0xFFFCA5A5)), // red → rose
    (Color(0xFF0891B2), Color(0xFF67E8F9)), // cyan → sky
    (Color(0xFFDB2777), Color(0xFFF9A8D4)), // pink → blush
    (Color(0xFF65A30D), Color(0xFFBEF264)), // lime → chartreuse
  ];

  Widget _cuentaChip(Map<String, dynamic> c, {int index = 0}) {
    final nombre = (c['nombre'] ?? c['name'] ?? 'Cuenta').toString();
    final tipo = (c['tipo'] ?? c['type'] ?? '').toString().toLowerCase();
    final saldo = _num(c['saldo_actual'] ?? c['saldo'] ?? 0);
    final hexColor = (c['color'] ?? '').toString();
    final color = hexColor.isNotEmpty
        ? _hexColor(hexColor)
        : _cuentaPalette[index % _cuentaPalette.length].$1;
    final gradEnd = Color.lerp(color, Colors.white, 0.45)!;

    return Container(
      width: 154,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(Colors.white, gradEnd, 0.30)!,
            Color.lerp(Colors.white, gradEnd, 0.85)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -18,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child:
                        Icon(_cuentaIcon(tipo), color: Colors.white, size: 17),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      saldo >= 0 ? 'Activa' : 'Revisar',
                      style: TextStyle(
                        color: color,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color.withValues(alpha: 0.85))),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_cop(saldo),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: saldo >= 0 ? _navy : const Color(0xFFDC2626))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditoCard(Map<String, dynamic> c) {
    final cod = c['cod']?.toString() ?? '';
    final asesor = (() {
      final nombre = (c['asesor'] ?? '').toString().trim();
      final aCod = (c['asesor_cod'] ?? '').toString().trim();
      return nombre.isNotEmpty ? nombre : aCod;
    })();
    final nombre = (c['cliente'] ?? 'Cliente').toString();
    final monto = _num(c['valor_prestamo'] ?? 0);
    final totalPagar = _num(c['total_pagar'] ?? 0);
    final numCuotas = c['num_cuotas']?.toString() ?? '';
    final tipo = (c['tipo'] ?? '').toString();
    final pagado = _num(c['total_pagado'] ?? 0);
    final pendiente = _num(c['saldo_pendiente'] ?? 0);
    final fecha = (c['fecha_prestamo'] ?? '').toString();
    final proxima = (c['proxima_fecha'] ?? '').toString();
    final estado = (c['estado'] ?? 'Activo').toString();
    final activo = estado.toLowerCase().contains('activ');

    bool vencido = false;
    if (activo && proxima.isNotEmpty) {
      try {
        vencido = DateTime.parse(proxima).isBefore(DateTime.now());
      } catch (_) {}
    }

    final cardKey = cod.isNotEmpty ? cod : nombre;
    final expanded = _expandedCreditos.contains(cardKey);

    final Color accent = !activo
        ? const Color(0xFF16A34A)
        : vencido
            ? const Color(0xFFDC2626)
            : _navy;

    final Color cardBg = !activo
        ? const Color(0xFFF0FDF4)
        : vencido
            ? const Color(0xFFFFF5F5)
            : Colors.white;

    final Color borderColor = !activo
        ? const Color(0xFF86EFAC)
        : vencido
            ? const Color(0xFFFCA5A5)
            : const Color(0xFFE2E8F0);

    final Color estadoColor = !activo
        ? const Color(0xFF16A34A)
        : vencido
            ? const Color(0xFFB71C1C)
            : _navy;

    final Color estadoBg = !activo
        ? const Color(0xFFDCFCE7)
        : vencido
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFF3F4F6);

    final initials = nombre
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    final progress =
        totalPagar > 0 ? (pagado / totalPagar).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => setState(() => expanded
          ? _expandedCreditos.remove(cardKey)
          : _expandedCreditos.add(cardKey)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: expanded ? 0.12 : 0.05),
              blurRadius: expanded ? 16 : 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header (siempre visible) ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text(initials,
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 15))),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (cod.isNotEmpty)
                        Text('#$cod',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8899BB),
                                fontWeight: FontWeight.w600)),
                      if (cod.isNotEmpty && asesor.isNotEmpty)
                        const SizedBox(width: 6),
                      if (asesor.isNotEmpty)
                        Flexible(
                            child: Text('· $asesor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF8899BB)))),
                    ]),
                  ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: estadoBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(estado,
                      style: TextStyle(
                          color: estadoColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8899BB),
                    size: 18),
              ]),
            ]),
          ),

          // ── Pendiente + Próxima cuota ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('PENDIENTE',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF8899BB),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_cop(pendiente),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: pendiente > 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A))),
                  ])),
              if (proxima.isNotEmpty)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('PRÓX. CUOTA',
                      style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF8899BB),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(proxima,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: vencido ? const Color(0xFFDC2626) : _navy)),
                ]),
            ]),
          ),

          // ── Barra de progreso ─────────────────────────────────
          if (totalPagar > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${(progress * 100).toStringAsFixed(0)}% pagado',
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFF8899BB))),
                          if (numCuotas.isNotEmpty || tipo.isNotEmpty)
                            Text(
                                [
                                  if (numCuotas.isNotEmpty) '$numCuotas cuotas',
                                  if (tipo.isNotEmpty) tipo
                                ].join(' · '),
                                style: const TextStyle(
                                    fontSize: 9, color: Color(0xFF8899BB))),
                        ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? const Color(0xFF16A34A) : accent),
                      ),
                    ),
                  ]),
            ),

          // ── Detalle expandido ─────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(children: [
                  Expanded(child: _statMini('Crédito', _cop(monto), _navy)),
                  Expanded(
                      child: _statMini('A Pagar', _cop(totalPagar), _navy)),
                  Expanded(
                      child: _statMini(
                          'Pagado', _cop(pagado), const Color(0xFF16A34A))),
                  Expanded(
                      child: _statMini('Pendiente', _cop(pendiente),
                          const Color(0xFFDC2626))),
                ]),
              ),
              if (fecha.isNotEmpty || tipo.isNotEmpty || numCuotas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    if (fecha.isNotEmpty)
                      _infoBadge(Icons.calendar_today_rounded, fecha),
                    if (tipo.isNotEmpty) _infoBadge(Icons.repeat_rounded, tipo),
                    if (numCuotas.isNotEmpty)
                      _infoBadge(Icons.format_list_numbered_rounded,
                          '$numCuotas cuotas'),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(children: [
                  Expanded(
                      child: _miniActionBtn(Icons.list_alt_rounded, 'Cuotas',
                          _navy, () => _showCuotasDialog(c))),
                  const SizedBox(width: 6),
                  _whatsAppBtn(() => _enviarRecordatorioWhatsApp(c)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _miniActionBtn(
                          Icons.verified_outlined,
                          'Paz y Salvo',
                          const Color(0xFF2563EB),
                          () => _showPazYSalvoDialog(c))),
                  const SizedBox(width: 6),
                  _miniIconBtn(
                      Icons.delete_outline_rounded,
                      const Color(0xFFDC2626),
                      () => _confirmarEliminarCredito(c)),
                ]),
              ),
            ]),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ]),
      ),
    );
  }

  Widget _statMini(String label, String value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8899BB),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ]);

  Widget _infoBadge(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF0F2FA),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: const Color(0xFF8899BB)),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 10, color: _navy, fontWeight: FontWeight.w600)),
      ]));

  Widget _miniActionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    final colorDark = Color.lerp(color, Colors.black, 0.22) ?? color;
    return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, colorDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: colorDark.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ));
  }

  Widget _miniIconBtn(IconData icon, Color color, VoidCallback onTap) {
    final colorDark = Color.lerp(color, Colors.black, 0.22) ?? color;
    return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, colorDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: colorDark.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ));
  }

  Widget _pendienteCard(Map<String, dynamic> p) {
    final cod = (p['codigo_solicitud'] ?? p['cod'] ?? '').toString();
    final solicitante = ([p['nombres'], p['apellidos']]
            .where((x) => x != null && x.toString().isNotEmpty)
            .join(' '))
        .trim();
    final doc = (p['num_documento'] ?? p['documento'] ?? '').toString();
    final email = (p['email'] ?? p['correo'] ?? '').toString();
    final tel = (p['telefono'] ?? '').toString();
    final valor = _num(p['valor_solicitado'] ?? p['valor_prestamo'] ?? 0);
    final numCuotas = (p['num_cuotas'] ?? '').toString();
    final tiempoRaw = (p['tiempo_cuota'] ?? p['tipo_cuota'] ?? '').toString();
    final tipo = tiempoRaw == '1'
        ? 'Mensual'
        : tiempoRaw == '2'
            ? 'Quincenal'
            : tiempoRaw == '4'
                ? 'Semanal'
                : tiempoRaw == '30'
                    ? 'Diario'
                    : tiempoRaw;
    final interes = (p['tasa_interes'] ?? p['interes'] ?? '').toString();
    final codigoAsesor = (p['codigo_asesor'] ?? '').toString().trim();
    final nombreAsesor = (p['nombre_asesor'] ?? codigoAsesor).toString().trim();
    final estadoCod = int.tryParse(p['codigo_estado']?.toString() ?? '0') ?? 0;

    // Verde = asesor asignado, Rojo = rechazado (estado 3), Blanco = pendiente
    final tieneAsesor = codigoAsesor.isNotEmpty;
    final rechazado = estadoCod == 3;
    final cardBg = rechazado
        ? const Color(0xFFFFCDD2)
        : tieneAsesor
            ? const Color(0xFFC8E6C9)
            : Colors.white;
    final cardBorder = rechazado
        ? const Color(0xFFEF9A9A)
        : tieneAsesor
            ? const Color(0xFFA5D6A7)
            : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Nombre + cod
        Row(children: [
          Expanded(
              child: Text(solicitante.isNotEmpty ? solicitante : 'Sin nombre',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _navy))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8)),
            child: Text('#$cod',
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 2, children: [
          if (doc.isNotEmpty) _cTag('Doc', doc),
          if (tel.isNotEmpty) _cTag('Tel', tel),
          if (tipo.isNotEmpty) _cTag('Tipo', tipo),
          if (numCuotas.isNotEmpty) _cTag('Cuotas', numCuotas),
          if (interes.isNotEmpty) _cTag('Interés', '$interes%'),
          if (nombreAsesor.isNotEmpty) _cTag('Asesor', nombreAsesor),
        ]),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(email,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFD1D5DB)),
        const SizedBox(height: 8),
        // Valor + botones según estado
        Row(children: [
          Expanded(
              child: Text(_cop(valor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _navy))),
          // Lápiz editar (siempre visible)
          _miniIconBtn(
              Icons.edit_rounded, _navy, () => _showEditarSolicitudDialog(p)),
          const SizedBox(width: 8),
          // Aprobado (verde): solo Rechazar
          if (tieneAsesor && !rechazado)
            _accionBtn(Icons.cancel_outlined, 'Rechazar',
                const Color(0xFFDC2626), () => _rechazarSolicitud(p))
          // Rechazado (rojo): solo Aprobar
          else if (rechazado)
            _accionBtn(Icons.check_circle_outline_rounded, 'Aprobar',
                const Color(0xFF16A34A), () => _aprobarSolicitud(p))
          // Pendiente (blanco): Aprobar + Rechazar
          else ...[
            _accionBtn(Icons.check_circle_outline_rounded, 'Aprobar',
                const Color(0xFF16A34A), () => _aprobarSolicitud(p)),
            const SizedBox(width: 8),
            _accionBtn(Icons.cancel_outlined, 'Rechazar',
                const Color(0xFFDC2626), () => _rechazarSolicitud(p)),
          ],
        ]),
      ]),
    );
  }

  void _showEditarSolicitudDialog(Map<String, dynamic> p) {
    final formKey = GlobalKey<FormState>();
    final cod = (p['codigo_solicitud'] ?? '').toString();
    final docCtrl = TextEditingController(
        text: (p['num_documento'] ?? p['documento'] ?? '').toString());
    final nombresCtrl =
        TextEditingController(text: (p['nombres'] ?? '').toString().trim());
    final apellidosCtrl =
        TextEditingController(text: (p['apellidos'] ?? '').toString().trim());
    final dirCtrl =
        TextEditingController(text: (p['direccion'] ?? '').toString());
    final emailCtrl = TextEditingController(
        text: (p['email'] ?? p['correo'] ?? '').toString());
    final telCtrl =
        TextEditingController(text: (p['telefono'] ?? '').toString());
    final valorCtrl = TextEditingController(
        text: (p['valor_solicitado'] ?? p['valor_prestamo'] ?? '').toString());
    final cuotasCtrl =
        TextEditingController(text: (p['num_cuotas'] ?? '').toString());

    // Asesor
    final asesorRaw = (p['codigo_asesor'] ?? '').toString().trim();
    String? selectedAsesor = asesorRaw.isEmpty ? null : asesorRaw;

    // Tiempo cuota: código → label
    final tiempoRaw = (p['tiempo_cuota'] ?? p['tipo_cuota'] ?? '').toString();
    String? selectedTiempo = tiempoRaw == '1'
        ? 'Mensual'
        : tiempoRaw == '2'
            ? 'Quincenal'
            : tiempoRaw == '4'
                ? 'Semanal'
                : tiempoRaw == '30'
                    ? 'Diario'
                    : tiempoRaw.isNotEmpty
                        ? tiempoRaw
                        : null;
    const tiempoOpciones = ['Mensual', 'Quincenal', 'Semanal', 'Diario'];
    const tiempoMap = {
      'Mensual': '1',
      'Quincenal': '2',
      'Semanal': '4',
      'Diario': '30'
    };

    // Fuente
    final fuenteRaw =
        (p['codigo_fuente'] ?? p['fuente'] ?? '').toString().trim();
    String? selectedFuente = fuenteRaw.isEmpty ? null : fuenteRaw;

    bool saving = false;
    bool listsLoaded = _fuentesLista.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (!listsLoaded) {
          listsLoaded = true;
          Future(() async {
            await Future.wait([
              if (_fuentesLista.isEmpty) _fetchFuentes(),
              if (_asesoresLista.isEmpty) _fetchAsesores(),
            ]);
            if (ctx.mounted) setS(() {});
          });
        }

        List<String> fuenteOpciones() {
          if (_fuentesLista.isNotEmpty) {
            return _fuentesLista
                .map((f) => (f['fuente'] ?? f['nombre'] ?? '').toString())
                .where((f) => f.isNotEmpty)
                .toList();
          }
          return [
            'Davivienda',
            'Bancolombia',
            'Daviplata',
            'Nequi',
            'Efectivo',
            'Préstamos',
            'SAF Ahorros'
          ];
        }

        Future<void> grabar() async {
          if (!formKey.currentState!.validate()) return;
          setS(() => saving = true);
          try {
            final tiempoCod = tiempoMap[selectedTiempo] ?? selectedTiempo ?? '';
            final r = await _api.post('/ajax/actualizar_registro.php', {
              'tabla': 'tbl_solicitudes_credito',
              'filtro': 'codigo_solicitud=$cod',
              'modo': 'editar',
              'codigo_asesor': selectedAsesor ?? '',
              'num_documento': docCtrl.text.trim(),
              'nombres': nombresCtrl.text.trim(),
              'apellidos': apellidosCtrl.text.trim(),
              'direccion': dirCtrl.text.trim(),
              'email': emailCtrl.text.trim(),
              'telefono': telCtrl.text.trim(),
              'fuente': selectedFuente ?? '',
              'valor_solicitado': valorCtrl.text.trim(),
              'tiempo_cuota': tiempoCod,
              'num_cuotas': cuotasCtrl.text.trim(),
            });
            final ok =
                r.statusCode == 200 && !r.body.toLowerCase().contains('error');
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              showDialog(
                  context: context,
                  builder: (_) => _resultDialog(
                      ok
                          ? 'Solicitud actualizada correctamente'
                          : r.body.trim(),
                      ok));
              if (ok) {
                await _fetchPendientes();
                if (mounted) setState(() {});
              }
            }
          } catch (e) {
            setS(() => saving = false);
            if (ctx.mounted) {
              showDialog(
                  context: ctx,
                  builder: (_) => _resultDialog('Error: $e', false));
            }
          }
        }

        // Helpers de estilo
        const indigo = Color(0xFF0D1B4B);
        const accentBlue = Color(0xFF1A3170);
        const borderCol = Color(0xFFE2E8F0);
        const hintCol = Color(0xFF94A3B8);
        const bgField = Color(0xFFF8F9FC);

        InputDecoration fieldDeco(String label, IconData icon) =>
            InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 12, color: hintCol),
              prefixIcon: Icon(icon, size: 16, color: hintCol),
              filled: true,
              fillColor: bgField,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: borderCol)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: accentBlue, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEF4444))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            );

        Widget field(String label, TextEditingController ctrl, IconData icon,
                {TextInputType? kb, bool required = false}) =>
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: ctrl,
                  keyboardType: kb,
                  decoration: fieldDeco(label, icon),
                  style: const TextStyle(fontSize: 13, color: _navy),
                  validator: required
                      ? (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null
                      : null,
                ));

        Widget dropdown<T>(String label, IconData icon, T? val,
                List<DropdownMenuItem<T>> items, ValueChanged<T?> onChange) =>
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<T>(
                  initialValue: val,
                  items: items,
                  onChanged: onChange,
                  decoration: fieldDeco(label, icon),
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: hintCol),
                  style: const TextStyle(fontSize: 13, color: _navy),
                ));

        Widget sectionLabel(String text) => Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(children: [
              Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                      color: indigo, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 7),
              Text(text.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: hintCol,
                      letterSpacing: 0.8)),
            ]));

        Widget rowFields(Widget a, Widget b) =>
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: a),
              const SizedBox(width: 10),
              Expanded(child: b)
            ]);

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: min(440, MediaQuery.of(ctx).size.width - 32),
                maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Gradient header ──
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF0D1B4B), Color(0xFF1A3170)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Edición de Solicitud',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text('Solicitud #$cod',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.75))),
                        ])),
                    GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white))),
                  ]),
                ),

                // ── Body ──
                Flexible(
                    child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Form(
                    key: formKey,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Asesor
                          sectionLabel('Asignación'),
                          dropdown<String>(
                              'Asesor',
                              Icons.person_outline_rounded,
                              selectedAsesor,
                              [
                                const DropdownMenuItem(
                                    value: null, child: Text('[Sin asignar]')),
                                ..._asesoresLista.map((a) {
                                  final sigla =
                                      (a['sigla'] ?? a['codigo_asesor'] ?? '')
                                          .toString();
                                  final nombre = ([a['nombres'], a['apellidos']]
                                          .where((x) =>
                                              x != null &&
                                              x.toString().isNotEmpty)
                                          .join(' '))
                                      .trim();
                                  return DropdownMenuItem(
                                      value: sigla,
                                      child: Text(
                                          nombre.isNotEmpty ? nombre : sigla,
                                          overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              (v) => setS(() => selectedAsesor = v)),

                          // Datos personales
                          sectionLabel('Datos personales'),
                          field('N° Documento', docCtrl, Icons.badge_outlined,
                              kb: TextInputType.number),
                          rowFields(
                            field('Nombres', nombresCtrl,
                                Icons.drive_file_rename_outline_rounded,
                                required: true),
                            field('Apellidos', apellidosCtrl,
                                Icons.drive_file_rename_outline_rounded,
                                required: true),
                          ),
                          field(
                              'Dirección', dirCtrl, Icons.location_on_outlined),

                          // Contacto
                          sectionLabel('Contacto'),
                          rowFields(
                            field('Email', emailCtrl, Icons.email_outlined,
                                kb: TextInputType.emailAddress),
                            field('Teléfono', telCtrl, Icons.phone_outlined,
                                kb: TextInputType.phone),
                          ),

                          // Crédito
                          sectionLabel('Crédito'),
                          dropdown<String>(
                              'Fuente',
                              Icons.account_balance_outlined,
                              selectedFuente,
                              [
                                const DropdownMenuItem(
                                    value: null, child: Text('[Seleccione]')),
                                ...fuenteOpciones().map((f) =>
                                    DropdownMenuItem(value: f, child: Text(f))),
                              ],
                              (v) => setS(() => selectedFuente = v)),

                          field('Valor Solicitado', valorCtrl,
                              Icons.attach_money_rounded,
                              kb: TextInputType.number, required: true),
                          rowFields(
                            dropdown<String>(
                                'Tiempo Cuotas',
                                Icons.schedule_rounded,
                                selectedTiempo,
                                tiempoOpciones
                                    .map((t) => DropdownMenuItem(
                                        value: t, child: Text(t)))
                                    .toList(),
                                (v) => setS(() => selectedTiempo = v)),
                            field('N° Cuotas', cuotasCtrl,
                                Icons.format_list_numbered_rounded,
                                kb: TextInputType.number),
                          ),

                          const SizedBox(height: 16),
                          // ── Botones ──
                          Row(children: [
                            Expanded(
                                child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: borderCol),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text('Cerrar',
                                  style: TextStyle(
                                      color: hintCol,
                                      fontWeight: FontWeight.w600)),
                            )),
                            const SizedBox(width: 10),
                            Expanded(
                                child: GestureDetector(
                              onTap: saving ? null : grabar,
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [accentBlue, indigo],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: indigo.withValues(alpha: 0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Center(
                                    child: saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        Colors.white)))
                                        : const Text('Grabar',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14))),
                              ),
                            )),
                          ]),
                        ]),
                  ),
                )),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _aprobarSolicitud(Map<String, dynamic> p) async {
    final cod = (p['codigo_solicitud'] ?? '').toString();
    String? asesorSel =
        _creditoFiltroAsesor.isNotEmpty ? _creditoFiltroAsesor : null;

    // Si no hay asesor preseleccionado, pedir al usuario
    if (asesorSel == null && _asesoresLista.isNotEmpty) {
      asesorSel = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String? tmp = _asesoresLista.first['sigla']?.toString() ?? '';
          return StatefulBuilder(
              builder: (ctx, setS) => AlertDialog(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Asignar asesor',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D1B4B))),
                    content: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Asesor', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tmp,
                          dropdownColor: Colors.white,
                          isExpanded: true,
                          items: _asesoresLista.map((a) {
                            final sigla =
                                (a['sigla'] ?? a['codigo_asesor'] ?? '')
                                    .toString();
                            final nombre = ([a['nombres'], a['apellidos']]
                                    .where((x) =>
                                        x != null && x.toString().isNotEmpty)
                                    .join(' '))
                                .trim();
                            return DropdownMenuItem(
                                value: sigla,
                                child:
                                    Text(nombre.isNotEmpty ? nombre : sigla));
                          }).toList(),
                          onChanged: (v) => setS(() => tmp = v),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, tmp),
                        child: const Text('Aprobar'),
                      ),
                    ],
                  ));
        },
      );
      if (asesorSel == null || !mounted) return;
    }

    final r = await _api.post('/ajax/aprobar_solicitud.php', {
      'codigo_solicitud': cod,
      'codigo_asesor': asesorSel ?? '',
    });
    if (!mounted) return;
    final exito =
        r.statusCode == 200 && r.body.toLowerCase().contains('aprobado');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(exito ? 'Solicitud #$cod aprobada' : 'Error: ${r.body}'),
      backgroundColor:
          exito ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
    ));
    if (exito) {
      await _fetchPendientes();
      if (mounted) setState(() {});
    }
  }

  Future<void> _rechazarSolicitud(Map<String, dynamic> p) async {
    final cod = (p['codigo_solicitud'] ?? '').toString();
    final nombre = ([p['nombres'], p['apellidos']]
            .where((x) => x != null && x.toString().isNotEmpty)
            .join(' '))
        .trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Text('Rechazar solicitud',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B4B))),
        ]),
        content: Text('¿Rechazar la solicitud #$cod de $nombre?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await _api
        .post('/ajax/rechazar_solicitud.php', {'codigo_solicitud': cod});
    if (!mounted) return;
    final exito =
        r.statusCode == 200 && r.body.toLowerCase().contains('rechazado');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(exito ? 'Solicitud #$cod rechazada' : 'Error: ${r.body}'),
      backgroundColor:
          exito ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
    ));
    if (exito) {
      await _fetchPendientes();
      if (mounted) setState(() {});
    }
  }

  Widget _accionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    final colorDark = Color.lerp(color, Colors.black, 0.22) ?? color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, colorDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: colorDark.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _whatsAppBtn(VoidCallback onTap) => Tooltip(
        message: 'Enviar recordatorio por WhatsApp',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF128C7E).withValues(alpha: 0.28),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/whatsapp.svg',
                  width: 21,
                  height: 21,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  // ── Cuotas dialog ───────────────────────────────────────────────
  Future<void> _showCuotasDialog(Map<String, dynamic> credito) async {
    final cod = credito['cod']?.toString() ?? '';
    final cliente = (credito['cliente'] ?? '').toString();
    List<Map<String, dynamic>> cuotas = [];
    bool loading = true;
    bool requestStarted = false;
    final hoy = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (loading && !requestStarted) {
          requestStarted = true;
          _api.post('/ajax/get_cuotas_credito.php',
              {'codigo_credito': cod}).then((r) {
            if (r.statusCode == 200) {
              try {
                final decoded = jsonDecode(r.body);
                if (decoded is List) {
                  cuotas = decoded
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                }
              } catch (_) {}
            }
            if (ctx.mounted) setS(() => loading = false);
          });
        }

        // Determina color de fila: verde=pagada, rojo=vencida, blanco=futura
        Color cuotaColor(Map<String, dynamic> q) {
          final pagadoFlag = (q['pagado'] ?? '').toString().toLowerCase();
          final pagada = pagadoFlag == 'si' ||
              (_num(q['valor_pagado'] ?? 0) >= _num(q['valor_pago'] ?? 1) &&
                  _num(q['valor_pagado'] ?? 0) > 0);
          if (pagada) return const Color(0xFFC8E6C9);
          try {
            final fp = DateTime.parse((q['fecha_pago'] ?? '').toString());
            if (fp.isBefore(hoy)) return const Color(0xFFFFCDD2);
          } catch (_) {}
          return Colors.white;
        }

        Color cuotaTextColor(Map<String, dynamic> q) {
          final c = cuotaColor(q);
          if (c == const Color(0xFFC8E6C9)) return const Color(0xFF1B5E20);
          if (c == const Color(0xFFFFCDD2)) return const Color(0xFFB71C1C);
          return const Color(0xFF0D1B4B);
        }

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header morado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF3B3B8A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.list_alt_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Listado de cuotas',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(
                        '$cliente · Cód #$cod',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ])),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 36),
                ),
              ]),
            ),
            // Cabecera tabla (color morado)
            Container(
              color: const Color(0xFF4A4A9A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(children: [
                SizedBox(
                    width: 24,
                    child: Text('No.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 3,
                    child: Text('Fecha pago',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 3,
                    child: Text('V. Pagar',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 3,
                    child: Text('V. Pagado',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Text('Pag.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Text('Acc.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            // Filas de cuotas
            if (loading)
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator())
            else if (cuotas.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Sin cuotas registradas',
                      style: TextStyle(color: Color(0xFF8899BB))))
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cuotas.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (_, i) {
                    final q = cuotas[i];
                    final bg = cuotaColor(q);
                    final txt = cuotaTextColor(q);
                    final valorPago = _num(q['valor_pago'] ?? 0);
                    final valorPagado = _num(q['valor_pagado'] ?? 0);
                    final pagadoFlag = (q['pagado'] ?? '').toString();
                    final pagadoSi = pagadoFlag.toLowerCase() == 'si' ||
                        (valorPagado >= valorPago && valorPagado > 0);
                    final fechaPago = (q['fecha_pago'] ?? '').toString();
                    return Container(
                      color: bg,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(children: [
                        SizedBox(
                          width: 24,
                          child: Text('${q['numero_cuota'] ?? i + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: txt)),
                        ),
                        Expanded(
                            flex: 3,
                            child: Text(fechaPago,
                                style: TextStyle(fontSize: 10, color: txt))),
                        Expanded(
                            flex: 3,
                            child: Text(_cop(valorPago),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: txt))),
                        Expanded(
                            flex: 3,
                            child: Text(
                                valorPagado > 0 ? _cop(valorPagado) : '',
                                style: TextStyle(fontSize: 10, color: txt))),
                        SizedBox(
                            width: 28,
                            child: Center(
                              child: Text(pagadoSi ? 'Si' : 'No',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: pagadoSi
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFFB71C1C))),
                            )),
                        SizedBox(
                            width: 48,
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        _showRegistroPagoDialog(ctx, q, () {
                                      _api.post('/ajax/get_cuotas_credito.php',
                                          {'codigo_credito': cod}).then((r) {
                                        if (r.statusCode == 200) {
                                          try {
                                            final d = jsonDecode(r.body);
                                            if (d is List) {
                                              cuotas = d
                                                  .whereType<Map>()
                                                  .map((e) =>
                                                      Map<String, dynamic>.from(
                                                          e))
                                                  .toList();
                                            }
                                          } catch (_) {}
                                        }
                                        if (ctx.mounted) setS(() {});
                                      });
                                    }),
                                    child: const Padding(
                                      padding: EdgeInsets.all(3),
                                      child: Icon(
                                          Icons.assignment_turned_in_outlined,
                                          size: 15,
                                          color: Color(0xFF3B3B8A)),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        _showEditarCuotaDialog(ctx, q, () {
                                      _api.post('/ajax/get_cuotas_credito.php',
                                          {'codigo_credito': cod}).then((r) {
                                        if (r.statusCode == 200) {
                                          try {
                                            final d = jsonDecode(r.body);
                                            if (d is List) {
                                              cuotas = d
                                                  .whereType<Map>()
                                                  .map((e) =>
                                                      Map<String, dynamic>.from(
                                                          e))
                                                  .toList();
                                            }
                                          } catch (_) {}
                                        }
                                        if (ctx.mounted) setS(() {});
                                      });
                                    }),
                                    child: const Padding(
                                      padding: EdgeInsets.all(3),
                                      child: Icon(Icons.edit_outlined,
                                          size: 15, color: Color(0xFF3B3B8A)),
                                    ),
                                  ),
                                ])),
                      ]),
                    );
                  },
                ),
              ),
            // Botón Cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A4A9A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ── Registro de pago de cuota ────────────────────────────────────
  Future<void> _showRegistroPagoDialog(BuildContext parentCtx,
      Map<String, dynamic> cuota, VoidCallback onSaved) async {
    final codigoCuota = cuota['codigo_cuota']?.toString() ?? '';
    String interes = '1'; // 1=No interés, 2=Con interés
    String fuente = '';
    final valorCtrl = TextEditingController(
        text: (cuota['valor_pago'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), ''));
    final comentCtrl = TextEditingController();
    DateTime fechaPago = DateTime.now();
    double moraVal = 0;
    bool loadingMora = codigoCuota.isNotEmpty;
    bool saving = false;

    await showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (loadingMora && codigoCuota.isNotEmpty) {
          loadingMora = false;
          _api.post('/ajax/consultar_datos_cuota.php',
              {'codigo_cuota': codigoCuota}).then((r) {
            if (r.statusCode == 200) {
              try {
                final d = jsonDecode(r.body);
                if (d is Map && d['success'] == true) {
                  final inc = double.tryParse(
                          d['valor_incremento']?.toString() ?? '0') ??
                      0;
                  if (ctx.mounted) setS(() => moraVal = inc);
                }
              } catch (_) {}
            }
          });
        }

        String fechaStr() {
          return '${fechaPago.year}-${fechaPago.month.toString().padLeft(2, '0')}-${fechaPago.day.toString().padLeft(2, '0')}';
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Registro de pago',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B4B))),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Interés
              Row(children: [
                const SizedBox(
                    width: 80,
                    child: Text('Interés',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D1B4B)))),
                Expanded(
                    child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E9F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD3D7EB)),
                  ),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                    value: interes,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    iconEnabledColor: const Color(0xFF3B3B8A),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0D1B4B),
                      fontWeight: FontWeight.w500,
                    ),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('No')),
                      DropdownMenuItem(value: '2', child: Text('Si')),
                    ],
                    onChanged: (v) => setS(() => interes = v ?? '1'),
                  )),
                )),
              ]),
              const SizedBox(height: 10),
              // Valor pagado
              TextField(
                controller: valorCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Color(0xFF0D1B4B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: const Color(0xFF3B3B8A),
                decoration: InputDecoration(
                  labelText: 'Valor pagado',
                  labelStyle: const TextStyle(
                    color: Color(0xFF5B5BB0),
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF3B3B8A),
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFE7E9F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B3B8A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              // Mora calculada (read-only)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: moraVal > 0
                      ? const Color(0xFFFFD7DB)
                      : const Color(0xFFDDF2E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: moraVal > 0
                        ? const Color(0xFFF3A8B0)
                        : const Color(0xFFB8DFC0),
                  ),
                ),
                child: Text(
                  moraVal > 0
                      ? 'Incremento por mora: ${_cop(moraVal)}'
                      : 'Sin incremento por mora',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: moraVal > 0
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF1B5E20),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Fuente
              DropdownButtonFormField<String>(
                initialValue: fuente,
                isExpanded: true,
                dropdownColor: Colors.white,
                iconEnabledColor: const Color(0xFF3B3B8A),
                style: const TextStyle(
                  color: Color(0xFF0D1B4B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Fuente',
                  labelStyle: const TextStyle(
                    color: Color(0xFF5B5BB0),
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF3B3B8A),
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFE7E9F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B3B8A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      '[Seleccione]',
                      style: TextStyle(color: Color(0xFF667395)),
                    ),
                  ),
                  ..._fuentesLista.map((f) {
                    final label =
                        (f['fuente'] ?? f['nombre'] ?? f['name'] ?? '')
                            .toString();
                    final codigo =
                        (f['valor'] ?? f['codigo'] ?? f['id'] ?? label)
                            .toString();
                    return DropdownMenuItem(
                      value: codigo,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) => setS(() => fuente = v ?? ''),
              ),
              const SizedBox(height: 10),
              // Fecha de Pago
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: fechaPago,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null && ctx.mounted) setS(() => fechaPago = d);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E9F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD3D7EB)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF3B3B8A)),
                    const SizedBox(width: 8),
                    Text(
                      '${fechaPago.day.toString().padLeft(2, '0')}/${fechaPago.month.toString().padLeft(2, '0')}/${fechaPago.year}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF0D1B4B)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              // Comentarios
              TextField(
                controller: comentCtrl,
                maxLines: 3,
                style: const TextStyle(
                  color: Color(0xFF0D1B4B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: const Color(0xFF3B3B8A),
                decoration: InputDecoration(
                  hintText: 'Comentarios (opcional)',
                  hintStyle: const TextStyle(
                    color: Color(0xFF667395),
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFE7E9F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B3B8A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar',
                  style: TextStyle(color: Color(0xFF8899BB))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B3B8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final val = double.tryParse(valorCtrl.text.trim()) ?? 0;
                      if (val <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Ingresa el valor pagado'),
                                backgroundColor: Color(0xFFDC2626)));
                        return;
                      }
                      setS(() => saving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final r =
                          await _api.post('/ajax/registrar_cuota_credito.php', {
                        'codigo_cuota': codigoCuota,
                        'interes': interes,
                        'valor_pagado': valorCtrl.text.trim(),
                        'fuente_cuota': fuente,
                        'fecha_registro_pago': fechaStr(),
                        'comentarios': comentCtrl.text.trim(),
                      });
                      setS(() => saving = false);
                      if (!ctx.mounted) return;
                      final ok = r.statusCode == 200 &&
                          r.body.contains('Pago Registrado');
                      messenger.showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Pago registrado correctamente'
                            : 'Error: ${r.body}'),
                        backgroundColor: ok
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ));
                      if (ok) {
                        Navigator.pop(ctx);
                        onSaved();
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Grabar'),
            ),
          ],
        );
      }),
    );
  }

  // ── Editar cuota ─────────────────────────────────────────────────
  Future<void> _showEditarCuotaDialog(BuildContext parentCtx,
      Map<String, dynamic> cuota, VoidCallback onSaved) async {
    final codigoCuota = cuota['codigo_cuota']?.toString() ?? '';
    final valorCtrl = TextEditingController(
        text: (cuota['valor_pago'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), ''));
    final obsCtrl =
        TextEditingController(text: (cuota['observaciones'] ?? '').toString());
    DateTime? fechaPago;
    try {
      fechaPago = DateTime.parse((cuota['fecha_pago'] ?? '').toString());
    } catch (_) {}
    bool saving = false;

    await showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        String fechaStr() {
          if (fechaPago == null) return '';
          return '${fechaPago!.year}-${fechaPago!.month.toString().padLeft(2, '0')}-${fechaPago!.day.toString().padLeft(2, '0')}';
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Editar Cuota',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B4B))),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: valorCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Color(0xFF0D1B4B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: const Color(0xFF3B3B8A),
                decoration: InputDecoration(
                  labelText: 'Valor de la cuota',
                  labelStyle: const TextStyle(
                    color: Color(0xFF5B5BB0),
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF3B3B8A),
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFE7E9F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B3B8A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: fechaPago ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null && ctx.mounted) setS(() => fechaPago = d);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E9F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD3D7EB)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF3B3B8A)),
                    const SizedBox(width: 8),
                    Text(
                      fechaPago != null
                          ? '${fechaPago!.day.toString().padLeft(2, '0')}/${fechaPago!.month.toString().padLeft(2, '0')}/${fechaPago!.year}'
                          : 'Fecha de pago',
                      style: TextStyle(
                        fontSize: 12,
                        color: fechaPago != null
                            ? const Color(0xFF0D1B4B)
                            : const Color(0xFF8899BB),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                maxLines: 3,
                style: const TextStyle(
                  color: Color(0xFF0D1B4B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: const Color(0xFF3B3B8A),
                decoration: InputDecoration(
                  hintText: 'Observaciones (opcional)',
                  hintStyle: const TextStyle(
                    color: Color(0xFF667395),
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFE7E9F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD3D7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B3B8A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF8899BB))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B3B8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setS(() => saving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final r = await _api.post('/ajax/editar_cuota.php', {
                        'codigo_cuota': codigoCuota,
                        'valor_pago': valorCtrl.text.trim(),
                        'fecha_pago': fechaStr(),
                      });
                      setS(() => saving = false);
                      if (!ctx.mounted) return;
                      bool ok = false;
                      try {
                        final d = jsonDecode(r.body);
                        ok = r.statusCode == 200 &&
                            (d['resultado'] == 1 || d['resultado'] == '1');
                      } catch (_) {
                        ok = false;
                      }
                      messenger.showSnackBar(SnackBar(
                        content:
                            Text(ok ? 'Cuota actualizada' : 'Error: ${r.body}'),
                        backgroundColor: ok
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ));
                      if (ok) {
                        Navigator.pop(ctx);
                        onSaved();
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar cambios'),
            ),
          ],
        );
      }),
    );
  }

  // ── Recordatorio por WhatsApp ────────────────────────────────────
  Future<void> _enviarRecordatorioWhatsApp(Map<String, dynamic> credito) async {
    final cliente = (credito['cliente'] ?? 'cliente').toString().trim();
    final cod = credito['cod']?.toString() ?? '';
    final proxima = (credito['proxima_fecha'] ?? '').toString().trim();
    final vencidas = int.tryParse(
          (credito['cuotas_vencidas'] ??
                  credito['vencidas'] ??
                  credito['cantidad_vencidas'] ??
                  '0')
              .toString(),
        ) ??
        0;
    var telefono = (credito['telefono'] ??
            credito['celular'] ??
            credito['telefono_cliente'] ??
            credito['numero_telefono'] ??
            '')
        .toString()
        .replaceAll(RegExp(r'\D'), '');

    if (telefono.startsWith('00')) telefono = telefono.substring(2);
    if (telefono.startsWith('57') && telefono.length == 12) {
      telefono = telefono.substring(2);
    }

    if (telefono.length != 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'El crédito #$cod no tiene un teléfono válido para WhatsApp.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final mensaje = vencidas > 0
        ? 'Hola Sr(a) $cliente, tienes $vencidas cuota(s) vencida(s), recuerde que su fecha de pago'
            '${proxima.isNotEmpty ? ' es $proxima' : ' ya se encuentra vencida'}.'
        : 'Hola Sr(a) $cliente, le recordamos que su próxima fecha de pago'
            '${proxima.isNotEmpty ? ' es $proxima' : ' está próxima'}.';

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF25D366)),
                SizedBox(height: 14),
                Text(
                  'Enviando recordatorio...',
                  style: TextStyle(
                    color: Color(0xFF0D1B4B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    bool enviado = false;
    String resultado = 'No se pudo enviar el recordatorio.';
    try {
      final response = await http
          .post(
            Uri.parse('https://whatsapp-bot-s66s.onrender.com/enviar'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'telefono': telefono,
              'mensaje': mensaje,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        enviado = response.statusCode == 200 && decoded['ok'] == true;
        resultado = enviado
            ? (decoded['mensaje']?.toString() ??
                'Recordatorio enviado correctamente.')
            : (decoded['error']?.toString() ??
                decoded['mensaje']?.toString() ??
                'El servicio de WhatsApp rechazó el envío.');
      } else {
        resultado = 'El servicio devolvió una respuesta no válida.';
      }
    } on TimeoutException {
      resultado = 'El servicio de WhatsApp tardó demasiado en responder.';
    } catch (e) {
      resultado = 'No fue posible conectar con el servicio de WhatsApp.';
      debugPrint('[SAF] WhatsApp: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado),
        backgroundColor:
            enviado ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Confirmar eliminar ───────────────────────────────────────────
  Future<void> _confirmarEliminarCredito(Map<String, dynamic> credito) async {
    final cod = credito['cod']?.toString() ?? '';
    final cliente = (credito['cliente'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Text('Eliminar crédito',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B4B))),
        ]),
        content: Text(
            '¿Desea eliminar el crédito #$cod de $cliente? Esta acción no se puede deshacer.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r =
        await _api.post('/ajax/eliminar_credito.php', {'codigo_credito': cod});
    if (!mounted) return;
    final exito =
        r.statusCode == 200 && r.body.toLowerCase().contains('eliminado');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(exito
          ? 'Crédito #$cod eliminado'
          : 'No se pudo eliminar. Verifique el servidor.'),
      backgroundColor:
          exito ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
    ));
    if (exito) {
      _api.invalidateCache('/ajax/get_creditos_lista.php');
      await _fetchCreditos('');
      if (mounted) setState(() {});
    }
  }

  // ── Paz y Salvo dialog ───────────────────────────────────────────
  void _showPazYSalvoDialog(Map<String, dynamic> credito) {
    final cliente = (credito['cliente'] ?? '').toString();
    final numDoc = (credito['num_documento'] ?? '').toString();
    final cod = credito['cod']?.toString() ?? '';
    final fechaPrestamo = (credito['fecha_prestamo'] ?? '').toString();
    final valorPrestamo = _num(credito['valor_prestamo'] ?? 0);
    final ultimaPago = (credito['ultima_fecha_pago'] ?? '').toString();
    final hoy = DateTime.now();
    final fechaFirma = '${hoy.day}/${hoy.month}/${hoy.year}';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header empresa
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF0D1B4B), width: 2),
                  ),
                  child: const Icon(Icons.savings_rounded,
                      color: Color(0xFF0D1B4B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('SAF',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF0D1B4B))),
                      const Text('Dirección · Tel: (316) 270-5951',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF64748B))),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fechaFirma,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                  const Text('Paz y salvo',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ]),
              ]),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF0D1B4B), thickness: 1.5),
              const SizedBox(height: 16),
              // Título
              const Center(
                child: Text('CERTIFICADO DE PAZ Y SALVO',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF0D1B4B),
                        letterSpacing: 0.5)),
              ),
              const SizedBox(height: 20),
              // Cuerpo
              RichText(
                  text: TextSpan(
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1E293B), height: 1.6),
                      children: [
                    const TextSpan(
                        text: 'La presente certifica que el(la) señor(a) '),
                    TextSpan(
                        text: cliente,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text: ' identificado(a) con cédula de ciudadanía No. '),
                    TextSpan(
                        text: numDoc,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text:
                            ' ha cancelado en su totalidad las obligaciones relacionadas con el crédito identificado con número '),
                    TextSpan(
                        text: cod,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ', realizado el dia '),
                    TextSpan(
                        text: fechaPrestamo,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ', por valor de '),
                    TextSpan(
                        text: _cop(valorPrestamo),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: '.'),
                  ])),
              const SizedBox(height: 12),
              if (ultimaPago.isNotEmpty)
                RichText(
                    text: TextSpan(
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                            height: 1.6),
                        children: [
                      const TextSpan(
                          text: 'Ultima Fecha de Pago: ',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '$ultimaPago.'),
                    ])),
              const SizedBox(height: 12),
              const Text(
                'Este certificado se expide a solicitud del interesado para los fines que estime convenientes.',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF1E293B), height: 1.6),
              ),
              const SizedBox(height: 12),
              Text(
                'En constancia de lo anterior, se firma a los $fechaFirma.',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF1E293B), height: 1.6),
              ),
              const SizedBox(height: 24),
              // Sello
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF1565C0), width: 2),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.savings_rounded,
                            color: Color(0xFF1565C0), size: 22),
                        const Text('SAF',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1565C0))),
                        const Text('PAZ Y SALVO',
                            style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0))),
                      ]),
                ),
              ),
              const SizedBox(height: 24),
              // Firmas
              Row(children: [
                Expanded(
                    child: Column(children: [
                  const Divider(color: Color(0xFF0D1B4B)),
                  const Text('Asesor',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ])),
                const SizedBox(width: 32),
                Expanded(
                    child: Column(children: [
                  const Divider(color: Color(0xFF0D1B4B)),
                  const Text('Deudor',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ])),
              ]),
              const SizedBox(height: 12),
              // Botón cerrar
              Center(
                  child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar',
                    style: TextStyle(color: Color(0xFF3B3B8A))),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pgBtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? _navy : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: enabled ? Colors.white : const Color(0xFF9CA3AF),
              size: 20),
        ),
      );

  Widget _cTag(String label, String value) => RichText(
          text: TextSpan(
        style: const TextStyle(fontSize: 11),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF8899BB))),
          TextSpan(
              text: value,
              style: const TextStyle(
                  color: Color(0xFF0D1B4B), fontWeight: FontWeight.w600)),
        ],
      ));

  Widget _ahoradorCard(Map<String, dynamic> a) =>
      _AhoradorExpandable(data: a, cop: _cop, num: _num);

  Widget _heroStat({
    required String label,
    required String? value,
    required IconData icon,
    required Color color,
    bool alignEnd = false,
  }) =>
      Padding(
        padding:
            EdgeInsets.only(left: alignEnd ? 16 : 0, right: alignEnd ? 0 : 16),
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!alignEnd) Icon(icon, color: color, size: 13),
                if (!alignEnd) const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.80),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                if (alignEnd) const SizedBox(width: 4),
                if (alignEnd) Icon(icon, color: color, size: 13),
              ],
            ),
            const SizedBox(height: 5),
            value == null
                ? Container(
                    width: 90,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4)))
                : Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _emptyActivity() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: _accent1, size: 26),
            ),
            const SizedBox(height: 12),
            const Text('Sin movimientos',
                style: TextStyle(
                    color: Color(0xFF3A4A7A),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text('Los movimientos aparecerán aquí',
                style: TextStyle(
                    color: const Color(0xFF8899BB).withValues(alpha: 0.8),
                    fontSize: 12)),
          ],
        ),
      );

  // ── Skeleton helpers ────────────────────────────────────────────
  Widget _skel(double w, double h, {double r = 10}) => AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) {
          final base = Color.lerp(const Color(0xFFDDE3EE),
              const Color(0xFFEEF1F8), _shimmer.value)!;
          return Container(
            width: w == double.infinity ? null : w,
            height: h,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(r),
            ),
          );
        },
      );

  Widget _pendientesSkeleton() => IgnorePointer(
        child: Opacity(
          opacity: 0.68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0).withValues(alpha: 0.65),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _skel(double.infinity, 15, r: 6)),
                          const SizedBox(width: 28),
                          _skel(58, 20, r: 8),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _skel(62, 10, r: 5),
                          const SizedBox(width: 10),
                          _skel(88, 10, r: 5),
                          const SizedBox(width: 10),
                          Expanded(child: _skel(double.infinity, 10, r: 5)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _skel(double.infinity, 25, r: 7)),
                          const SizedBox(width: 10),
                          _skel(78, 30, r: 9),
                          const SizedBox(width: 8),
                          _skel(72, 30, r: 9),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _dashboardSkeleton() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance card
          AnimatedBuilder(
            animation: _shimmer,
            builder: (_, __) {
              final c = Color.lerp(const Color(0xFFCED7EE),
                  const Color(0xFFDDE5F5), _shimmer.value)!;
              return Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                height: 190,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(28)),
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _skel(100, 13, r: 6),
                      const SizedBox(height: 6),
                      _skel(70, 18, r: 6),
                      const SizedBox(height: 14),
                      _skel(150, 38, r: 8),
                      const Spacer(),
                      Row(children: [
                        _skel(80, 44, r: 10),
                        const SizedBox(width: 14),
                        _skel(80, 44, r: 10),
                        const SizedBox(width: 14),
                        _skel(80, 44, r: 10),
                      ]),
                    ]),
              );
            },
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Section title
              _skel(130, 18, r: 6),
              const SizedBox(height: 16),
              // 2x2 summary cards
              Row(children: [
                Expanded(child: _skel(double.infinity, 108, r: 16)),
                const SizedBox(width: 12),
                Expanded(child: _skel(double.infinity, 108, r: 16)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _skel(double.infinity, 108, r: 16)),
                const SizedBox(width: 12),
                Expanded(child: _skel(double.infinity, 108, r: 16)),
              ]),
              const SizedBox(height: 26),
              // Recent activity title
              _skel(160, 18, r: 6),
              const SizedBox(height: 14),
              // 3 activity rows
              _skel(double.infinity, 68, r: 14),
              const SizedBox(height: 10),
              _skel(double.infinity, 68, r: 14),
              const SizedBox(height: 10),
              _skel(double.infinity, 68, r: 14),
            ]),
          ),
        ],
      );

  Widget _loadingView() => SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _accent1),
              const SizedBox(height: 16),
              Text('Cargando datos...',
                  style: TextStyle(
                      color: const Color(0xFF8899BB).withValues(alpha: 0.8),
                      fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _avatarFallback(String name) => Container(
        color: _accent1,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      );

  Widget _profileSheet(String email) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header con gradiente
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accent1.withValues(alpha: 0.06),
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  // Avatar con anillo gradiente
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent1.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: Container(
                        color: Colors.white,
                        child: _photoUrl.isNotEmpty
                            ? Image.network(
                                _photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarFallback(_fullName.split(' ').first),
                              )
                            : _avatarFallback(_fullName.split(' ').first),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accent1.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: _accent1.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Opciones
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                children: [
                  // Gestión de usuarios — tarjeta gradiente
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _accent1.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showUsersManagement();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.manage_accounts_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gestión de usuarios',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Usuarios, perfiles y accesos',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white70,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cerrar sesión — gradiente épico
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFB91C1C),
                          Color(0xFFE53935),
                          Color(0xFFFF6B35),
                        ],
                        stops: [0.0, 0.55, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFE53935).withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 0,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: -4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              contentPadding: EdgeInsets.zero,
                              titlePadding: EdgeInsets.zero,
                              title: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 32, 24, 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Icono con gradiente épico
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFB91C1C),
                                            Color(0xFFE53935),
                                            Color(0xFFFF6B35),
                                          ],
                                          stops: [0.0, 0.55, 1.0],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE53935)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 20,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 8),
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFFFF6B35)
                                                .withValues(alpha: 0.2),
                                            blurRadius: 36,
                                            spreadRadius: -4,
                                            offset: const Offset(0, 14),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.logout_rounded,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      '¿Cerrar sesión?',
                                      style: TextStyle(
                                        color: _navy,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Se cerrará tu sesión activa y tendrás que\nvolver a iniciar sesión para continuar.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF8899BB),
                                        fontSize: 13,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    // Botón confirmar
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFB91C1C),
                                            Color(0xFFE53935),
                                            Color(0xFFFF6B35),
                                          ],
                                          stops: [0.0, 0.55, 1.0],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE53935)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 14,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          onTap: () => Navigator.pop(ctx, true),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 15),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.logout_rounded,
                                                    color: Colors.white,
                                                    size: 18),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Sí, cerrar sesión',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Botón cancelar
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF8899BB),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            side: const BorderSide(
                                                color: Color(0xFFE2E8F0),
                                                width: 1.5),
                                          ),
                                        ),
                                        child: const Text(
                                          'No, quedarse',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                              actions: const [],
                            ),
                          );
                          if (confirm == true && mounted) {
                            Navigator.of(context).pop();
                            _logout();
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Cerrar sesión',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Utility ──────────────────────────────────────────────────────
  static Color _hexColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final padded = clean.length == 6 ? 'FF$clean' : clean;
    return Color(int.tryParse(padded, radix: 16) ?? 0xFF4361EE);
  }

  static double _num(dynamic v) => v == null
      ? 0.0
      : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

  static Map<String, dynamic> _json(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return {};
  }

  static String _cop(double amount) {
    final neg = amount < 0;
    final n = amount.abs().toInt();
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${neg ? '-' : ''}\$ ${buf.toString()}';
  }

  static IconData _cuentaIcon(String tipo) {
    switch (tipo) {
      case 'ingreso':
        return Icons.arrow_downward_rounded;
      case 'crédito':
      case 'credito':
        return Icons.credit_card_rounded;
      case 'gasto':
        return Icons.arrow_upward_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tarjeta de ahorrador expandible
// ══════════════════════════════════════════════════════════════════════════════
class _AhoradorExpandable extends StatefulWidget {
  const _AhoradorExpandable({
    required this.data,
    required this.cop,
    required this.num,
  });
  final Map<String, dynamic> data;
  final String Function(double) cop;
  final double Function(dynamic) num;

  @override
  State<_AhoradorExpandable> createState() => _AhoradorExpandableState();
}

class _AhoradorExpandableState extends State<_AhoradorExpandable>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  static const _purple = Color(0xFF4361EE);
  static const _navy = Color(0xFF0D1B4B);

  @override
  Widget build(BuildContext context) {
    final a = widget.data;
    final nombre = (a['ahorrador'] ?? a['nombre'] ?? 'Ahorrador').toString();
    final asesor = (a['asesor'] ?? '').toString();
    final total = widget.num(a['total_ahorrado'] ?? a['valor_pactado'] ?? 0);
    final pactado = widget.num(a['valor_pactado'] ?? 0);
    final neto = widget.num(a['neto_pagar'] ?? a['neto'] ?? 0);
    final rend = widget.num(a['porcentaje'] ?? 0);
    final fecha = (a['Fecha_ingreso'] ?? a['fecha_ingreso'] ?? '').toString();
    final cuotas = a['ahorros'];
    final List<Map<String, dynamic>> meses = cuotas is List
        ? cuotas
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];

    // En mora sólo si una cuota YA VENCIDA (fecha ≤ hoy en Colombia) no está
    // pagada. Las cuotas futuras vienen con mora=1 del API pero no cuentan.
    final hoy = _hoyColombia();
    final enMora = meses.any((m) {
      final pagado =
          (m['estado_pago'] ?? '').toString().toLowerCase().contains('pagado');
      if (pagado) return false;
      final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
      if (fc == null) return false;
      return !DateTime(fc.year, fc.month, fc.day).isAfter(hoy); // fc ≤ hoy
    });

    final parts = nombre.trim().split(RegExp(r'\s+'));
    final i1 = parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : 'A';
    final i2 = parts.length > 1
        ? parts[parts.length >= 3 ? 2 : 1][0].toUpperCase()
        : '';
    final initials = '$i1$i2';

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded
                ? _purple.withValues(alpha: 0.25)
                : const Color(0xFFE8ECF4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? _purple.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _expanded ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Accent top bar ──────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: enMora
                        ? [const Color(0xFFDC2626), const Color(0xFFF87171)]
                        : [const Color(0xFF4361EE), const Color(0xFF6366F1)],
                  ),
                ),
              ),
            ),

            // ── Cabecera ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4361EE), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4361EE).withValues(alpha: 0.30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(width: 11),
                // Nombre + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _navy,
                              height: 1.25,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (asesor.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 10,
                                  color: _purple.withValues(alpha: 0.8)),
                              const SizedBox(width: 3),
                              Text(asesor,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _purple.withValues(alpha: 0.9))),
                            ]),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: enMora
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              enMora
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_rounded,
                              size: 10,
                              color: enMora
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              enMora ? 'En mora' : 'Al día',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: enMora
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A)),
                            ),
                          ]),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Monto + chevron — columna derecha
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(_anim),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2FA),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 15, color: Color(0xFF8899BB)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4361EE), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(widget.cop(total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Colors.white)),
                          Text('ahorrado',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                  ],
                ),
              ]),
            ),

            // ── Detalle expandible ───────────────────────────────
            SizeTransition(
              sizeFactor: _anim,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(17)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: const Color(0xFFE8ECF4),
                    ),
                    const SizedBox(height: 14),

                    // 2×2 data grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        Expanded(
                            child: _detailChip(
                                Icons.calendar_today_outlined,
                                'Fecha ingreso',
                                fecha.length >= 10 ? fecha.substring(0, 10) : fecha,
                                const Color(0xFF4361EE), const Color(0xFF818CF8))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _detailChip(
                                Icons.savings_outlined,
                                'Valor pactado',
                                widget.cop(pactado),
                                const Color(0xFF7C3AED), const Color(0xFFA78BFA))),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        Expanded(
                            child: _detailChip(
                                Icons.trending_up_rounded,
                                'Rendimiento',
                                '${rend.toStringAsFixed(1)}%',
                                const Color(0xFF059669), const Color(0xFF34D399))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _detailChip(
                                Icons.account_balance_wallet_outlined,
                                'Neto a pagar',
                                widget.cop(neto),
                                const Color(0xFFD97706), const Color(0xFFFBBF24))),
                      ]),
                    ),

                    // Cuotas mensuales — scroll horizontal
                    if (meses.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4361EE), Color(0xFF6366F1)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text('Cuotas mensuales',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _navy)),
                        ]),
                      ),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          itemCount: meses.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => _mesChip(meses[i]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, String value,
          Color c1, Color c2) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c1.withValues(alpha: 0.08), c2.withValues(alpha: 0.15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c1.withValues(alpha: 0.20)),
          boxShadow: [
            BoxShadow(
                color: c1.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 12, color: c1),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: c1.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: c1.withValues(alpha: 0.9))),
        ]),
      );

  // Fecha actual en Colombia (UTC-5, sin horario de verano), sólo Y-M-D.
  static DateTime _hoyColombia() {
    final n = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    return DateTime(n.year, n.month, n.day);
  }

  Widget _mesChip(Map<String, dynamic> m) {
    final mes = (m['nombre_mes'] ?? '').toString();
    final estadoPago = (m['estado_pago'] ?? '').toString();
    final valor = widget.num(m['valor_pagado'] ?? m['valor'] ?? 0);
    final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
    final vencida = fc != null &&
        !DateTime(fc.year, fc.month, fc.day).isAfter(_hoyColombia());

    final esPagado = estadoPago.toLowerCase().contains('pagado');
    // Vencida y sin pagar → roja; futura sin pagar → gris (pendiente).
    final esNoPago = !esPagado && vencida;
    final esFuturo = !esPagado && !vencida;

    final textColor = esPagado
        ? const Color(0xFF16A34A)
        : esNoPago
            ? const Color(0xFFDC2626)
            : const Color(0xFF8899BB);
    final icon = esPagado
        ? Icons.check_circle_rounded
        : esNoPago
            ? Icons.cancel_rounded
            : Icons.radio_button_unchecked_rounded;

    final gradColors = esPagado
        ? [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)]
        : esNoPago
            ? [const Color(0xFFFEE2E2), const Color(0xFFFECDD3)]
            : [const Color(0xFFF0F2FA), const Color(0xFFE8ECF4)];

    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: textColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(height: 5),
          Text(mes,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.2)),
          const SizedBox(height: 3),
          Text(
            esFuturo ? '—' : widget.cop(valor),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

// ── Animated SAF logo for the AppBar ────────────────────────────────────────
class _AnimatedSafLogo extends StatefulWidget {
  const _AnimatedSafLogo();
  @override
  State<_AnimatedSafLogo> createState() => _AnimatedSafLogoState();
}

class _AnimatedSafLogoState extends State<_AnimatedSafLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;
  late final Animation<double> _glowAlpha;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _rotate = _ctrl;
    _glowAlpha = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.18), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: 42,
        height: 42,
        child: Stack(alignment: Alignment.center, children: [
          // Pulsing outer glow ring
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: _glowAlpha.value),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          // Rotating logo inside frosted circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Transform.rotate(
                angle: _rotate.value * 2 * pi,
                child: const CustomPaint(
                    painter: SafLogoPainter(Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
