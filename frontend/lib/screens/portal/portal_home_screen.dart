import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/portal_service.dart';
import 'portal_login_screen.dart';
import 'portal_widgets.dart';

double _n(dynamic v) => double.tryParse((v ?? '0').toString()) ?? 0;
int _i(dynamic v) => int.tryParse((v ?? '0').toString()) ?? 0;

/// Estado de los créditos del cliente (solo lectura).
class PortalHomeScreen extends StatefulWidget {
  const PortalHomeScreen({super.key});

  @override
  State<PortalHomeScreen> createState() => _PortalHomeScreenState();
}

class _PortalHomeScreenState extends State<PortalHomeScreen> {
  final _portal = PortalService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final d = await _portal.misCreditos();
      if (!mounted) return;
      if (d['sesion_expirada'] == true) {
        await _portal.logout();
        _irALogin();
        return;
      }
      if (d['success'] != true) {
        setState(() => _error =
            (d['mensaje'] ?? 'No se pudo cargar tu información.').toString());
        return;
      }
      setState(() => _data = d);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Error de conexión. Revisa tu internet e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _irALogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PortalLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _salir() async {
    HapticFeedback.lightImpact();
    await _portal.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cliente = (_data?['cliente'] as Map?) ?? _portal.cliente ?? {};
    final nombre = (cliente['nombre'] ?? '').toString();
    final primer = nombre.split(' ').first;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF020714),
        body: PortalBackground(
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              _header(nombre),
              Expanded(
                child: RefreshIndicator(
                  color: portalCyan,
                  backgroundColor: const Color(0xFF0B1230),
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(
                        16, 8, 16, 32 + MediaQuery.of(context).padding.bottom),
                    children: [
                      PortalEntrance(
                        child: Text('Hola${primer.isNotEmpty ? ', $primer' : ''} 👋',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      const PortalEntrance(
                        delayMs: 60,
                        child: Text('Este es el estado de tu crédito hoy.',
                            style:
                                TextStyle(color: portalTextSoft, fontSize: 14)),
                      ),
                      const SizedBox(height: 18),
                      ..._contenido(),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header(String nombre) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(children: [
          const PortalLogo(size: 40, animated: false),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PORTAL DE CLIENTES',
                    style: TextStyle(
                        color: Color(0xFF9DA8FF),
                        fontSize: 9.5,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800)),
                Text(nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _cargar,
            icon: AnimatedRotation(
              turns: _loading ? 1 : 0,
              duration: const Duration(milliseconds: 700),
              child: const Icon(Icons.refresh_rounded, color: Colors.white70),
            ),
          ),
          Material(
            color: const Color(0xFFEF4444).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _salir,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFFECACA), size: 16),
                  SizedBox(width: 5),
                  Text('Salir',
                      style: TextStyle(
                          color: Color(0xFFFECACA),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ]),
              ),
            ),
          ),
        ]),
      );

