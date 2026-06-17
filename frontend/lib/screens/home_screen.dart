import 'dart:convert';
import 'package:flutter/material.dart';
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

  // Filtros movimientos
  String _filterCuenta = '';
  String _filterTipo = '';
  DateTime? _filterDesde;
  DateTime? _filterHasta;

  // Filtros créditos
  String _creditoFiltroEstado = '';

  // Simulador crédito
  double _simMeses = 6;
  double _simMonto = 1000000;
  double _simTasa = 2.0;
  DateTime? _simDesde;
  DateTime? _simHasta;

  // ── Data state ──────────────────────────────────────────────────
  bool _loadingData = true;
  List<Map<String, dynamic>> _cuentas = [];
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _ahorradores = []; // Lista completa del año
  List<Map<String, dynamic>> _creditos = []; // Estadística por fuente
  String _ahorFilterAnio = DateTime.now().year.toString();
  String _ahorFilterAsesor = '0'; // '0' = Todos; o la sigla (DT, JP, …)
  List<Map<String, dynamic>> _creditosLista = []; // Aprobados/Pendientes

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

  // Ahorradores tras aplicar el filtro de asesor (cliente)
  List<Map<String, dynamic>> get _ahorradoresFiltrados {
    if (_ahorFilterAsesor == '0') return _ahorradores;
    return _ahorradores
        .where((a) =>
            (a['asesor'] ?? '').toString().trim().toUpperCase() ==
            _ahorFilterAsesor.toUpperCase())
        .toList();
  }

  // ── Computed ────────────────────────────────────────────────────
  double get _totalSaldo => _cuentas.fold(0.0,
      (s, c) => s + _num(c['saldo_actual'] ?? c['saldo'] ?? c['balance'] ?? 0));

  // tipo_movimiento: "2"=Gasto "3"=Ingreso/Transferencia
  double get _totalIngresos => _movimientos.where((m) {
        final t = (m['tipo_movimiento'] ?? '').toString();
        return t == '3' || t == '1';
      }).fold(0.0, (s, m) => s + _num(m['valor'] ?? 0));

  double get _totalEgresos => _movimientos
      .where((m) => (m['tipo_movimiento'] ?? '').toString() == '2')
      .fold(0.0, (s, m) => s + _num(m['valor'] ?? 0));

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
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────
  Future<void> _loadData() async {
    await _api.init();
    final u = _api.user;
    final codigoUsuario = u?['codigo_usuario']?.toString() ?? '';
    final anio = DateTime.now().year.toString();

    await _fetchCuentas(codigoUsuario);
    await Future.wait([
      _fetchMovimientosTodasCuentas(codigoUsuario),
      _fetchAhorradores(anio),
      _fetchCreditos(codigoUsuario),
    ]);

    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _fetchCuentas(String filtro) async {
    try {
      final r =
          await _api.post('/ajax/listar_cuentas_gasto.php', {'filtro': filtro});
      debugPrint('[SAF] cuentas status: ${r.statusCode}');
      debugPrint(
          '[SAF] cuentas body: ${r.body.substring(0, r.body.length.clamp(0, 400))}');
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        List<dynamic>? list;
        if (d is List) {
          list = d;
        } else if (d is Map) {
          // try common wrapper keys
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
        }
      }
    } catch (e) {
      debugPrint('[SAF] cuentas: $e');
    }
  }

  Future<void> _fetchMovimientosTodasCuentas(String usuario) async {
    final all = <Map<String, dynamic>>[];
    await Future.wait(_cuentas.map((cuenta) async {
      final codigo = cuenta['codigo']?.toString() ?? '';
      if (codigo.isEmpty) return;
      try {
        final r = await _api.post('/ajax/listar_movimientos_cuenta.php',
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
    all.sort((a, b) =>
        (b['fecha'] ?? '').toString().compareTo((a['fecha'] ?? '').toString()));
    _movimientos = all;
  }

  Future<void> _fetchAhorradores([String? anio, String? asesor]) async {
    try {
      final r = await _api.post('/ajax/listado_ahorros.php', {
        'anio_ahorro': anio ?? _ahorFilterAnio,
        'filtro_asesor': asesor ?? _ahorFilterAsesor,
      });
      if (r.statusCode == 200) {
        final d = _json(r.body);
        debugPrint(
            '[SAF] ahorros body: ${r.body.substring(0, r.body.length.clamp(0, 200))}');
        final list = d['ahorradores'];
        if (list is List) {
          setState(() {
            _ahorradores = list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
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
    // Estadística por fuente (totales agrupados)
    try {
      final r = await _api.post('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_total_creditos_valores', 'filtro': filtro});
      if (r.statusCode == 200) {
        final d = _json(r.body);
        debugPrint('[SAF] creditos-stat FULL: ${r.body}');
        final list = d['datos'];
        if (list is List) {
          _creditos = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos stat: $e');
    }

    // Lista individual de créditos aprobados
    try {
      final r = await _api.post('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_creditos_aprobados', 'filtro': filtro});
      if (r.statusCode == 200) {
        final d = _json(r.body);
        debugPrint(
            '[SAF] creditos-lista: ${r.body.substring(0, r.body.length.clamp(0, 300))}');
        final list = d['datos'];
        if (list is List) {
          _creditosLista = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos lista: $e');
    }
  }

  // Carga la estadística de la sub-pestaña activa.
  Future<void> _fetchEstadistica() async {
    final codigo = _estTabs[_estSubTab].$2;
    setState(() {
      _estLoading = true;
      _estData = [];
    });
    try {
      final r = await _api.post('/ajax/listado_json_campos.php',
          {'codigo_consulta': codigo, 'filtro': '', 'agrupacion': ''});
      if (r.statusCode == 200) {
        final d = _json(r.body);
        debugPrint(
            '[SAF] est $codigo: ${r.body.substring(0, r.body.length.clamp(0, 250))}');
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
      if (nombres.isNotEmpty && apellidos.isNotEmpty)
        return '$nombres $apellidos';
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1),
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: CustomPaint(painter: SafLogoPainter(Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('SAF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 1.2,
                )),
            const Spacer(),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded,
                      color: Colors.white, size: 24),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF4B6E),
                      border: Border.all(color: _navy, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
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
    if (_loadingData) return _dashboardSkeleton();

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
              _sectionTitle('Resumen del mes'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Total Ingresos',
                      value: _cop(ingresos),
                      color: const Color(0xFF16A34A),
                      bgColor: const Color(0xFFDCFCE7),
                      badge:
                          '+${_movimientos.where((m) => _tipoOf(m) == 'ingreso').length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.trending_down_rounded,
                      label: 'Total Gastos',
                      value: _cop(egresos),
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEE2E2),
                      badge:
                          '${_movimientos.where((m) => _tipoOf(m) == 'gasto').length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Balance',
                      value: _cop(balance),
                      color: balance >= 0 ? _accent1 : const Color(0xFFDC2626),
                      bgColor: balance >= 0
                          ? const Color(0xFFEEF0FF)
                          : const Color(0xFFFEE2E2),
                      badge: '${_cuentas.length} cuentas',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      icon: Icons.savings_rounded,
                      label: 'Ahorradores',
                      value: _ahorradores.isEmpty
                          ? '0'
                          : _ahorradores.length.toString(),
                      color: const Color(0xFF7B2FBE),
                      bgColor: const Color(0xFFF3E5F5),
                      badge: 'activos',
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
            padding: const EdgeInsets.only(left: 20, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Mis Cuentas'),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 3),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('Ver todo',
                      style: TextStyle(
                          color: _accent1,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 106,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _cuentas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _cuentaChip(_cuentas[i]),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle('Actividad Reciente'),
                  TextButton(
                    onPressed: () => setState(() => _selectedIndex = 3),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: const Text('Ver todo',
                        style: TextStyle(
                            color: _accent1,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
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

    // Totales calculados desde lista de créditos individuales
    final totalPagado = _creditosLista.fold(
        0.0, (s, c) => s + _num(c['total_pagado'] ?? c['pagado'] ?? 0));
    final totalPendiente = _creditosLista.fold(
        0.0,
        (s, c) =>
            s +
            _num(c['saldo_pendiente'] ?? c['pendiente'] ?? c['saldo'] ?? 0));

    final creditosFiltrados = _creditoFiltroEstado.isEmpty
        ? _creditosLista
        : _creditosLista.where((c) {
            final est = (c['estado'] ?? '').toString().toLowerCase();
            return est.contains(_creditoFiltroEstado.toLowerCase());
          }).toList();

    // ── Cálculo del simulador (modelo de interés diario) ──────────
    final meses = _simMeses.round();
    // Días entre fechas; si no hay rango, se asume meses × 30.
    final dias = (_simDesde != null && _simHasta != null)
        ? _simHasta!.difference(_simDesde!).inDays.clamp(0, 100000)
        : meses * 30;
    final tasaDiaria = (_simTasa / 100) / 30; // tasa mensual → diaria
    final valorDiario = _simMonto * tasaDiaria; // interés que genera por día
    final totalIntereses = valorDiario * dias;
    final valorTotalDiario = _simMonto + totalIntereses; // capital + interés
    final valorAPagar = valorTotalDiario;
    final cuotaMensual = meses > 0 ? valorAPagar / meses : 0.0;
    final cuotaQuincenal = meses > 0 ? valorAPagar / (meses * 2) : 0.0;
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
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Icon(Icons.credit_card_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  const Text('Gestión de Créditos',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                const Text(
                    'Administra solicitudes, créditos aprobados y simulaciones',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ])),
          const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(children: [
          _creditoTabBtn(0, 'Aprobados'),
          const SizedBox(width: 8),
          _creditoTabBtn(1, 'Pendientes'),
          const SizedBox(width: 8),
          _creditoTabBtn(2, 'Simular Crédito'),
          const SizedBox(width: 8),
          _creditoTabBtn(3, 'Estadística por Fuente'),
        ]),
      ),

      // ── Contenido por sub-tab ───────────────────────────────
      if (_creditoSubTab == 0 || _creditoSubTab == 1) ...[
        // Botones acción
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(
                child: _actionBtn(
                    label: 'AGREGAR DEUDOR',
                    color: _navy,
                    icon: Icons.person_add_rounded,
                    onTap: () => _snack('Agregar deudor próximamente'))),
            const SizedBox(width: 8),
            Expanded(
                child: _actionBtn(
                    label: 'AGREGAR CRÉDITO',
                    color: _navy,
                    icon: Icons.add_card_rounded,
                    onTap: () => _snack('Agregar crédito próximamente'))),
          ]),
        ),
        // Stats Total Pagado / Total Pendiente
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3B3B8A), Color(0xFF5252B4)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('TOTAL PAGADO',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_cop(totalPagado),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ])),
            Container(width: 1, height: 40, color: Colors.white24),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  const Text('TOTAL PENDIENTE',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_cop(totalPendiente),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ])),
          ]),
        ),
        // Filtro Estado — fila compacta alineada
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const Text('Estado',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8899BB))),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F2FA),
                    borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _creditoFiltroEstado.isEmpty
                        ? null
                        : _creditoFiltroEstado,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    hint: const Text('Seleccione',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF8899BB))),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(value: 'activ', child: Text('Activo')),
                      DropdownMenuItem(
                          value: 'inactiv', child: Text('Inactivo')),
                      DropdownMenuItem(
                          value: 'pendiente', child: Text('Pendiente')),
                    ],
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF0D1B4B)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: Color(0xFF8899BB)),
                    onChanged: (v) =>
                        setState(() => _creditoFiltroEstado = v ?? ''),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() {}),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: _navy, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Consultar',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ]),
        ),
        // Lista de créditos
        if (creditosFiltrados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _emptyActivity(),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: creditosFiltrados.map((c) => _creditoCard(c)).toList(),
            ),
          ),
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
              max: 60,
              divisions: 59,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => setState(() => _simMeses = v),
            ),
            const SizedBox(height: 8),
            _simLabel('Monto solicitado: ${_cop(_simMonto)}'),
            Slider(
              value: _simMonto,
              min: 100000,
              max: 50000000,
              divisions: 100,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => setState(() => _simMonto = v),
            ),
            const SizedBox(height: 8),
            _simLabel('Tasa interés mensual: ${_simTasa.toStringAsFixed(1)}%'),
            Slider(
              value: _simTasa,
              min: 0.5,
              max: 10,
              divisions: 19,
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
                _simResultRow('Valor Diario', _cop(valorDiario)),
                _simResultRow(
                    'Valor total con intereses diarios', _cop(valorTotalDiario)),
                _simResultRow('Cuota Mensual', _cop(cuotaMensual)),
                _simResultRow('Cuota Quincenal', _cop(cuotaQuincenal)),
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


  // ── Estadística por Fuente — barras horizontales ─────────────
  Widget _estadisticaCreditosWidget() {
    if (_creditos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: _emptyActivity(),
      );
    }

    // Auto-detectar nombres de campo desde el primer registro
    final first = _creditos.first;
    final allKeys = first.keys.toList();
    debugPrint('[SAF] stat keys: $allKeys');
    debugPrint('[SAF] stat first: $first');

    const fuenteKeys = [
      'fuente',
      'nombre_fuente',
      'cuenta',
      'nombre',
      'nombre_cuenta',
      'cuenta_fuente',
      'nombre_origen',
      'origen'
    ];
    const salidasKeys = [
      'total_salidas',
      'salidas',
      'creditos_otorgados',
      'total_creditos',
      'prestado',
      'total_prestado',
      'valor_credito'
    ];
    const entradasKeys = [
      'total_entradas',
      'entradas',
      'cuotas_pagadas',
      'total_cuotas',
      'cobrado',
      'total_cobrado',
      'total_pagado',
      'valor_cobrado'
    ];

    var fk =
        fuenteKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    if (fk.isEmpty) {
      fk = allKeys.firstWhere(
          (k) => first[k] is String && (first[k] as String).isNotEmpty,
          orElse: () => allKeys.first);
    }
    var sk =
        salidasKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    var ek =
        entradasKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');

    // Fallback: usar campos numéricos por posición
    final numKeys = allKeys.where((k) => _num(first[k]) > 0).toList();
    if (sk.isEmpty && numKeys.isNotEmpty) sk = numKeys[0];
    if (ek.isEmpty && numKeys.length >= 2) ek = numKeys[1];

    debugPrint('[SAF] detect → fuente=$fk  salidas=$sk  entradas=$ek');

    String labelOf(Map<String, dynamic> d) => (d[fk] ?? '?').toString();
    double salidasOf(Map<String, dynamic> d) => _num(d[sk]);
    double entradasOf(Map<String, dynamic> d) => _num(d[ek]);

    final totalSalidas = _creditos.fold(0.0, (s, d) => s + salidasOf(d));
    final totalEntradas = _creditos.fold(0.0, (s, d) => s + entradasOf(d));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Balance de valores por fuente',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        _barChartSection(
          title: 'Salidas por fuente (Créditos otorgados)',
          barColor: const Color(0xFF3B3B8A),
          data: _creditos,
          labelFn: labelOf,
          valueFn: salidasOf,
          total: totalSalidas,
          totalLabel: 'Total salidas',
        ),
        const SizedBox(height: 20),
        _barChartSection(
          title: 'Entradas por fuente (Cuotas pagadas)',
          barColor: const Color(0xFF16A34A),
          data: _creditos,
          labelFn: labelOf,
          valueFn: entradasOf,
          total: totalEntradas,
          totalLabel: 'Total entradas',
        ),
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
        // Barras horizontales
        ...sorted.map((d) {
          final val = valueFn(d);
          final pct = val / maxVal;
          final name = labelFn(d);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(
                width: 76,
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8899BB))),
              ),
              const SizedBox(width: 8),
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
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          )),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
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

  Widget _creditoTabBtn(int index, String label) {
    final active = _creditoSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _creditoSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF3B3B8A) : Colors.transparent,
              width: 2,
            ),
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active
                    ? const Color(0xFF3B3B8A)
                    : const Color(0xFF8899BB))),
      ),
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
                    color: value == null
                        ? const Color(0xFF94A3B8)
                        : navy),
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
                      fontWeight:
                          destacado ? FontWeight.w800 : FontWeight.w500,
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

  // ══════════════════════════════════════════════════════════════
  //  AHORRADORES TAB
  // ══════════════════════════════════════════════════════════════
  Widget _ahorradoresTab() {
    if (_loadingData) return _loadingView();

    const navy = Color(0xFF0D1B4B);

    // Años disponibles: 2020..año actual
    final currentYear = DateTime.now().year;
    final anios = List.generate(
        currentYear - 2019, (i) => (currentYear - i).toString());

    // Asesores: todos los conocidos (igual que la web) + cualquiera presente
    // en los datos, ordenados por nombre completo.
    final asesorSet = <String>{..._asesorNombres.keys};
    for (final a in _ahorradores) {
      final v = (a['asesor'] ?? '').toString().trim().toUpperCase();
      if (v.isNotEmpty) asesorSet.add(v);
    }
    final asesorOrdenados = asesorSet.toList()
      ..sort((a, b) =>
          _nombreAsesor(a).toLowerCase().compareTo(_nombreAsesor(b).toLowerCase()));
    final asesores = ['0', ...asesorOrdenados];

    final lista = _ahorradoresFiltrados;
    final total = lista.fold(
        0.0,
        (s, a) =>
            s + _num(a['total_ahorrado'] ?? a['valor_pactado'] ?? a['monto'] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Botones de acción ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _actionBtn(
                icon: Icons.person_add_rounded,
                label: 'Agregar Ahorrador',
                color: navy,
                onTap: () => _snack('Agregar ahorrador próximamente')),
            _actionBtn(
                icon: Icons.savings_rounded,
                label: 'Agregar Ahorro',
                color: navy,
                onTap: () => _snack('Agregar ahorro próximamente')),
            _actionBtn(
                icon: Icons.settings_rounded,
                label: 'Configurar Ahorro',
                color: navy,
                onTap: () => _snack('Configurar ahorro próximamente')),
          ]),
        ),

        // ── Filtros Año / Asesor ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Año:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: navy)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButton<String>(
                      value: _ahorFilterAnio,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                          color: navy, fontWeight: FontWeight.w600, fontSize: 14),
                      items: anios
                          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _ahorFilterAnio = v);
                        _reloadAhorradores();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Asesor:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: navy)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButton<String>(
                      value: asesores.contains(_ahorFilterAsesor)
                          ? _ahorFilterAsesor
                          : '0',
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                          color: navy, fontWeight: FontWeight.w600, fontSize: 14),
                      items: asesores
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                    s == '0' ? 'Todos' : _nombreAsesor(s),
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      // Filtrado del lado del cliente (sin recargar del servidor)
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _ahorFilterAsesor = v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Header card ──────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.savings_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Ahorradores',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12)),
              const SizedBox(height: 4),
              Text('${lista.length} registrados',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Total ahorrado',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11)),
              const SizedBox(height: 4),
              Text(_cop(total),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ]),
          ]),
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _sectionTitle(lista.isEmpty
              ? 'Sin ahorradores para los filtros seleccionados'
              : 'Lista de Ahorradores'),
        ),
        const SizedBox(height: 10),
        if (lista.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text('No hay ahorradores para los filtros seleccionados',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8899BB))),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ahoradorCard(lista[i]),
          ),
      ],
    );
  }

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

    final totalSaldo =
        _cuentas.fold(0.0, (s, c) => s + _num(c['saldo_actual'] ?? 0));
    final filtrados = _movimientosFiltrados;
    final gastos = filtrados
        .where((m) => (m['tipo_movimiento'] ?? '').toString() == '2')
        .fold(0.0, (s, m) => s + _num(m['valor'] ?? 0));
    final ingresos = filtrados.where((m) {
      final t = (m['tipo_movimiento'] ?? '').toString();
      return t == '3' || t == '1';
    }).fold(0.0, (s, m) => s + _num(m['valor'] ?? 0));
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
                onTap: () => _snack('Nueva Cuenta/Fuente próximamente'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _actionBtn(
                  label: '⇄ Movimientos',
                  color: _navy,
                  onTap: () => setState(() => _movSubTab = 1),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: _actionBtn(
                  label: '⇄ Transferir',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _snack('Transferir entre cuentas próximamente'),
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
                Text(_cop(totalSaldo),
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
          // ── MOVIMIENTOS: botones de acción ────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              Expanded(
                  child: _actionBtn(
                label: '+ Nuevo Movimiento',
                color: _navy,
                onTap: () => _snack('Nuevo movimiento próximamente'),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _actionBtn(
                label: 'Consultar',
                color: const Color(0xFF0EA5E9),
                icon: Icons.search_rounded,
                onTap: () => _snack('Consulta avanzada próximamente'),
              )),
            ]),
          ),
          // ── Filtros ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            padding: const EdgeInsets.all(14),
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
            child: Column(children: [
              // Fila 1: Cuenta | Tipo
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
                  onChanged: (v) => setState(() => _filterCuenta = v ?? ''),
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
                  onChanged: (v) => setState(() => _filterTipo = v ?? ''),
                )),
              ]),
              const SizedBox(height: 10),
              // Fila 2: Desde | Hasta
              Row(children: [
                Expanded(
                    child: _filterDate(
                  label: 'Desde',
                  value: _filterDesde,
                  onPick: (d) => setState(() => _filterDesde = d),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _filterDate(
                  label: 'Hasta',
                  value: _filterHasta,
                  onPick: (d) => setState(() => _filterHasta = d),
                )),
              ]),
              // Limpiar filtros (si hay alguno activo)
              if (_filterCuenta.isNotEmpty ||
                  _filterTipo.isNotEmpty ||
                  _filterDesde != null ||
                  _filterHasta != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _filterCuenta = '';
                      _filterTipo = '';
                      _filterDesde = null;
                      _filterHasta = null;
                    }),
                    child: const Text('Limpiar filtros',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ),
                ),
            ]),
          ),
          // ── Stats ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              Expanded(
                  child: _statPill(
                      Icons.arrow_upward_rounded,
                      'Gastos',
                      _cop(gastos),
                      const Color(0xFFDC2626),
                      const Color(0xFFFEE2E2))),
              const SizedBox(width: 8),
              Expanded(
                  child: _statPill(
                      Icons.arrow_downward_rounded,
                      'Ingresos',
                      _cop(ingresos),
                      const Color(0xFF16A34A),
                      const Color(0xFFDCFCE7))),
              const SizedBox(width: 8),
              Expanded(
                  child: _statPill(
                      Icons.account_balance_rounded,
                      'Balance',
                      _cop(balance),
                      balance >= 0
                          ? _accent1
                          : const Color.fromARGB(255, 37, 143, 204),
                      balance >= 0
                          ? const Color(0xFFEEF0FF)
                          : const Color.fromARGB(255, 206, 223, 243))),
            ]),
          ),
          // ── Lista movimientos ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Movimientos'),
                Text('${filtrados.length} registros',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8899BB))),
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
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
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
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

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
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14, color: _navy)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tipo,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
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
              onTap: () => _snack('Editar cuenta próximamente'),
            ),
            const SizedBox(width: 6),
            _iconActionBtn(
              icon: Icons.balance_rounded,
              color: const Color(0xFF0EA5E9),
              onTap: () => _snack('Movimientos de cuenta próximamente'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          // Color dot de la cuenta
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  isIngreso ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIngreso
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color:
                  isIngreso ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _navy)),
                const SizedBox(height: 2),
                Text(
                  cuentaNom.isNotEmpty ? '$cuentaNom · $fecha' : fecha,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF8899BB)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${isIngreso ? '+' : '-'}${_cop(valor)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isIngreso
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _snack('Eliminar movimiento próximamente'),
                child: const Icon(Icons.cancel_rounded,
                    size: 20, color: Color(0xFFCBD5E1)),
              ),
            ],
          ),
        ]),
      ),
      if (divider)
        Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            endIndent: 16,
            color: Colors.grey.withValues(alpha: 0.12)),
    ]);
  }

  // ══════════════════════════════════════════════════════════════
  //  ESTADÍSTICA TAB
  // ══════════════════════════════════════════════════════════════
  // Definición de las 8 sub-pestañas: (título, codigo_consulta, columnas)
  // Cada columna: (encabezado, clave en el JSON, alineadoDerecha)
  static const List<
      (String, String, List<(String, String, bool)>)> _estTabs = [
    ('Pagan Puntual', 'json_est_pagan_puntual', [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('A tiempo', 'puntuales', true),
      ('% Puntual', 'porcentaje', true),
    ]),
    ('Más Créditos', 'json_est_mas_creditos', [
      ('Cliente', 'cliente', false),
      ('Cantidad', 'cantidad', true),
      ('Monto Total', 'monto', true),
    ]),
    ('Mayor Monto', 'json_est_mayor_monto', [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('Monto Total', 'monto', true),
    ]),
    ('Mayor Antigüedad', 'json_est_mayor_antiguedad', [
      ('Cliente', 'cliente', false),
      ('Primer Crédito', 'fecha', false),
      ('Antigüedad', 'antiguedad', true),
    ]),
    ('Más Retrasos', 'json_est_mas_retrasos', [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('Retrasos', 'retrasos', true),
    ]),
    ('Nuevos Clientes', 'json_est_nuevos_clientes', [
      ('Cliente', 'cliente', false),
      ('Fecha Ingreso', 'fecha', false),
      ('Primer Monto', 'monto', true),
    ]),
    ('Mejor Scoring', 'listado_mejor_scoring', [
      ('Cliente', 'cliente', false),
      ('Cantidad de Créditos', 'cantidad_creditos', true),
      ('Puntaje Total', 'puntaje_total', true),
      ('Índice Promedio', 'indice_promedio', true),
    ]),
    ('Pagos Anticipados', 'json_est_pagos_anticipados', [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('Anticipados', 'anticipados', true),
    ]),
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

          // ── Grid de sub-pestañas (2 columnas, igual que la web) ──
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

          // ── Filtros por columna (uno por cada columna, como la web) ──
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
    final hint = esCliente
        ? 'Buscar cliente'
        : 'Filtrar ${col.$1.toLowerCase()}';
    return TextField(
      // El key incluye la pestaña: al cambiar de sub-pestaña el campo se
      // recrea vacío (sin necesidad de un controller que haya que liberar).
      key: ValueKey('estfiltro_${_estSubTab}_${col.$2}'),
      keyboardType: col.$3 ? TextInputType.number : TextInputType.text,
      onChanged: (v) => setState(() {
        if (v.isEmpty) {
          _estFiltros.remove(col.$2);
        } else {
          _estFiltros[col.$2] = v;
        }
        _estPage = 0;
      }),
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
    final metricas = cols.skip(1).toList(); // columnas numéricas

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
          // Cliente + ranking
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('$rank',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: navy)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(cliente,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: navy)),
            ),
          ]),
          const SizedBox(height: 12),
          // Métricas en fila
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
                              color: Color(0xFF7C3AED))),
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
    int desde = (pagina - 2).clamp(0, (totalPaginas - 5).clamp(0, totalPaginas));
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                          )),
                      const SizedBox(height: 2),
                      Text(name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
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

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    required String badge,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                      color: bgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: bgColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(badge,
                      style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8899BB),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ],
        ),
      );

  Widget _cuentaChip(Map<String, dynamic> c) {
    final nombre = (c['nombre'] ?? c['name'] ?? 'Cuenta').toString();
    final tipo = (c['tipo'] ?? c['type'] ?? '').toString().toLowerCase();
    final saldo = _num(c['saldo_actual'] ?? c['saldo'] ?? 0);
    final color = _cuentaColor(tipo);

    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(_cuentaIcon(tipo), color: color, size: 14),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const Spacer(),
          Text(nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A4A7A))),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(_cop(saldo),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: saldo >= 0 ? _navy : const Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  Widget _creditoCard(Map<String, dynamic> c) {
    final nombre =
        (c['cliente'] ?? c['nombre'] ?? c['name'] ?? 'Cliente').toString();
    final monto = _num(c['monto'] ?? c['valor'] ?? c['amount'] ?? 0);
    final cuota = _num(c['cuota'] ?? c['cuota_mensual'] ?? 0);
    final estado = (c['estado'] ?? 'Activo').toString();
    final activo = estado.toLowerCase().contains('activ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.credit_card_rounded,
                color: Color(0xFF34D399), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _navy)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Monto: ${_cop(monto)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8899BB))),
                    if (cuota > 0) ...[
                      const Text(' · ',
                          style: TextStyle(color: Color(0xFF8899BB))),
                      Text('Cuota: ${_cop(cuota)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8899BB))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: activo ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(estado,
                style: TextStyle(
                  color: activo
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }

  Widget _ahoradorCard(Map<String, dynamic> a) =>
      _AhoradorExpandable(data: a, cop: _cop, num: _num);

  Widget _statPill(
          IconData icon, String label, String value, Color color, Color bg) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color.withValues(alpha: 0.7), fontSize: 9.5)),
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

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
        color: _navy,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ));

  Widget _profileSheet(String email) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _accent1.withValues(alpha: 0.35), width: 2.5),
                boxShadow: [
                  BoxShadow(
                      color: _accent1.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 6))
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
            const SizedBox(height: 14),
            Text(_fullName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _logout();
                },
                icon: const Icon(Icons.logout_rounded,
                    color: Color(0xFFE53935), size: 20),
                label: const Text('Cerrar sesión',
                    style: TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
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

  static String _tipoOf(Map<String, dynamic> m) =>
      (m['tipo'] ?? m['type'] ?? m['movimiento'] ?? '')
          .toString()
          .toLowerCase();

  static Map<String, dynamic> _json(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return {};
  }

  static String _cop(double amount) {
    final n = amount.abs().toInt();
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '\$ ${buf.toString()}';
  }

  static Color _cuentaColor(String tipo) {
    switch (tipo) {
      case 'ingreso':
        return const Color(0xFF16A34A);
      case 'crédito':
      case 'credito':
        return const Color(0xFFF59E0B);
      case 'gasto':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4361EE);
    }
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

  static const _purple = Color(0xFF7C3AED);
  static const _navy   = Color(0xFF0D1B4B);

  @override
  Widget build(BuildContext context) {
    final a        = widget.data;
    final nombre   = (a['ahorrador'] ?? a['nombre'] ?? 'Ahorrador').toString();
    final asesor   = (a['asesor'] ?? '').toString();
    final total    = widget.num(a['total_ahorrado'] ?? a['valor_pactado'] ?? 0);
    final pactado  = widget.num(a['valor_pactado'] ?? 0);
    final neto     = widget.num(a['neto_pagar'] ?? a['neto'] ?? 0);
    final rend     = widget.num(a['porcentaje'] ?? 0);
    final fecha    = (a['Fecha_ingreso'] ?? a['fecha_ingreso'] ?? '').toString();
    final cuotas   = a['ahorros'];
    final List<Map<String, dynamic>> meses = cuotas is List
        ? cuotas.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList()
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

    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? _purple.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? _purple.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _expanded ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                // Avatar
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _navy)),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (asesor.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Asesor: $asesor',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _purple)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (enMora)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('En mora',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626))),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Al día',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A))),
                        ),
                    ]),
                  ],
                )),
                // Total + chevron
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(widget.cop(total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _purple)),
                  const Text('ahorrado',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8899BB))),
                  const SizedBox(height: 4),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_anim),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: Color(0xFF8899BB)),
                  ),
                ]),
              ]),
            ),

            // ── Detalle expandible ───────────────────────────────
            SizeTransition(
              sizeFactor: _anim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),

                  // Ficha de datos
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Wrap(spacing: 12, runSpacing: 10, children: [
                      _detailChip('Fecha ingreso', fecha.length >= 10
                          ? fecha.substring(0, 10) : fecha),
                      _detailChip('Valor pactado', widget.cop(pactado)),
                      _detailChip('Rendimiento', '${rend.toStringAsFixed(1)}%'),
                      _detailChip('Neto a pagar', widget.cop(neto)),
                    ]),
                  ),

                  // Cuotas mensuales — scroll horizontal
                  if (meses.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text('Cuotas mensuales',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _navy)),
                    ),
                    SizedBox(
                      height: 82,
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
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8899BB),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _purple)),
        ]),
      );

  // Fecha actual en Colombia (UTC-5, sin horario de verano), sólo Y-M-D.
  static DateTime _hoyColombia() {
    final n = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    return DateTime(n.year, n.month, n.day);
  }

  Widget _mesChip(Map<String, dynamic> m) {
    final mes        = (m['nombre_mes'] ?? '').toString();
    final estadoPago = (m['estado_pago'] ?? '').toString();
    final valor      = widget.num(m['valor_pagado'] ?? m['valor'] ?? 0);
    final fc         = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
    final vencida    = fc != null &&
        !DateTime(fc.year, fc.month, fc.day).isAfter(_hoyColombia());

    final esPagado = estadoPago.toLowerCase().contains('pagado');
    // Vencida y sin pagar → roja; futura sin pagar → gris (pendiente).
    final esNoPago = !esPagado && vencida;
    final esFuturo = !esPagado && !vencida;

    final bgColor = esPagado
        ? const Color(0xFFDCFCE7)
        : esNoPago
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFF0F2FA);
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

    return Container(
      width: 82,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(height: 4),
          Text(mes,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 2),
          Text(
            esFuturo ? '\$ 0' : widget.cop(valor),
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: textColor),
          ),
        ],
      ),
    );
  }
}
