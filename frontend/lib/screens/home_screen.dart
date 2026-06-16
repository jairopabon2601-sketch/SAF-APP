import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/saf_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Services & controllers ──────────────────────────────────────
  final _api = ApiService();

  // ── UI state ────────────────────────────────────────────────────
  bool _balanceVisible = true;
  int _selectedIndex = 0;

  // ── Data state ──────────────────────────────────────────────────
  bool _loadingData = true;
  List<Map<String, dynamic>> _cuentas = [];
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _ahorradores = [];
  List<Map<String, dynamic>> _creditos = [];

  // ── Computed ────────────────────────────────────────────────────
  double get _totalSaldo => _cuentas.fold(0.0,
      (s, c) => s + _num(c['saldo_actual'] ?? c['saldo'] ?? c['balance'] ?? 0));

  double get _totalIngresos => _movimientos
      .where((m) => _tipoOf(m) == 'ingreso')
      .fold(0.0, (s, m) => s + _num(m['valor'] ?? m['amount'] ?? m['monto'] ?? 0));

  double get _totalEgresos => _movimientos
      .where((m) => _tipoOf(m) == 'gasto')
      .fold(0.0, (s, m) => s + _num(m['valor'] ?? m['amount'] ?? m['monto'] ?? 0));

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
    _loadData();
  }


  // ── Data loading ────────────────────────────────────────────────
  Future<void> _loadData() async {
    await _api.init();
    // Debug: identify actual API field names
    debugPrint('[SAF] user keys: ${_api.user?.keys.toList()}');
    debugPrint('[SAF] user: ${_api.user}');

    await Future.wait([
      _fetchList('/api/cuentas/listar.php',
          keys: const ['cuentas', 'data', 'resultado_data'],
          out: (v) => _cuentas = v),
      _fetchList('/api/movimientos/listar.php',
          keys: const ['movimientos', 'data', 'resultado_data'],
          out: (v) => _movimientos = v),
      _fetchList('/api/ahorradores/listar.php',
          keys: const ['ahorradores', 'data', 'resultado_data'],
          out: (v) => _ahorradores = v),
      _fetchList('/api/creditos/listar.php',
          keys: const ['creditos', 'prestamos', 'data'],
          out: (v) => _creditos = v),
    ]);

    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _fetchList(String endpoint,
      {required List<String> keys,
      required void Function(List<Map<String, dynamic>>) out}) async {
    try {
      final r = await _api.get(endpoint);
      if (r.statusCode == 200) {
        final d = _json(r.body);
        for (final k in keys) {
          final v = d[k];
          if (v is List) {
            out(v.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList());
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] $endpoint: $e');
    }
  }

  // ── User helpers ────────────────────────────────────────────────
  String get _fullName {
    final u = _api.user;
    if (u == null) return 'Usuario';
    // Try separate first + last name fields (most common in Spanish PHP apps)
    for (final nk in ['nombre', 'nombres', 'primer_nombre', 'p_nombre', 'firstname', 'first_name']) {
      for (final ak in ['apellido', 'apellidos', 'primer_apellido', 'p_apellido', 'lastname', 'last_name']) {
        final n = (u[nk] ?? '').toString().trim();
        final a = (u[ak] ?? '').toString().trim();
        if (n.isNotEmpty && a.isNotEmpty) return '$n $a';
      }
    }
    // Try full-name fields
    for (final k in ['nombre', 'nombres', 'nombre_completo', 'nombreCompleto',
                     'nombre_usuario', 'fullname', 'full_name', 'name', 'usuario']) {
      final v = (u[k] ?? '').toString().trim();
      if (v.isNotEmpty && v.contains(' ')) return v; // prefer multi-word
    }
    for (final k in ['nombre', 'nombres', 'name', 'usuario', 'email', 'correo']) {
      final v = (u[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return 'Usuario';
  }

  String get _photoUrl {
    final u = _api.user;
    if (u == null) return '';
    for (final k in [
      'foto', 'imagen', 'avatar', 'photo', 'fotografia',
      'foto_perfil', 'imagen_perfil', 'profile_photo',
      'profile_picture', 'profile_image', 'picture', 'img',
    ]) {
      final raw = (u[k] ?? '').toString().trim();
      if (raw.isNotEmpty && raw != 'null') {
        if (raw.startsWith('http')) return raw;
        return 'https://safenlinea.com/$raw';
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
                        .map((e) => _movimientoItem(e.value,
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
  Widget _creditosTab() {
    if (_loadingData) return _loadingView();
    if (_creditos.isEmpty) {
      return _emptyTab(Icons.credit_card_rounded, 'Créditos',
          'No hay créditos activos', const Color(0xFF34D399));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: _creditos.length,
      itemBuilder: (_, i) => _creditoCard(_creditos[i]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  AHORRADORES TAB
  // ══════════════════════════════════════════════════════════════
  Widget _ahorradoresTab() {
    if (_loadingData) return _loadingView();
    if (_ahorradores.isEmpty) {
      return _emptyTab(Icons.savings_rounded, 'Ahorradores',
          'No hay ahorradores registrados', const Color(0xFFA78BFA));
    }

    final total = _ahorradores.fold(0.0,
        (s, a) => s + _num(a['total_ahorrado'] ?? a['valor_pactado'] ?? a['monto'] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
                color: const Color(0xFF7B2FBE).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.savings_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Ahorradores',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${_ahorradores.length} registrados',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total ahorrado',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(_cop(total),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _sectionTitle('Lista de Ahorradores'),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: _ahorradores.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ahoradorCard(_ahorradores[i]),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  MOVIMIENTOS TAB (Gestión de Gastos)
  // ══════════════════════════════════════════════════════════════
  Widget _movimientosTab() {
    if (_loadingData) return _loadingView();

    final ingresos = _totalIngresos;
    final gastos = _totalEgresos;
    final balance = ingresos - gastos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: _statPill(Icons.arrow_downward_rounded,
                    'Total Gastos', _cop(gastos), const Color(0xFFDC2626),
                    const Color(0xFFFEE2E2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statPill(Icons.arrow_upward_rounded,
                    'Total Ingresos', _cop(ingresos), const Color(0xFF16A34A),
                    const Color(0xFFDCFCE7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statPill(Icons.account_balance_rounded,
                    'Balance', _cop(balance),
                    balance >= 0 ? _accent1 : const Color(0xFFDC2626),
                    balance >= 0 ? const Color(0xFFEEF0FF) : const Color(0xFFFEE2E2)),
              ),
            ],
          ),
        ),

        // Cuentas section
        if (_cuentas.isNotEmpty) ...[
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _sectionTitle('Cuentas y Fuentes'),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _cuentas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _cuentaRow(_cuentas[i]),
          ),
        ],

        // Movements list
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _sectionTitle('Movimientos'),
        ),
        const SizedBox(height: 12),
        if (_movimientos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _emptyActivity(),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
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
              children: _movimientos
                  .asMap()
                  .entries
                  .map((e) => _movimientoItem(e.value,
                      divider: e.key < _movimientos.length - 1))
                  .toList(),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ESTADÍSTICA TAB
  // ══════════════════════════════════════════════════════════════
  Widget _estadisticaTab() {
    return _emptyTab(Icons.bar_chart_rounded, 'Estadística',
        'Reportes y análisis financiero', const Color(0xFFFBBF24));
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
                  onTap: () => setState(() => _selectedIndex = i),
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
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
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
                              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
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
            top: -20, right: -20,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30, right: 40,
            child: Container(
              width: 80, height: 80,
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
                  _balanceMini(Icons.savings_rounded, 'Ahorros',
                      _cop(_ahorradores.fold(0.0, (s, a) => s + _num(a['total_ahorrado'] ?? a['monto'] ?? 0)))),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.2),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 14)),
                  _balanceMini(Icons.credit_score_rounded, 'Créditos',
                      _creditos.length.toString()),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.2),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 14)),
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
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6)),
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
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
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

  Widget _cuentaRow(Map<String, dynamic> c) {
    final nombre = (c['nombre'] ?? c['name'] ?? 'Cuenta').toString();
    final tipo = (c['tipo'] ?? c['type'] ?? '').toString().toLowerCase();
    final saldo = _num(c['saldo_actual'] ?? c['saldo'] ?? 0);
    final estado = (c['estado'] ?? 'Activa').toString();
    final color = _cuentaColor(tipo);

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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(_cuentaIcon(tipo), color: color, size: 20),
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
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tipo.isNotEmpty ? _capitalize(tipo) : 'Cuenta',
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Text(estado,
                        style: const TextStyle(
                            color: Color(0xFF8899BB), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Text(_cop(saldo),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: saldo >= 0 ? _navy : const Color(0xFFDC2626),
              )),
        ],
      ),
    );
  }

  Widget _movimientoItem(Map<String, dynamic> m, {bool divider = false}) {
    final desc =
        (m['descripcion'] ?? m['description'] ?? m['concepto'] ?? 'Movimiento')
            .toString();
    final cuenta = (m['cuenta'] ?? m['account'] ?? '').toString();
    final tipo = _tipoOf(m);
    final valor = _num(m['valor'] ?? m['amount'] ?? m['monto'] ?? 0);
    final fecha = (m['fecha'] ?? m['date'] ?? '').toString();
    final isIngreso = tipo == 'ingreso';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isIngreso
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIngreso
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isIngreso
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  size: 18,
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
                          color: _navy,
                        )),
                    const SizedBox(height: 3),
                    Text(
                      cuenta.isNotEmpty ? '$cuenta · $fecha' : fecha,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF8899BB)),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIngreso ? '+' : '-'}${_cop(valor)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isIngreso
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
        if (divider)
          Divider(
              height: 1,
              thickness: 1,
              indent: 68,
              endIndent: 16,
              color: Colors.grey.withValues(alpha: 0.12)),
      ],
    );
  }

  Widget _creditoCard(Map<String, dynamic> c) {
    final nombre = (c['cliente'] ?? c['nombre'] ?? c['name'] ?? 'Cliente').toString();
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
            width: 44, height: 44,
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
                        fontWeight: FontWeight.w700, fontSize: 14, color: _navy)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Monto: ${_cop(monto)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8899BB))),
                    if (cuota > 0) ...[
                      const Text(' · ', style: TextStyle(color: Color(0xFF8899BB))),
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
              color: activo
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFF3F4F6),
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

  Widget _ahoradorCard(Map<String, dynamic> a) {
    final nombre = (a['nombre'] ?? a['ahorrador'] ?? a['name'] ?? 'Ahorrador').toString();
    final asesor = (a['asesor'] ?? '').toString();
    final total = _num(a['total_ahorrado'] ?? a['valor_pactado'] ?? a['monto'] ?? 0);
    final fecha = (a['fecha_ingreso'] ?? a['fecha'] ?? '').toString();

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
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _navy)),
                const SizedBox(height: 3),
                Text(
                  [if (asesor.isNotEmpty) 'Asesor: $asesor',
                   if (fecha.isNotEmpty) fecha].join(' · '),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8899BB)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_cop(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF7C3AED))),
              const SizedBox(height: 2),
              const Text('ahorrado',
                  style: TextStyle(fontSize: 10, color: Color(0xFF8899BB))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label, String value, Color color, Color bg) =>
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
                style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9.5)),
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

  Widget _emptyTab(IconData icon, String title, String subtitle, Color color) =>
      SizedBox(
        height: 460,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24)),
                child: Icon(icon, color: color, size: 38),
              ),
              const SizedBox(height: 18),
              Text(title,
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF8899BB), fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text('Próximamente',
                    style: TextStyle(
                        color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
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
                border:
                    Border.all(color: _accent1.withValues(alpha: 0.35), width: 2.5),
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
            // DEBUG: remove after confirming field names
            if (_api.user != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'API fields: ${_api.user!.keys.join(', ')}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text('⚠ user is null',
                  style: TextStyle(fontSize: 11, color: Colors.red)),
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
  static double _num(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

  static String _tipoOf(Map<String, dynamic> m) =>
      (m['tipo'] ?? m['type'] ?? m['movimiento'] ?? '').toString().toLowerCase();

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

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