  List<Widget> _contenido() {
    if (_loading && _data == null) {
      return [
        for (final h in [168.0, 96.0, 300.0])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _Skeleton(height: h),
          ),
      ];
    }
    if (_data == null) {
      return [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: portalGlass(),
          child: Column(children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFFBBF24), size: 34),
            const SizedBox(height: 10),
            Text(_error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ]),
        ),
      ];
    }
    final resumen = (_data!['resumen'] as Map?) ?? {};
    final proximo = resumen['proximo_pago'] is Map
        ? Map<String, dynamic>.from(resumen['proximo_pago'] as Map)
        : null;
    final creditos = ((_data!['creditos'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return [
      PortalEntrance(delayMs: 80, child: _ProximoPago(proximo: proximo)),
      const SizedBox(height: 14),
      PortalEntrance(
        delayMs: 160,
        child: Row(children: [
          Expanded(
            child: _Resumen(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Saldo pendiente',
              value: _n(resumen['saldo_pendiente']),
              color: const Color(0xFF9DA8FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Resumen(
              icon: Icons.event_available_rounded,
              label: 'Total pagado',
              value: _n(resumen['total_pagado']),
              color: const Color(0xFF6EE7B7),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < creditos.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: PortalEntrance(
            delayMs: 240 + i * 80,
            child: _CreditoCard(credito: creditos[i], inicialAbierto: i == 0),
          ),
        ),
      const SizedBox(height: 6),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 14),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Vista de solo consulta. Para pagos o cambios comunícate con tu asesor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: portalTextSoft, fontSize: 11),
          ),
        ),
      ]),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Skeleton extends StatefulWidget {
  const _Skeleton({required this.height});
  final double height;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: FadeTransition(
          opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      );
}

class _ProximoPago extends StatelessWidget {
  const _ProximoPago({required this.proximo});
  final Map<String, dynamic>? proximo;

  @override
  Widget build(BuildContext context) {
    final p = proximo;
    if (p == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF059669)]),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 12)),
          ],
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¡Estás al día!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text('No tienes cuotas pendientes.',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ]),
      );
    }
    final dias = _i(p['dias']);
    final List<Color> grad;
    final String txt;
    final Color glow;
    if (dias < 0) {
      grad = const [Color(0xFF7F1D1D), Color(0xFFB91C1C), Color(0xFFEF4444)];
      txt = 'Vencida hace ${-dias} día${dias == -1 ? '' : 's'}';
      glow = const Color(0xFFEF4444);
    } else if (dias == 0) {
      grad = const [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFF59E0B)];
      txt = 'Vence hoy';
      glow = const Color(0xFFF59E0B);
    } else if (dias <= 3) {
      grad = const [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFFF59E0B)];
      txt = 'Faltan $dias día${dias == 1 ? '' : 's'}';
      glow = const Color(0xFFF59E0B);
    } else {
      grad = const [Color(0xFF1E1B4B), Color(0xFF5B54F5), Color(0xFF3B82F6)];
      txt = 'Faltan $dias días';
      glow = const Color(0xFF5B54F5);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
            colors: grad,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: glow.withValues(alpha: 0.40),
              blurRadius: 34,
              offset: const Offset(0, 14)),
        ],
      ),
      child: PortalShine(
        borderRadius: 26,
        alpha: 0.14,
        period: const Duration(milliseconds: 5000),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.event_rounded,
                        color: Colors.white.withValues(alpha: 0.75), size: 14),
                    const SizedBox(width: 5),
                    Text('TU PRÓXIMO PAGO',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10.5,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PortalCountUp(
                      value: _n(p['valor']),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${portalFechaLarga((p['fecha'] ?? '').toString())} · cuota ${p['numero']}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PulseChip(text: txt, pulse: dias <= 0),
          ]),
        ),
      ),
    );
  }
}

class _PulseChip extends StatefulWidget {
  const _PulseChip({required this.text, required this.pulse});
  final String text;
  final bool pulse;

  @override
  State<_PulseChip> createState() => _PulseChipState();
}

class _PulseChipState extends State<_PulseChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white
                      .withValues(alpha: 0.25 + 0.35 * _c.value)),
              boxShadow: widget.pulse
                  ? [
                      BoxShadow(
                          color: Colors.white
                              .withValues(alpha: 0.10 + 0.20 * _c.value),
                          blurRadius: 12),
                    ]
                  : null,
            ),
            child: Text(widget.text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: portalGlass(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: portalTextSoft,
                    fontSize: 9.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: PortalCountUp(
            value: value,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ]),
    );
  }
}

class _CreditoCard extends StatefulWidget {
  const _CreditoCard({required this.credito, required this.inicialAbierto});
  final Map<String, dynamic> credito;
  final bool inicialAbierto;

  @override
  State<_CreditoCard> createState() => _CreditoCardState();
}

class _CreditoCardState extends State<_CreditoCard> {
  late bool _abierto = widget.inicialAbierto &&
      (widget.credito['estado'] ?? '').toString() != 'Pagado';

  @override
  Widget build(BuildContext context) {
    final c = widget.credito;
    final estado = (c['estado'] ?? '').toString();
    final numCuotas = _i(c['num_cuotas']);
    final pagadas = _i(c['cuotas_pagadas']);
    final totalPagar = _n(c['total_pagar']);
    final totalPagado = _n(c['total_pagado']);
    final vencidas = _i(c['cuotas_vencidas']);
    final cuotas = ((c['cuotas'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final color = estado == 'Pagado'
        ? const Color(0xFF34D399)
        : estado == 'Atrasado'
            ? const Color(0xFFF87171)
            : portalCyan;
    final pctPago =
        totalPagar > 0 ? (totalPagado / totalPagar).clamp(0.0, 1.0) : 0.0;
    final asesor = (c['asesor'] ?? '').toString();

    return Container(
      decoration: portalGlass(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              PortalRing(
                progress: numCuotas > 0 ? pagadas / numCuotas : 0.0,
                color: color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$pagadas',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1)),
                  Text('de $numCuotas',
                      style:
                          const TextStyle(color: portalTextSoft, fontSize: 10)),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Crédito #${c['codigo']}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: color.withValues(alpha: 0.45)),
                          ),
                          child: Text(estado.toUpperCase(),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9.5,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('SALDO PENDIENTE',
                        style: TextStyle(
                            color: portalTextSoft,
                            fontSize: 9.5,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: PortalCountUp(
                        value: _n(c['saldo_pendiente']),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Text('Pagado ${portalCop(totalPagado)}',
                  style: const TextStyle(color: portalTextSoft, fontSize: 11)),
              const Spacer(),
              Text('Total ${portalCop(totalPagar)}',
                  style: const TextStyle(color: portalTextSoft, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 9,
                color: Colors.white.withValues(alpha: 0.07),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pctPago),
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [color, const Color(0xFF6366F1)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: [
                _Dato(Icons.account_balance_rounded, 'Prestado',
                    portalCop(_n(c['valor_prestamo']))),
                _Dato(Icons.repeat_rounded, 'Frecuencia',
                    (c['frecuencia'] ?? '').toString()),
                _Dato(Icons.pending_actions_rounded, 'Cuotas pendientes',
                    '${_i(c['cuotas_pendientes'])}'),
                _Dato(Icons.person_outline_rounded, 'Asesor',
                    asesor.isEmpty ? '—' : asesor),
              ],
            ),
            if (vencidas > 0 && estado != 'Pagado') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFCA5A5), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Tienes $vencidas cuota${vencidas == 1 ? '' : 's'} vencida${vencidas == 1 ? '' : 's'}. Comunícate con tu asesor para ponerte al día.',
                        style: const TextStyle(
                            color: Color(0xFFFECACA), fontSize: 12)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _abierto = !_abierto);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(children: [
              Text(
                  _abierto ? 'Ocultar cuotas' : 'Ver las ${cuotas.length} cuotas',
                  style: const TextStyle(
                      color: Color(0xFFB8CBFF),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
              const Spacer(),
              AnimatedRotation(
                turns: _abierto ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFB8CBFF)),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_abierto
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: Column(children: [
                    for (var i = 0; i < cuotas.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: PortalEntrance(
                          delayMs: (i < 14 ? i : 14) * 35,
                          offsetY: 8,
                          child: _CuotaFila(cuota: cuotas[i]),
                        ),
                      ),
                  ]),
                ),
        ),
      ]),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, color: portalTextSoft, size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: portalTextSoft,
                      fontSize: 8.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CuotaFila extends StatelessWidget {
  const _CuotaFila({required this.cuota});
  final Map<String, dynamic> cuota;

  @override
  Widget build(BuildContext context) {
    final pagada = cuota['pagada'] == true;
    final vencida = cuota['vencida'] == true;
    final abonado = _n(cuota['valor_pagado']);
    final fechaPago = (cuota['fecha_pago'] ?? '').toString();
    final parcial = !pagada && abonado > 0;

    final Color c;
    final IconData icon;
    final String txt;
    if (pagada) {
      c = const Color(0xFF6EE7B7);
      icon = Icons.check_circle_rounded;
      txt = fechaPago.isNotEmpty
          ? 'Pagada el ${portalFechaCorta(fechaPago)}'
          : 'Pagada';
    } else if (vencida) {
      c = const Color(0xFFFCA5A5);
      icon = Icons.warning_amber_rounded;
      txt = parcial ? 'Vencida · abonó ${portalCop(abonado)}' : 'Vencida';
    } else if (parcial) {
      c = const Color(0xFFA5B4FC);
      icon = Icons.timelapse_rounded;
      txt =
          'Abono de ${portalCop(abonado)}${fechaPago.isNotEmpty ? ' · ${portalFechaCorta(fechaPago)}' : ''}';
    } else {
      c = portalTextSoft;
      icon = Icons.schedule_rounded;
      txt = 'Pendiente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: pagada || vencida || parcial ? 0.11 : 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          child: Text('${cuota['numero']}',
              style: const TextStyle(
                  color: Color(0xFF0B1023),
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(portalFechaCorta((cuota['fecha_limite'] ?? '').toString()),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(icon, color: c, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(txt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c, fontSize: 11.5)),
                ),
              ]),
            ],
          ),
        ),
        Text(portalCop(_n(cuota['valor'])),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
