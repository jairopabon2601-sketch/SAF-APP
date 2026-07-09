// ignore_for_file: use_build_context_synchronously

import '../../controllers/home_actions.dart';
import '../../controllers/home_data_controller.dart';
import 'credits_screen.dart';
import 'dashboard_screen.dart';
import 'home_dependencies.dart';
import 'savings_screen.dart';

/// Fecha/hora actual en Colombia (UTC-5 fijo, sin horario de verano),
/// independiente de la zona horaria configurada en el dispositivo.
DateTime nowBogota() =>
    DateTime.now().toUtc().subtract(const Duration(hours: 5));

/// Hora exacta de digitación de un movimiento (campo `fecha_registro`,
/// 'yyyy-MM-dd HH:mm:ss'), formateada como "1:51 a. m.". Los movimientos
/// anteriores a este cambio no tienen ese dato (llega null/vacío desde el
/// backend) — en ese caso no se muestra nada en vez de un "00:00" falso.
String formatHoraRegistro(dynamic fechaRegistro) {
  final raw = (fechaRegistro ?? '').toString().trim();
  if (raw.isEmpty || raw == 'null') return '';
  final match = RegExp(r'(\d{2}):(\d{2})').firstMatch(raw);
  if (match == null) return '';
  final h = int.tryParse(match.group(1)!);
  final m = int.tryParse(match.group(2)!);
  if (h == null || m == null) return '';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final periodo = h < 12 ? 'a. m.' : 'p. m.';
  return '$h12:${m.toString().padLeft(2, '0')} $periodo';
}

/// Convierte una fecha 'yyyy-MM-dd' en una etiqueta legible: "Hoy", "Ayer"
/// o "d Mes" (con año si no es el actual). Compartido entre Movimientos
/// (encabezados de grupo por día) e Inicio (actividad reciente).
String formatDayLabel(String fecha) {
  final parts = fecha.split('-');
  if (parts.length != 3) return fecha;
  final y = int.tryParse(parts[0]);
  final mo = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || mo == null || d == null) return fecha;
  final date = DateTime(y, mo, d);
  final today = nowBogota();
  final todayD = DateTime(today.year, today.month, today.day);
  final diff = todayD.difference(date).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  const meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic'
  ];
  final mesLabel = (mo >= 1 && mo <= 12) ? meses[mo - 1] : '';
  return '$d $mesLabel${y != today.year ? ' $y' : ''}';
}

class _MovementDayGroup {
  final String fecha; // yyyy-MM-dd
  final List<Map<String, dynamic>> items;
  _MovementDayGroup(this.fecha, this.items);
}

extension HomeMovementsScreen<T extends StatefulWidget> on HomeController<T> {
  Widget buildMovementsScreen() {
    // Esta pestaña solo necesita cuentas + movimientos. Antes esperaba a
    // que loadData() completara cada sección (ahorradores, créditos, etc.)
    // antes de pintar algo; ahora, en cuanto cuentas/movimientos llegan (de
    // caché o de red) se muestran, sin esperar al resto de datos no relacionados.
    if (loadingData && accounts.isEmpty && movements.isEmpty) {
      return _movementsSkeleton();
    }

    final filtrados = filteredMovements;
    final activeAccounts =
        accounts.where((c) => (c['estado'] ?? '').toString() == '1').toList();

    // Sin filtros → totales históricos (como la web); con filtros → filtrados
    final hasUserFilter = accountFilter.isNotEmpty ||
        movementTypeFilter.isNotEmpty ||
        filterFrom != null ||
        filterTo != null;

    // Server totals: default range → serverExpenses/serverIncome; filtered → filteredExpenses/filteredIncome
    final gastos = hasUserFilter
        ? (filteredTotalsLoaded
            ? filteredExpenses
            : filtrados
                .where((m) => !movementIsIncome(m))
                .fold(0.0, (s, m) => s + numberValue(m['valor'] ?? 0)))
        : (serverTotalsLoaded ? serverExpenses : 0.0);
    final ingresos = hasUserFilter
        ? (filteredTotalsLoaded
            ? filteredIncome
            : filtrados
                .where(movementIsIncome)
                .fold(0.0, (s, m) => s + numberValue(m['valor'] ?? 0)))
        : (serverTotalsLoaded ? serverIncome : 0.0);
    final balance = ingresos - gastos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sub-tab switcher ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: homeNavy.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(children: [
              _subTab(0, 'Cuentas'),
              _subTab(1, 'Movimientos'),
            ]),
          ),
        ),

        if (movementSubTab == 0) ...[
          // ── CUENTAS: tarjeta de acciones ─────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: lineCol),
                boxShadow: [
                  BoxShadow(
                    color: homeNavy.withValues(alpha: 0.09),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── CTA principal ──────────────────────────
                  _ActionTile(
                    onTap: () => _showNuevaCuentaDialog(),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF37AB87), // lerp(#059669, white, 0.20)
                        Color(0xFF059669), // base
                        Color(0xFF047552), // lerp(#059669, black, 0.22)
                        Color(0xFF024832), // lerp(#059669, black, 0.52)
                      ],
                      stops: [0.0, 0.30, 0.65, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    iconColor: const Color(0xFF059669),
                    icon: Icons.add_card_rounded,
                    title: 'Nueva Cuenta / Fuente',
                    subtitle: 'Agregar fuente de dinero',
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    trailing: true,
                    entranceDelay: 0,
                  ),
                  // ── Fila secundaria ────────────────────────
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            onTap: () => _showRegistrarMovimientoDialog(),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4D6DB5), // lerp(#1E3A8A, white, 0.20)
                                Color(0xFF1E3A8A), // base
                                Color(0xFF17296C), // lerp(#1E3A8A, black, 0.22)
                                Color(0xFF0C1542), // lerp(#1E3A8A, black, 0.52)
                              ],
                              stops: [0.0, 0.30, 0.65, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            iconColor: const Color(0xFF1E3A8A),
                            icon: Icons.swap_vert_rounded,
                            title: 'Movimiento',
                            subtitle: 'Ingreso / Gasto',
                            borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(22)),
                            entranceDelay: 120,
                          ),
                        ),
                        Container(width: 1, color: lineCol),
                        Expanded(
                          child: _ActionTile(
                            onTap: () => _showTransferirDialog(),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF8C04C), // lerp(#F59E0B, white, 0.20)
                                Color(0xFFF59E0B), // base
                                Color(0xFFC07C09), // lerp(#F59E0B, black, 0.22)
                                Color(0xFF745C05), // lerp(#F59E0B, black, 0.52)
                              ],
                              stops: [0.0, 0.30, 0.65, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            iconColor: const Color(0xFFF59E0B),
                            icon: Icons.compare_arrows_rounded,
                            title: 'Transferir',
                            subtitle: 'Entre cuentas',
                            borderRadius: const BorderRadius.only(
                                bottomRight: Radius.circular(22)),
                            entranceDelay: 220,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Total saldo card
          AnimatedBuilder(
            animation: shimmer,
            builder: (_, __) {
              final glow = shimmer.value;
              final total = activeAccounts.fold(
                  0.0, (s, c) => s + numberValue(c['saldo_actual'] ?? 0));
              return Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F0A3C),
                      Color(0xFF1E1265),
                      Color(0xFF3730A3),
                      Color(0xFF4F46E5),
                    ],
                    stops: [0.0, 0.3, 0.65, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3730A3)
                          .withValues(alpha: 0.45 + glow * 0.18),
                      blurRadius: 20 + glow * 8,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      blurRadius: 32,
                      spreadRadius: -4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(children: [
                  Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              const Color(0xFF818CF8).withValues(alpha: 0.25),
                              Colors.transparent,
                            ]),
                          ))),
                  Positioned(
                      left: -20,
                      bottom: -20,
                      child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          ))),
                  Positioned.fill(
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      child: Transform.translate(
                        offset: Offset((glow * 2 - 1) * 180, 0),
                        child: Transform.rotate(
                          angle: 0.4,
                          child: Container(
                            width: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.09),
                                Colors.white.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.20),
                                Colors.white.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total de Saldos',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.65),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3)),
                              const SizedBox(height: 4),
                              Text(
                                  balanceVisible
                                      ? formatCop(total)
                                      : '• • • • • •',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.8)),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Text('${activeAccounts.length} cuentas',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ]),
              );
            },
          ),
          // Lista de cuentas
          if (activeAccounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildEmptyActivity(
                title: 'Sin cuentas',
                subtitle: 'Tus cuentas y fuentes apareceran aqui',
                icon: Icons.account_balance_wallet_outlined,
                accent: const Color(0xFF059669),
                badge: 'Crea una nueva cuenta',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: activeAccounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _cuentaRowReal(activeAccounts[i], i),
            ),
        ] else ...[
          // ── HERO BANNER ────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (_, t, child) => Transform.translate(
              offset: Offset(0, 28 * (1 - t)),
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (_, heroChild) => Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF060D26),
                      Color(0xFF0D1B4B),
                      Color(0xFF163B8C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF6366F1)
                          .withValues(alpha: 0.30 + 0.16 * shimmer.value)),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF1E40AF)
                            .withValues(alpha: 0.45 + 0.16 * shimmer.value),
                        blurRadius: 28 + 10 * shimmer.value,
                        spreadRadius: -4,
                        offset: const Offset(0, 14)),
                    BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                        blurRadius: 48,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: heroChild,
              ),
              child: Stack(children: [
                // Orb top-right
                Positioned(
                  right: -70,
                  top: -70,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.22),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Orb bottom-left
                Positioned(
                  left: -40,
                  bottom: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Marca de agua SAF — branding sutil, no compite con la info.
                Positioned(
                  right: -18,
                  bottom: -14,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.07,
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child:
                            CustomPaint(painter: SafLogoPainter(Colors.white)),
                      ),
                    ),
                  ),
                ),
                // Horizontal shimmer line
                Positioned(
                  left: 0,
                  right: 0,
                  top: 72,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Barrido de luz diagonal animado
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: shimmer,
                      builder: (_, __) => Transform.translate(
                        offset: Offset((shimmer.value * 2 - 1) * 340, 0),
                        child: Transform.rotate(
                          angle: 0.45,
                          child: Container(
                            width: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.07),
                                Colors.white.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ──
                      Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: balance >= 0
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF87171),
                            boxShadow: [
                              BoxShadow(
                                  color: (balance >= 0
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFFF87171))
                                      .withValues(alpha: 0.85),
                                  blurRadius: 8,
                                  spreadRadius: 2)
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                            hasUserFilter
                                ? 'Balance del período'
                                : 'Balance total',
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                        const Spacer(),
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CustomPaint(
                              painter: SafLogoPainter(
                                  Colors.white.withValues(alpha: 0.55))),
                        ),
                        const SizedBox(width: 6),
                        Text('SAF',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: Text('${filtrados.length} mov.',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // ── Balance amount ──
                      (hasUserFilter && !filteredTotalsLoaded)
                          ? Container(
                              width: 170,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8)))
                          : TweenAnimationBuilder<double>(
                              key: ValueKey(balance),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeOutExpo,
                              builder: (_, t, __) => Text(
                                formatCop(balance * t),
                                style: TextStyle(
                                    color: balance >= 0
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFF87171),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                    shadows: [
                                      Shadow(
                                        color: (balance >= 0
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFDC2626))
                                            .withValues(alpha: 0.55),
                                        blurRadius: 16,
                                      )
                                    ]),
                              ),
                            ),
                      const SizedBox(height: 16),
                      // ── GASTOS / INGRESOS cards ──
                      Row(children: [
                        // GASTOS
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7F1D1D),
                                  Color(0xFFB91C1C),
                                  Color(0xFFEF4444),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.55),
                                    blurRadius: 18,
                                    spreadRadius: -2,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Colors.white,
                                        size: 10),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('GASTOS',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8)),
                                ]),
                                const SizedBox(height: 7),
                                (hasUserFilter && !filteredTotalsLoaded)
                                    ? Container(
                                        width: 80,
                                        height: 14,
                                        decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(4)))
                                    : TweenAnimationBuilder<double>(
                                        key: ValueKey(gastos),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration:
                                            const Duration(milliseconds: 900),
                                        curve: Curves.easeOutExpo,
                                        builder: (_, t, __) => Text(
                                          formatCop(gastos * t),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // INGRESOS
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF064E3B),
                                  Color(0xFF065F46),
                                  Color(0xFF10B981),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF059669)
                                        .withValues(alpha: 0.55),
                                    blurRadius: 18,
                                    spreadRadius: -2,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('INGRESOS',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.arrow_downward_rounded,
                                          color: Colors.white,
                                          size: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                (hasUserFilter && !filteredTotalsLoaded)
                                    ? Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                            width: 80,
                                            height: 14,
                                            decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.25),
                                                borderRadius:
                                                    BorderRadius.circular(4))))
                                    : TweenAnimationBuilder<double>(
                                        key: ValueKey(ingresos),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration:
                                            const Duration(milliseconds: 900),
                                        curve: Curves.easeOutExpo,
                                        builder: (_, t, __) => Text(
                                          formatCop(ingresos * t),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                      // ── Barra proporción ingresos/gastos ──
                      if (ingresos + gastos > 0) ...[
                        const SizedBox(height: 14),
                        Builder(builder: (_) {
                          final ratio =
                              (ingresos / (ingresos + gastos)).clamp(0.0, 1.0);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Stack(children: [
                                  Container(
                                    height: 7,
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.45),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: ratio),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, animRatio, __) =>
                                        FractionallySizedBox(
                                      widthFactor: animRatio,
                                      child: Container(
                                        height: 7,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF059669),
                                              Color(0xFF34D399)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF34D399)
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '${(ratio * 100).toStringAsFixed(0)}% ingresos',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.60),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      '${((1 - ratio) * 100).toStringAsFixed(0)}% gastos',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.60),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
          // ── Botones de acción (Movimientos tab) ──────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: lineCol),
                boxShadow: [
                  BoxShadow(
                    color: homeNavy.withValues(alpha: 0.09),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(children: [
                _ActionTile(
                  onTap: () => _showRegistrarMovimientoDialog(),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF37AB87),
                      Color(0xFF059669),
                      Color(0xFF047552),
                      Color(0xFF024832),
                    ],
                    stops: [0.0, 0.30, 0.65, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: const Color(0xFF059669),
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Nuevo Movimiento',
                  subtitle: 'Registrar ingreso o gasto',
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  trailing: true,
                  entranceDelay: 0,
                ),
                _ActionTile(
                  onTap: () => _showTransferirDialog(),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF8C04C),
                      Color(0xFFF59E0B),
                      Color(0xFFC07C09),
                      Color(0xFF745C05),
                    ],
                    stops: [0.0, 0.30, 0.65, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: const Color(0xFFF59E0B),
                  icon: Icons.compare_arrows_rounded,
                  title: 'Transferir',
                  subtitle: 'Mover entre cuentas',
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(22)),
                  entranceDelay: 100,
                ),
              ]),
            ),
          ),
          // ── Filtros ──────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - t)),
                child: RepaintBoundary(child: child),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: lineCol),
                boxShadow: [
                  BoxShadow(
                      color: homeNavy.withValues(alpha: 0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0B0F2E),
                        Color(0xFF1E3A8A),
                        Color(0xFF3B82F6),
                      ],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(19)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.tune_rounded,
                          size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text('Filtros',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2)),
                    if (hasUserFilter) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF34D399).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.4))),
                        child: const Text('activo',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF6EE7B7),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                    ],
                    const Spacer(),
                    if (hasUserFilter)
                      GestureDetector(
                        onTap: () {
                          refresh(() {
                            accountFilter = '';
                            movementTypeFilter = '';
                            filterFrom = null;
                            filterTo = null;
                            filteredTotalsLoaded = false;
                            movementsPage = 1;
                          });
                          unawaited(onDateFilterChanged());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22))),
                          child: const Row(children: [
                            Icon(Icons.close_rounded,
                                size: 11, color: Colors.white70),
                            SizedBox(width: 4),
                            Text('Limpiar',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                  ]),
                ),
                // Campos de filtro
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: _filterDropdown<String>(
                        label: 'Cuenta',
                        icon: Icons.account_balance_wallet_rounded,
                        accent: const Color(0xFF8B5CF6),
                        value: accountFilter.isEmpty ? null : accountFilter,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Todas')),
                          ...accounts.map((c) {
                            final color = parseHexColor(
                                (c['color'] ?? '#4361EE').toString());
                            return DropdownMenuItem(
                              value: (c['nombre'] ?? '').toString(),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                          (c['nombre'] ?? '').toString(),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                            );
                          }),
                        ],
                        onChanged: (v) async {
                          refresh(() {
                            accountFilter = v ?? '';
                            filteredTotalsLoaded = false;
                            movementsPage = 1;
                          });
                          await loadSelectedAccountMovements();
                          unawaited(fetchFilteredTotals());
                        },
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _filterDropdown<String>(
                        label: 'Tipo',
                        icon: Icons.swap_vert_rounded,
                        accent: const Color(0xFFF59E0B),
                        value: movementTypeFilter.isEmpty
                            ? null
                            : movementTypeFilter,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Todos')),
                          DropdownMenuItem(
                            value: '2',
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 7),
                              const Text('Gasto',
                                  style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          DropdownMenuItem(
                            value: '3',
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 7),
                              const Text('Ingreso',
                                  style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                        onChanged: (v) {
                          refresh(() {
                            movementTypeFilter = v ?? '';
                            filteredTotalsLoaded = false;
                            movementsPage = 1;
                          });
                          unawaited(fetchFilteredTotals());
                        },
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _filterDate(
                        label: 'Desde',
                        value: filterFrom,
                        onPick: (d) {
                          if (d == null) return;
                          refresh(() {
                            filterFrom = d;
                            filteredTotalsLoaded = false;
                            movementsPage = 1;
                          });
                          unawaited(onDateFilterChanged());
                        },
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _filterDate(
                        label: 'Hasta',
                        value: filterTo,
                        onPick: (d) {
                          if (d == null) return;
                          refresh(() {
                            filterTo = d;
                            filteredTotalsLoaded = false;
                            movementsPage = 1;
                          });
                          unawaited(onDateFilterChanged());
                        },
                      )),
                    ]),
                  ]),
                ),
              ]),
            ),
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
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Movimientos',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                          letterSpacing: -0.3)),
                ]),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text('${filtrados.length} registros',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          if (filtrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildEmptyActivity(
                badge: hasUserFilter
                    ? 'Ajusta los filtros'
                    : 'Registra tu primer movimiento',
              ),
            )
          else ...[
            Builder(builder: (_) {
              final totalPags =
                  ((filtrados.length - 1) ~/ movementsPageSize) + 1;
              final pag = movementsPage.clamp(1, totalPags);
              final desde = (pag - 1) * movementsPageSize;
              final hasta =
                  (desde + movementsPageSize).clamp(0, filtrados.length);
              final pagina = filtrados.sublist(desde, hasta);
              final groups = _groupMovementsByDay(pagina);
              final rows = <Widget>[];
              var localIndex = 0;
              for (final group in groups) {
                rows.add(_dayGroupHeader(group, localIndex));
                for (final m in group.items) {
                  final i = localIndex++;
                  // Clave por identidad del movimiento (no por posición): al
                  // eliminar uno, todo lo que venía después recorría su
                  // índice y Flutter podía reconciliar mal qué widget
                  // corresponde a cuál dato, dejando una fila fantasma hasta
                  // que un refresh completo reconstruía el árbol desde cero.
                  final movKey = (m['codigo'] ??
                          m['codigo_movimiento'] ??
                          m['id'] ??
                          (desde + i))
                      .toString();
                  rows.add(Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AnimatedMovementCard(
                      key: ValueKey('mov_$movKey'),
                      data: m,
                      index: i,
                      onDelete: () => _confirmEliminarMovimiento(m),
                    ),
                  ));
                }
                rows.add(const SizedBox(height: 6));
              }
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(children: rows),
                ),
                if (totalPags > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: buildPaginationBar([
                      buildPaginationButton(Icons.chevron_left_rounded, pag > 1,
                          () {
                        refresh(() => movementsPage = pag - 1);
                      }),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: buildPaginationLabel(
                            'Pág $pag de $totalPags  ·  ${filtrados.length} registros',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      buildPaginationButton(
                          Icons.chevron_right_rounded, pag < totalPags, () {
                        refresh(() => movementsPage = pag + 1);
                      }),
                    ]),
                  ),
              ]);
            }),
          ],
        ],
      ],
    );
  }

  Widget buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) =>
      _AnimatedActionButton(
          label: label, color: color, onTap: onTap, icon: icon);

  Widget buildAnimatedMovementCard(
    Map<String, dynamic> data,
    int index, {
    VoidCallback? onDelete,
  }) =>
      _AnimatedMovementCard(
        key: ValueKey('amc_$index'),
        data: data,
        index: index,
        onDelete: onDelete,
      );

  // Agrupa movimientos consecutivos del mismo día (la lista ya viene
  // ordenada por fecha desc) para mostrar subtotales tipo "estado de cuenta".
  List<_MovementDayGroup> _groupMovementsByDay(
      List<Map<String, dynamic>> list) {
    final groups = <_MovementDayGroup>[];
    for (final m in list) {
      final raw = (m['fecha'] ?? '').toString();
      final fecha = raw.length >= 10 ? raw.substring(0, 10) : raw;
      if (groups.isNotEmpty && groups.last.fecha == fecha) {
        groups.last.items.add(m);
      } else {
        groups.add(_MovementDayGroup(fecha, [m]));
      }
    }
    return groups;
  }

  Widget _dayGroupHeader(_MovementDayGroup group, int index) =>
      buildDayGroupHeader(group.fecha, group.items, index: index);

  /// Banner de grupo por día: gradiente navy→azul con shimmer, badge de
  /// calendario y chip sólido verde/rojo con el neto del día. Compartido
  /// con "Actividad reciente" en Inicio.
  ///
  /// [index] debe ser el índice de la primera card de ese grupo (misma base
  /// que usan las `_AnimatedMovementCard`) — así el banner entra al mismo
  /// tiempo que sus movimientos en vez de aparecer instantáneo mientras las
  /// cards (que sí tienen demora escalonada) todavía no se ven.
  Widget buildDayGroupHeader(String fecha, List<Map<String, dynamic>> items,
      {int index = 0}) {
    final ingresos = items
        .where(movementIsIncome)
        .fold(0.0, (s, m) => s + numberValue(m['valor'] ?? 0));
    final gastos = items
        .where((m) => !movementIsIncome(m))
        .fold(0.0, (s, m) => s + numberValue(m['valor'] ?? 0));
    final neto = ingresos - gastos;
    final netoGrad = neto >= 0
        ? const [Color(0xFF059669), Color(0xFF34D399)]
        : const [Color(0xFFB91C1C), Color(0xFFEF4444)];
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0B0F2E),
                Color(0xFF1E3A8A),
                Color(0xFF3B82F6),
              ],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A)
                    .withValues(alpha: 0.30 + 0.12 * shimmer.value),
                blurRadius: 14 + 5 * shimmer.value,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset((shimmer.value * 2 - 1) * 260, 0),
                  child: Transform.rotate(
                    angle: 0.42,
                    child: Container(
                      width: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: const Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 9),
                  Text(formatDayLabel(fecha),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22))),
                    child: Text(
                        '${items.length} ${items.length == 1 ? 'mov.' : 'movs.'}',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: netoGrad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: netoGrad.last.withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Neto ',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85))),
                      Text('${neto >= 0 ? '+' : '−'}${formatCop(neto.abs())}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );

    // Misma base de demora que _AnimatedMovementCard ((index*65).clamp(0,380)
    // + 520ms de entrada) para que el banner del día aparezca junto con su
    // primera card, no antes. _AnimatedMovementCard usa DOS curvas distintas
    // (easeOut para el fade, easeOutCubic para el slide) sobre el mismo
    // progreso — usar una sola curva (easeOutCubic) para ambos hacía que la
    // opacidad del banner subiera más rápido que la de la card (easeOut es
    // menos "adelantada"), por eso se veía el banner listo primero aunque
    // la duración total ya coincidiera. Progreso lineal aquí + cada curva
    // aplicada por separado, igual que hace la card internamente.
    final delayMs = (index * 65).clamp(0, 380);
    final totalMs = delayMs + 520;
    return TweenAnimationBuilder<double>(
      key: ValueKey('daygroup_${fecha}_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1.0),
      builder: (_, t, child) {
        final progress = t.clamp(0.0, 1.0);
        final fadeT = Curves.easeOut.transform(progress);
        final slideT = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: fadeT,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - slideT)),
            child: RepaintBoundary(child: child),
          ),
        );
      },
      child: content,
    );
  }

  Widget _filterDropdown<ValueType>({
    required String label,
    required ValueType? value,
    required List<DropdownMenuItem<ValueType>> items,
    required ValueChanged<ValueType?> onChanged,
    IconData icon = Icons.filter_list_rounded,
    Color accent = const Color(0xFF3B82F6),
  }) {
    final active = value != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textSoft,
              letterSpacing: 0.6)),
      const SizedBox(height: 5),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.14),
                    accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? accent.withValues(alpha: 0.45) : lineCol),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(accent, Colors.white, 0.18) ?? accent,
                  accent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: accent.withValues(alpha: 0.40),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ]
                  : null,
            ),
            child: Icon(icon, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ValueType>(
                value: value,
                isExpanded: true,
                items: items,
                onChanged: onChanged,
                dropdownColor: dialogBg,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: textMain,
                    fontFamily: 'sans-serif'),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: active ? accent : textSoft),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _filterDate({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
    Color accent = const Color(0xFF3B82F6),
  }) {
    final active = value != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textSoft,
              letterSpacing: 0.6)),
      const SizedBox(height: 5),
      GestureDetector(
        onTap: () async {
          final picked = await showLightDatePicker(
            screenContext,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          onPick(picked);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.14),
                      accent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active ? accent.withValues(alpha: 0.45) : lineCol),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(accent, Colors.white, 0.18) ?? accent,
                    accent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: accent.withValues(alpha: 0.40),
                            blurRadius: 6,
                            offset: const Offset(0, 2)),
                      ]
                    : null,
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null
                    ? '${value.day.toString().padLeft(2, '0')}/'
                        '${value.month.toString().padLeft(2, '0')}/'
                        '${value.year}'
                    : 'Seleccione',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? textMain : textSoft),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── Diálogo Crear Deudor ─────────────────────────────────────────
  Widget buildDialogRow(String label, Widget input) => LayoutBuilder(
        builder: (_, constraints) {
          final labelW = (constraints.maxWidth * 0.37).clamp(90.0, 130.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: labelW,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDarkTheme
                          ? [
                              homeAccent.withValues(alpha: 0.24),
                              homeAccent.withValues(alpha: 0.10),
                            ]
                          : [
                              const Color(0xFFE0E7FF),
                              const Color(0xFFEEF2FF),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: homeAccent.withValues(
                            alpha: isDarkTheme ? 0.30 : 0.18)),
                  ),
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDarkTheme
                              ? const Color(0xFFB6C2FF)
                              : const Color(0xFF3730A3))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: input),
            ],
          );
        },
      );

  // Dropdown estilizado para los diálogos
  Widget buildDialogDropdown<ValueType>({
    required ValueType? value,
    required List<DropdownMenuItem<ValueType>> items,
    required ValueChanged<ValueType?> onChanged,
    String? hint,
    String? Function(ValueType?)? validator,
    bool isExpanded = true,
  }) =>
      DropdownButtonFormField<ValueType>(
        // ignore: deprecated_member_use
        value: value,
        isExpanded: isExpanded,
        decoration: dialogInputDecoration(),
        dropdownColor: dialogBg,
        style: dialogTextStyle,
        hint: Text(hint ?? '[Seleccione]', style: dialogHintStyle),
        icon:
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textSoft),
        items: items,
        onChanged: onChanged,
        validator: validator,
      );

  InputDecoration dialogInputDecoration() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _dialogFieldBorderColor())),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _dialogFieldBorderColor())),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4361EE), width: 1.6)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6)),
      );

  Color _dialogFieldBorderColor([Color accent = homeAccent]) => isDarkTheme
      ? Color.lerp(lineCol, accent, 0.18)!.withValues(alpha: 0.72)
      : const Color(0xFFE0E7FF);

  Widget buildDialogField(
    TextEditingController ctrl, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) =>
      TextFormField(
        controller: ctrl,
        decoration: dialogInputDecoration(),
        keyboardType: keyboard,
        obscureText: obscure,
        style: dialogTextStyle,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
            : null,
      );

  Widget _subTab(int index, String label) {
    const icons = [
      Icons.account_balance_wallet_rounded,
      Icons.receipt_long_rounded
    ];
    // Colores por pestaña, visibles en claro y oscuro: Cuentas = mismo
    // degradado índigo/violeta del panel "Total de Saldos" justo debajo,
    // para que combinen. Movimientos = ámbar/naranja.
    const gradients = [
      [
        Color(0xFF0F0A3C),
        Color(0xFF1E1265),
        Color(0xFF3730A3),
        Color(0xFF4F46E5),
      ],
      [Color(0xFF7C2D12), Color(0xFFD97706), Color(0xFFFBBF24)],
    ];
    const accents = [Color(0xFF4F46E5), Color(0xFFF59E0B)];
    final active = movementSubTab == index;
    return Expanded(
      child: _SubTabButton(
        active: active,
        icon: icons[index],
        label: label,
        gradient: gradients[index],
        accent: accents[index],
        onTap: () => refresh(() => movementSubTab = index),
      ),
    );
  }

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
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
    final formKey = GlobalKey<FormState>();
    final nuevoSaldoCtrl = TextEditingController();
    final nombreCuenta = (cuenta['nombre'] ?? '').toString();
    final codigoCuenta = (cuenta['codigo'] ?? '').toString();

    // Debe ser exactamente el mismo saldo mostrado en la tarjeta. Calcularlo
    // desde los movimientos cargados puede dar 0 si el listado está paginado.
    final saldoActual = accountBalance(cuenta);

    bool saving = false;
    if (!isMounted) return;

    final hexColor = (cuenta['color'] ?? '#4361EE').toString();
    final accentColor = parseHexColor(hexColor);
    final cLight = Color.lerp(accentColor, Colors.white, 0.40)!;
    final cDark = Color.lerp(accentColor, Colors.black, 0.20)!;
    final initials = nombreCuenta.trim().isNotEmpty
        ? nombreCuenta
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase()
        : 'C';

    await showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget premBtn({
          required List<Color> colors,
          required VoidCallback? onPressed,
          required Widget child,
        }) =>
            GestureDetector(
              onTap: onPressed,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: onPressed != null
                      ? [
                          BoxShadow(
                            color: colors.first.withValues(alpha: 0.42),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: colors.first.withValues(alpha: 0.18),
                            blurRadius: 24,
                            spreadRadius: -4,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: child,
              ),
            );

        Widget infoRow(IconData icon, String label, String value) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dialogFieldBorderColor(accentColor)),
              ),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cLight, accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 10,
                              color: textSoft,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(value,
                          style: TextStyle(
                              fontSize: 14,
                              color: textMain,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ]),
            );

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.20),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ─────────────────────────────────────
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(26)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0F0A3C),
                              const Color(0xFF1E1265),
                              accentColor.withValues(alpha: 0.85),
                              accentColor,
                            ],
                            stops: const [0.0, 0.3, 0.7, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(children: [
                          Positioned(
                              right: -20,
                              top: -20,
                              child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      cLight.withValues(alpha: 0.28),
                                      Colors.transparent,
                                    ]),
                                  ))),
                          Positioned(
                              left: -15,
                              bottom: -15,
                              child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ))),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [cLight, accentColor, cDark],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          accentColor.withValues(alpha: 0.50),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ajustar Saldo',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.3)),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.account_balance_rounded,
                                                size: 10,
                                                color: Colors.white70),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(nombreCuenta,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.90),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF991B1B),
                                        Color(0xFFDC2626),
                                        Color(0xFFF43F5E)
                                      ],
                                      stops: [0.0, 0.5, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFDC2626)
                                            .withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ),
                    // ── Form ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoRow(Icons.account_balance_rounded, 'Cuenta',
                              nombreCuenta),
                          infoRow(Icons.savings_rounded, 'Saldo Actual',
                              formatCop(saldoActual)),
                          // Nuevo saldo input
                          Text('Nuevo Saldo',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textMid)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nuevoSaldoCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textMain),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle:
                                  const TextStyle(color: Color(0xFFB0BCCF)),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF3730A3),
                                      Color(0xFF4F46E5)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.attach_money_rounded,
                                    size: 16, color: Colors.white),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: _dialogFieldBorderColor(
                                          const Color(0xFF4F46E5)))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: _dialogFieldBorderColor(
                                          const Color(0xFF4F46E5)))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF4F46E5), width: 2)),
                              errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFDC2626))),
                              filled: true,
                              fillColor: inputFill,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa el nuevo saldo'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: nuevoSaldoCtrl,
                            builder: (_, val, __) {
                              final text = val.text.trim();
                              if (text.isEmpty) return const SizedBox.shrink();
                              final nuevo = double.tryParse(text
                                      .replaceAll('.', '')
                                      .replaceAll(',', '.')) ??
                                  0.0;
                              final diff = nuevo - saldoActual;
                              final isPos = diff >= 0;
                              final color = isPos
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626);
                              final sign = isPos ? '+' : '';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.30)),
                                ),
                                child: Row(children: [
                                  Icon(
                                    isPos
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 15,
                                    color: color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ajuste: $sign${formatCop(diff)}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: color),
                                  ),
                                ]),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // ── Buttons ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                      child: Row(children: [
                        Expanded(
                          child: premBtn(
                            colors: const [
                              Color(0xFF7F1D1D),
                              Color(0xFFDC2626),
                              Color(0xFFF43F5E)
                            ],
                            onPressed: () => Navigator.pop(ctx),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('Cancelar',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: premBtn(
                            colors: saving
                                ? [
                                    const Color(0xFF9CA3AF),
                                    const Color(0xFF6B7280)
                                  ]
                                : const [
                                    Color(0xFF065F46),
                                    Color(0xFF059669),
                                    Color(0xFF10B981)
                                  ],
                            onPressed: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setS(() => saving = true);
                                    try {
                                      final nuevoSaldo = double.tryParse(
                                              nuevoSaldoCtrl.text
                                                  .trim()
                                                  .replaceAll('.', '')
                                                  .replaceAll(',', '.')) ??
                                          0.0;
                                      final diferencia =
                                          nuevoSaldo - saldoActual;
                                      final now = DateTime.now();
                                      String pad2(int n) =>
                                          n.toString().padLeft(2, '0');
                                      final fecha =
                                          '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
                                      final r = await repository.post(
                                          '/ajax/ajustar_saldo_cuenta.php', {
                                        'codigo_cuenta': codigoCuenta,
                                        'saldo_actual':
                                            saldoActual.toStringAsFixed(2),
                                        'nuevo_saldo':
                                            nuevoSaldo.toStringAsFixed(2),
                                        'diferencia':
                                            diferencia.toStringAsFixed(2),
                                        'fecha': fecha,
                                        'usuario': codigoUsuario,
                                      });
                                      if (r.statusCode == 200) {
                                        final d = decodeJsonMap(r.body);
                                        final ok = d['success'] == true ||
                                            d['resultado'] == 1;
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        final sign = diferencia >= 0 ? '+' : '';
                                        showResult(
                                            ok,
                                            ok
                                                ? 'Ajuste de $sign${formatCop(diferencia)} aplicado correctamente.'
                                                : friendlyError(d['msg'] ??
                                                    d['mensaje'] ??
                                                    'No se pudo ajustar el saldo'));
                                        if (ok &&
                                            diferencia.abs().round() > 0) {
                                          // Pintar de una vez; la recarga de
                                          // red reconcilia después. Mismo
                                          // movimiento que crea el endpoint:
                                          // ingreso si sube, gasto si baja.
                                          applyLocalMovement(
                                            codigoCuenta: codigoCuenta,
                                            tipoMovimiento:
                                                diferencia > 0 ? '3' : '2',
                                            valor: diferencia.abs(),
                                            fecha: fecha,
                                            descripcion: 'Ajuste de cuenta',
                                          );
                                        }
                                        if (ok) {
                                          repository.invalidateCache(
                                              '/ajax/listar_cuentas_gasto.php');
                                          repository.invalidateCache(
                                              '/ajax/listar_movimientos_usuario.php');
                                          unawaited(
                                              refreshAfterMovementChange());
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('[SAF] ajustar saldo: $e');
                                    } finally {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                      }
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text('Guardar Ajuste',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13)),
                                    ],
                                  ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showTransferirDialog() async {
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
    final formKey = GlobalKey<FormState>();
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    String pad2(int n) => n.toString().padLeft(2, '0');
    String selectedFecha = '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
    String? origenCod;
    String? origenNom;
    String? destinoCod;
    String? destinoNom;
    bool saving = false;

    final List<Map<String, dynamic>> cuentasOpts =
        accounts.where((c) => (c['estado'] ?? '').toString() == '1').toList();

    if (!isMounted) return;

    await showDialog(
      context: screenContext,
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

        // ── helpers visuales ────────────────────────────────
        InputDecoration fieldDeco({
          String hint = '',
          IconData? icon,
        }) =>
            InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFFB0BCCF), fontSize: 14),
              prefixIcon: icon != null
                  ? Icon(icon, size: 18, color: const Color(0xFF4361EE))
                  : null,
              filled: true,
              fillColor: inputFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _dialogFieldBorderColor(const Color(0xFFF59E0B)))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _dialogFieldBorderColor(const Color(0xFFF59E0B)))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF4361EE), width: 1.5)),
            );

        Widget fieldLabel(String label) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                        letterSpacing: 0.2)),
              ]),
            );

        Widget pickerField({
          required String? value,
          required String hint,
          required IconData icon,
          required VoidCallback onTap,
        }) =>
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: inputFill,
                  border: Border.all(
                    color: value != null
                        ? const Color(0xFFF59E0B)
                        : _dialogFieldBorderColor(const Color(0xFFF59E0B)),
                    width: value != null ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(icon,
                      size: 18,
                      color:
                          value != null ? const Color(0xFFF59E0B) : textSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(value ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            color: value != null ? textMain : textSoft)),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color:
                          value != null ? const Color(0xFFF59E0B) : textSoft),
                ]),
              ),
            );

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 12)),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF78350F),
                          Color(0xFFB45309),
                          Color(0xFFF59E0B),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.compare_arrows_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transferir entre Cuentas',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Mover saldo de una cuenta a otra',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      appCloseX(() => Navigator.pop(ctx)),
                    ]),
                  ),

                  // ── Form body ────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cuenta Origen
                            fieldLabel('Cuenta Origen'),
                            pickerField(
                              value: origenNom,
                              hint: 'Selecciona cuenta de origen',
                              icon: Icons.logout_rounded,
                              onTap: () async {
                                if (cuentasOpts.isEmpty) return;
                                final picked =
                                    await showDialog<Map<String, dynamic>>(
                                  context: ctx,
                                  builder: (dCtx) =>
                                      AppPickerDialog<Map<String, dynamic>>(
                                    title: 'Cuenta Origen',
                                    titleIcon: Icons.logout_rounded,
                                    items: cuentasOpts,
                                    labelBuilder: (c) =>
                                        (c['nombre'] ?? '').toString(),
                                    colorBuilder: (c) => parseHexColor(
                                        (c['color'] ?? '#4361EE').toString()),
                                  ),
                                );
                                if (picked != null) {
                                  setS(() {
                                    origenCod =
                                        (picked['codigo'] ?? '').toString();
                                    origenNom =
                                        (picked['nombre'] ?? '').toString();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Cuenta Destino
                            fieldLabel('Cuenta Destino'),
                            pickerField(
                              value: destinoNom,
                              hint: 'Selecciona cuenta de destino',
                              icon: Icons.login_rounded,
                              onTap: () async {
                                if (cuentasOpts.isEmpty) return;
                                final picked =
                                    await showDialog<Map<String, dynamic>>(
                                  context: ctx,
                                  builder: (dCtx) =>
                                      AppPickerDialog<Map<String, dynamic>>(
                                    title: 'Cuenta Destino',
                                    titleIcon: Icons.login_rounded,
                                    items: cuentasOpts,
                                    labelBuilder: (c) =>
                                        (c['nombre'] ?? '').toString(),
                                    colorBuilder: (c) => parseHexColor(
                                        (c['color'] ?? '#4361EE').toString()),
                                  ),
                                );
                                if (picked != null) {
                                  setS(() {
                                    destinoCod =
                                        (picked['codigo'] ?? '').toString();
                                    destinoNom =
                                        (picked['nombre'] ?? '').toString();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Valor
                            fieldLabel('Valor a Transferir'),
                            TextFormField(
                              controller: valorCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  color: textMain, fontWeight: FontWeight.w600),
                              decoration: fieldDeco(
                                  hint: '0', icon: Icons.attach_money_rounded),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingresa el valor'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // Fecha
                            fieldLabel('Fecha de Transferencia'),
                            pickerField(
                              value: () {
                                final p = selectedFecha.split('-');
                                return p.length == 3
                                    ? '${p[2]}/${p[1]}/${p[0]}'
                                    : selectedFecha;
                              }(),
                              hint: 'DD/MM/AAAA',
                              icon: Icons.calendar_today_rounded,
                              onTap: () async {
                                final picked = await showLightDatePicker(
                                  ctx,
                                  initialDate:
                                      DateTime.tryParse(selectedFecha) ?? now,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setS(() {
                                    selectedFecha =
                                        '${picked.year}-${pad2(picked.month)}-${pad2(picked.day)}';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Descripción
                            fieldLabel('Descripción (opcional)'),
                            TextFormField(
                              controller: descCtrl,
                              maxLines: 3,
                              style: TextStyle(color: textMain, fontSize: 14),
                              decoration: fieldDeco(
                                hint: 'Ej: Transferencia para gastos...',
                                icon: Icons.notes_rounded,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Botones ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(children: [
                      Expanded(
                        child: gradBtn(
                          colors: const [
                            Color(0xFF991B1B),
                            Color(0xFFDC2626),
                            Color(0xFFEF4444)
                          ],
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
                                    showResult(false,
                                        'Seleccione la cuenta de origen');
                                    return;
                                  }
                                  if (destinoCod == null) {
                                    showResult(false,
                                        'Seleccione la cuenta de destino');
                                    return;
                                  }
                                  if (origenCod == destinoCod) {
                                    showResult(false,
                                        'La cuenta de origen y destino no pueden ser la misma');
                                    return;
                                  }
                                  if (!formKey.currentState!.validate()) return;
                                  final valor = numberValue(valorCtrl.text
                                      .replaceAll(RegExp(r'[^\d]'), ''));
                                  if (valor <= 0) {
                                    showResult(false,
                                        'Ingrese un valor válido para transferir');
                                    return;
                                  }
                                  final cuentaOrigen = cuentasOpts.firstWhere(
                                    (cuenta) =>
                                        (cuenta['codigo'] ?? '').toString() ==
                                        origenCod,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  final saldoOrigen = numberValue(
                                      cuentaOrigen['saldo_actual'] ??
                                          cuentaOrigen['saldo'] ??
                                          cuentaOrigen['balance'] ??
                                          0);
                                  if (saldoOrigen < valor) {
                                    showResult(false,
                                        'La cuenta de origen no tiene saldo suficiente');
                                    return;
                                  }
                                  setS(() => saving = true);
                                  try {
                                    final r = await repository
                                        .post('/ajax/transferir_cuentas.php', {
                                      'cuenta_origen': origenCod!,
                                      'cuenta_destino': destinoCod!,
                                      'valor': valorCtrl.text.trim(),
                                      'fecha': selectedFecha,
                                      'descripcion': descCtrl.text.trim(),
                                      'usuario': codigoUsuario,
                                    });
                                    final raw = r.body.trim();
                                    final lower = raw.toLowerCase();
                                    final isHtml =
                                        lower.contains('<!doctype') ||
                                            lower.contains('<html') ||
                                            lower.contains('fatal error') ||
                                            lower.contains('warning:') ||
                                            lower.contains('require_once');
                                    final d = isHtml
                                        ? <String, dynamic>{}
                                        : decodeJsonMap(raw);
                                    final ok = r.statusCode == 200 &&
                                        !isHtml &&
                                        (d['success'] == true ||
                                            d['resultado'] == 1);
                                    if (!ok) {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                      }
                                      showResult(
                                        false,
                                        isHtml
                                            ? 'El servidor no pudo procesar la transferencia.'
                                            : friendlyError(d['msg'] ??
                                                d['mensaje'] ??
                                                'No se pudo completar la transferencia'),
                                      );
                                      return;
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    // Pintar de una vez las dos patas de la
                                    // transferencia (mismas descripciones que
                                    // arma transferir_cuentas.php); la
                                    // recarga de red reconcilia después.
                                    final descBase = descCtrl.text.trim();
                                    final valorTransfer =
                                        numberValue(valorCtrl.text.trim());
                                    applyLocalMovement(
                                      codigoCuenta: origenCod!,
                                      tipoMovimiento: '2',
                                      valor: valorTransfer,
                                      fecha: selectedFecha,
                                      descripcion: descBase.isNotEmpty
                                          ? descBase
                                          : 'Transferencia a '
                                              '${destinoNom ?? 'cuenta destino'}',
                                    );
                                    applyLocalMovement(
                                      codigoCuenta: destinoCod!,
                                      tipoMovimiento: '3',
                                      valor: valorTransfer,
                                      fecha: selectedFecha,
                                      descripcion: descBase.isNotEmpty
                                          ? descBase
                                          : 'Transferencia desde '
                                              '${origenNom ?? 'cuenta origen'}',
                                    );
                                    repository.invalidateCache(
                                        '/ajax/listar_cuentas_gasto.php');
                                    repository.invalidateCache(
                                        '/ajax/listar_movimientos_usuario.php');
                                    showResult(true,
                                        'Transferencia realizada correctamente.');
                                    unawaited(refreshAfterMovementChange());
                                  } catch (e) {
                                    debugPrint('[SAF] transferir: $e');
                                    if (ctx.mounted) {
                                      setS(() => saving = false);
                                    }
                                    showResult(false,
                                        'No fue posible completar la transferencia: ${friendlyError(e)}');
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
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showRegistrarMovimientoDialog(
      {Map<String, dynamic>? cuentaInicial}) async {
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
    final formKey = GlobalKey<FormState>();
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final now = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    String selectedFecha = '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
    String? selectedCuenta = cuentaInicial?['codigo']?.toString();
    String? selectedCuentaNombre = cuentaInicial?['nombre']?.toString();
    String? selectedCuentaColor = cuentaInicial?['color']?.toString();
    String? selectedTipo;
    bool saving = false;

    // Cuentas activas disponibles desde el estado actual
    final List<Map<String, dynamic>> cuentasOpts =
        accounts.where((c) => (c['estado'] ?? '').toString() == '1').toList();

    if (!isMounted) return;

    await showDialog(
      context: screenContext,
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

        // ── helpers visuales ────────────────────────────────
        InputDecoration fieldDeco({
          String hint = '',
          IconData? icon,
          Widget? suffix,
          double iconSize = 18,
        }) =>
            InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFFB0BCCF), fontSize: 14),
              prefixIcon: icon != null
                  ? Icon(icon, size: iconSize, color: const Color(0xFF4361EE))
                  : null,
              suffixIcon: suffix,
              filled: true,
              fillColor: inputFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _dialogFieldBorderColor(const Color(0xFF4361EE)))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _dialogFieldBorderColor(const Color(0xFF4361EE)))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF4361EE), width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEF4444))),
            );

        Widget fieldLabel(String label) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4361EE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                        letterSpacing: 0.2)),
              ]),
            );

        Widget pickerField({
          required String? value,
          required String hint,
          required IconData icon,
          required VoidCallback onTap,
          Color? valueColor,
        }) =>
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: inputFill,
                  border: Border.all(
                    color: value != null
                        ? const Color(0xFF4361EE)
                        : _dialogFieldBorderColor(const Color(0xFF4361EE)),
                    width: value != null ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(icon,
                      size: 18,
                      color: value != null
                          ? valueColor ?? const Color(0xFF4361EE)
                          : textSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(value ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            color: value != null ? textMain : textSoft)),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color:
                          value != null ? const Color(0xFF4361EE) : textSoft),
                ]),
              ),
            );

        // Campo de cuenta: muestra el color/inicial reales de la cuenta
        // (igual que en la lista de Cuentas) en vez de un icono genérico,
        // para confirmar de un vistazo cuál quedó seleccionada.
        Widget cuentaField() {
          final hasValue =
              selectedCuentaNombre != null && selectedCuentaNombre!.isNotEmpty;
          final color = hasValue && selectedCuentaColor != null
              ? parseHexColor(selectedCuentaColor!)
              : const Color(0xFF4361EE);
          final initials = hasValue
              ? selectedCuentaNombre!
                  .trim()
                  .split(' ')
                  .take(2)
                  .map((w) => w.isNotEmpty ? w[0] : '')
                  .join()
                  .toUpperCase()
              : '';
          return GestureDetector(
            onTap: () async {
              if (cuentasOpts.isEmpty) return;
              final picked = await showDialog<Map<String, dynamic>>(
                context: ctx,
                builder: (dCtx) => AppPickerDialog<Map<String, dynamic>>(
                  title: 'Seleccionar Cuenta',
                  titleIcon: Icons.account_balance_wallet_rounded,
                  items: cuentasOpts,
                  labelBuilder: (c) => (c['nombre'] ?? '').toString(),
                  colorBuilder: (c) =>
                      parseHexColor((c['color'] ?? '#4361EE').toString()),
                  selectedValue: cuentasOpts
                      .cast<Map<String, dynamic>?>()
                      .firstWhere(
                          (c) =>
                              (c?['codigo'] ?? '').toString() == selectedCuenta,
                          orElse: () => null),
                ),
              );
              if (picked != null) {
                setS(() {
                  selectedCuenta = (picked['codigo'] ?? '').toString();
                  selectedCuentaNombre = (picked['nombre'] ?? '').toString();
                  selectedCuentaColor = (picked['color'] ?? '').toString();
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: inputFill,
                border: Border.all(
                  color: hasValue
                      ? color
                      : _dialogFieldBorderColor(const Color(0xFF4361EE)),
                  width: hasValue ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                if (hasValue)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(color, Colors.white, 0.35)!,
                          color,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  )
                else
                  Icon(Icons.account_balance_wallet_rounded,
                      size: 18, color: textSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(selectedCuentaNombre ?? 'Selecciona una cuenta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: hasValue ? FontWeight.w700 : null,
                          color: hasValue ? textMain : textSoft)),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: hasValue ? color : textSoft),
              ]),
            ),
          );
        }

        // Toggle Gasto/Ingreso: al ser una elección binaria no necesita
        // abrir un picker modal aparte, un par de chips es más directo.
        Widget tipoToggle() {
          Widget chip({
            required String codigo,
            required String label,
            required IconData icon,
            required Color color,
          }) {
            final selected = selectedTipo == codigo;
            return Expanded(
              child: GestureDetector(
                onTap: () => setS(() => selectedTipo = codigo),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(colors: [
                            color,
                            Color.lerp(color, Colors.black, 0.15)!,
                          ])
                        : null,
                    color: selected ? null : inputFill,
                    border: Border.all(
                      color: selected ? color : _dialogFieldBorderColor(color),
                      width: selected ? 0 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon,
                        size: 16, color: selected ? Colors.white : color),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : color)),
                  ]),
                ),
              ),
            );
          }

          return Row(children: [
            chip(
                codigo: '2',
                label: 'Gasto',
                icon: Icons.trending_down_rounded,
                color: const Color(0xFFDC2626)),
            const SizedBox(width: 10),
            chip(
                codigo: '3',
                label: 'Ingreso',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF059669)),
          ]);
        }

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF4361EE).withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 12)),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0D1B4B),
                          Color(0xFF1E3A8A),
                          Color(0xFF4361EE),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.swap_vert_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Registrar Movimiento',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Nuevo gasto o ingreso',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      appCloseX(() => Navigator.pop(ctx)),
                    ]),
                  ),

                  // ── Form body ────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cuenta
                            fieldLabel('Cuenta'),
                            cuentaField(),
                            const SizedBox(height: 14),

                            // Tipo de movimiento
                            fieldLabel('Tipo de movimiento'),
                            tipoToggle(),
                            const SizedBox(height: 14),

                            // Valor
                            fieldLabel('Valor'),
                            TextFormField(
                              controller: valorCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  color: textMain,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5),
                              decoration: fieldDeco(
                                hint: '0',
                                icon: Icons.attach_money_rounded,
                                iconSize: 22,
                              ).copyWith(
                                prefixIconConstraints: const BoxConstraints(
                                    minWidth: 40, minHeight: 40),
                                hintStyle: const TextStyle(
                                    color: Color(0xFFB0BCCF),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingresa el valor'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // Fecha
                            fieldLabel('Fecha'),
                            pickerField(
                              value: () {
                                final p = selectedFecha.split('-');
                                return p.length == 3
                                    ? '${p[2]}/${p[1]}/${p[0]}'
                                    : selectedFecha;
                              }(),
                              hint: 'DD/MM/AAAA',
                              icon: Icons.calendar_today_rounded,
                              onTap: () async {
                                final picked = await showLightDatePicker(
                                  ctx,
                                  initialDate:
                                      DateTime.tryParse(selectedFecha) ?? now,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setS(() {
                                    selectedFecha =
                                        '${picked.year}-${pad2(picked.month)}-${pad2(picked.day)}';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Descripción
                            fieldLabel('Descripción'),
                            TextFormField(
                              controller: descCtrl,
                              maxLines: 3,
                              style: TextStyle(color: textMain, fontSize: 14),
                              decoration: fieldDeco(
                                  hint: 'Ej: Pago de servicios...',
                                  icon: Icons.notes_rounded),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Botones ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(children: [
                      Expanded(
                        child: gradBtn(
                          colors: const [
                            Color(0xFF991B1B),
                            Color(0xFFDC2626),
                            Color(0xFFEF4444)
                          ],
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
                                    showResult(false,
                                        'Seleccione una cuenta para continuar');
                                    return;
                                  }
                                  if (selectedTipo == null) {
                                    showResult(false,
                                        'Seleccione el tipo de movimiento');
                                    return;
                                  }
                                  if (!formKey.currentState!.validate()) return;
                                  setS(() => saving = true);
                                  try {
                                    final r = await repository
                                        .post('/ajax/guardar_movimiento.php', {
                                      'codigo_cuenta': selectedCuenta!,
                                      'tipo_movimiento': selectedTipo!,
                                      'valor': valorCtrl.text.trim(),
                                      'fecha': selectedFecha,
                                      'descripcion': descCtrl.text.trim(),
                                      'usuario': codigoUsuario,
                                    });
                                    if (r.statusCode == 200) {
                                      final d = decodeJsonMap(r.body);
                                      final ok = d['success'] == true ||
                                          d['resultado'] == 1;
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      showResult(
                                          ok,
                                          ok
                                              ? 'Movimiento registrado correctamente.'
                                              : friendlyError(d['msg'] ??
                                                  d['mensaje'] ??
                                                  'No se pudo guardar el movimiento'));
                                      if (ok) {
                                        // Pintar de una vez con lo local; la
                                        // recarga de red de abajo reconcilia.
                                        applyLocalMovement(
                                          codigoCuenta: selectedCuenta!,
                                          tipoMovimiento: selectedTipo!,
                                          valor: numberValue(
                                              valorCtrl.text.trim()),
                                          fecha: selectedFecha,
                                          descripcion: descCtrl.text.trim(),
                                        );
                                        repository.invalidateCache(
                                            '/ajax/listar_cuentas_gasto.php');
                                        repository.invalidateCache(
                                            '/ajax/listar_movimientos_usuario.php');
                                        unawaited(refreshAfterMovementChange());
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
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showNuevaCuentaDialog() async {
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
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

    if (!isMounted) return;

    await showDialog(
      context: screenContext,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        // Carga real en background (solo una vez)
        if (tipos.length == 2 && tipos[0]['_loaded'] == null) {
          tipos[0]['_loaded'] = true;
          repository.post('/ajax/listado_select.php', {
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

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF4361EE).withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 12)),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0D1B4B),
                          Color(0xFF1E3A8A),
                          Color(0xFF4361EE),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nueva Cuenta/Fuente',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Agrega una cuenta o fuente de fondos',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      appCloseX(() => Navigator.pop(ctx)),
                    ]),
                  ),

                  // ── Form body ────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),

                            // Nombre
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(children: [
                                Container(
                                  width: 3,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text('Nombre de la cuenta/fuente',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: textMain,
                                        letterSpacing: 0.2)),
                              ]),
                            ),
                            TextFormField(
                              controller: nombreCtrl,
                              style: TextStyle(
                                  color: textMain, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Ej. Nequi, Efectivo...',
                                hintStyle:
                                    const TextStyle(color: Color(0xFFB0BCCF)),
                                prefixIcon: const Icon(
                                    Icons.label_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: inputFill,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: _dialogFieldBorderColor(
                                            const Color(0xFF10B981)))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: _dialogFieldBorderColor(
                                            const Color(0xFF10B981)))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF10B981), width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 13),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Color
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(children: [
                                Container(
                                  width: 3,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text('Color (opcional)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: textMain,
                                        letterSpacing: 0.2)),
                              ]),
                            ),
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
                                          color: sel
                                              ? homeNavy
                                              : Colors.transparent,
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
                            const SizedBox(height: 16),

                            // Tipo
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(children: [
                                Container(
                                  width: 3,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text('Tipo de cuenta',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: textMain,
                                        letterSpacing: 0.2)),
                              ]),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final picked =
                                    await showDialog<Map<String, dynamic>>(
                                  context: ctx,
                                  builder: (dCtx) =>
                                      AppPickerDialog<Map<String, dynamic>>(
                                    title: 'Seleccionar Tipo',
                                    titleIcon: Icons.category_outlined,
                                    items: tipos,
                                    labelBuilder: (t) =>
                                        (t['nombre'] ?? '').toString(),
                                  ),
                                );
                                if (picked != null) {
                                  setS(() {
                                    selectedTipo =
                                        (picked['codigo'] ?? '').toString();
                                    selectedTipoNombre =
                                        (picked['nombre'] ?? '').toString();
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 13),
                                decoration: BoxDecoration(
                                  color: inputFill,
                                  border: Border.all(
                                      color: selectedTipo != null
                                          ? const Color(0xFF10B981)
                                          : _dialogFieldBorderColor(
                                              const Color(0xFF10B981)),
                                      width: selectedTipo != null ? 1.5 : 1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(children: [
                                  Icon(Icons.category_outlined,
                                      size: 18,
                                      color: selectedTipo != null
                                          ? const Color(0xFF10B981)
                                          : textSoft),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      selectedTipoNombre ??
                                          'Selecciona tipo de cuenta',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: selectedTipo != null
                                              ? textMain
                                              : textSoft),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: selectedTipo != null
                                          ? const Color(0xFF10B981)
                                          : textSoft),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Botones
                            Row(children: [
                              Expanded(
                                child: gradBtn(
                                  colors: const [
                                    Color(0xFFDC2626),
                                    Color(0xFFEF4444)
                                  ],
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
                                          if (!formKey.currentState!
                                              .validate()) {
                                            return;
                                          }
                                          if (selectedTipo == null) {
                                            showResult(false,
                                                'Selecciona el tipo de cuenta');
                                            return;
                                          }
                                          setS(() => saving = true);
                                          try {
                                            final r = await repository.post(
                                                '/ajax/guardar_cuenta_gasto.php',
                                                {
                                                  'nombre':
                                                      nombreCtrl.text.trim(),
                                                  'color': selectedHex,
                                                  'tipo_cuenta': selectedTipo!,
                                                  'usuario': codigoUsuario,
                                                });
                                            final d = decodeJsonMap(r.body);
                                            final raw = r.body.trim();
                                            // PHP puede devolver JSON {success:true}, '1',
                                            // o un string descriptivo — cualquier 200 sin
                                            // "error" explícito cuenta como éxito.
                                            final ok = r.statusCode == 200 &&
                                                (d['success'] == true ||
                                                    d['resultado'] == 1 ||
                                                    d['resultado'] == '1' ||
                                                    raw == '1' ||
                                                    (d.isEmpty &&
                                                        !raw
                                                            .toLowerCase()
                                                            .contains(
                                                                'error')));
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            // Siempre refrescamos si el server respondió 200
                                            if (r.statusCode == 200) {
                                              repository.invalidateCache(
                                                  '/ajax/listar_cuentas_gasto.php');
                                              await fetchAccounts(
                                                  codigoUsuario);
                                              if (isMounted) refresh(() {});
                                            }
                                            showResult(
                                                ok,
                                                ok
                                                    ? (d['msg']?.toString() ??
                                                        'Cuenta creada exitosamente')
                                                    : friendlyError(d['msg'] ??
                                                            raw.isNotEmpty
                                                        ? raw
                                                        : 'No se pudo guardar la cuenta'));
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              setS(() => saving = false);
                                            }
                                            showResult(false, friendlyError(e));
                                          }
                                        },
                                  child: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
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
                  ),
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
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
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
    int movsPage = 1;
    const movsPerPage = 20;

    bool saving = false;

    Color parseHex(String hex) {
      try {
        final h = hex.replaceAll('#', '');
        if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      } catch (_) {}
      return homeAccent;
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
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        // Cargar tipos
        if (!tiposLoaded && !loadingTipos) {
          loadingTipos = true;
          Future.microtask(() async {
            try {
              final r = await repository.post('/ajax/listado_select.php', {
                'tabla': 'tbl_cuentas_tipo',
                'valor': 'codigo',
                'etiqueta': 'nombre',
                'filtro': 'codigo=2 or codigo=3',
                'campos_orden': 'nombre ASC',
              });
              if (r.statusCode == 200) {
                final raw = jsonDecode(r.body);
                final list = raw is List
                    ? raw
                    : (raw is Map && raw['datos'] is List
                        ? raw['datos']
                        : null);
                if (list != null) {
                  tiposOpts = (list as List)
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
              final now = nowBogota();
              String pad(int n) => n.toString().padLeft(2, '0');
              final mesInicio = '${now.year}-${pad(now.month)}-01';
              final ultimoDia = DateTime(now.year, now.month + 1, 0).day;
              final mesFin = '${now.year}-${pad(now.month)}-${pad(ultimoDia)}';
              movsList = await fetchAccountMovements(codigo, codigoUsuario,
                  desde: mesInicio, hasta: mesFin);
            } catch (_) {}
            setS(() {
              loadingMovs = false;
              movsLoaded = true;
            });
          });
        }

        final previewColor = parseHex(colorCtrl.text);

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: dialogBg,
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
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 20),
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
                        appCloseX(saving ? null : () => Navigator.pop(ctx)),
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
                            buildSavingsField(
                              ctrl: nombreCtrl,
                              label: 'Nombre',
                              icon: Icons.label_outline_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingrese el nombre'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            buildSavingsFieldLabel('Color'),
                            const SizedBox(height: 6),
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: previewColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: lineCol),
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
                                  border: Border.all(color: lineCol),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: colorCtrl,
                                  style:
                                      TextStyle(color: textMain, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixText: '#',
                                    prefixStyle: const TextStyle(
                                        color: homeAccent,
                                        fontWeight: FontWeight.bold),
                                    hintText: 'RRGGBB',
                                    hintStyle: TextStyle(
                                        color: textSoft, fontSize: 13),
                                    filled: true,
                                    fillColor: inputFill,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: lineCol)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: lineCol)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: homeAccent, width: 1.5)),
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
                                final hx =
                                    hex.replaceAll('#', '').toUpperCase();
                                final active =
                                    colorCtrl.text.toUpperCase() == hx;
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
                                        color: active
                                            ? homeNavy
                                            : Colors.transparent,
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
                            buildSavingsFieldLabel('Tipo'),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: !tiposLoaded
                                  ? null
                                  : () async {
                                      final picked = await showDialog<
                                          Map<String, dynamic>>(
                                        context: ctx,
                                        builder: (dCtx) => AppPickerDialog<
                                            Map<String, dynamic>>(
                                          title: 'Seleccionar Tipo',
                                          titleIcon: Icons.category_outlined,
                                          items: tiposOpts,
                                          labelBuilder: (t) =>
                                              (t.values.last ?? '').toString(),
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
                              child: buildDateContainer(
                                  selectedTipoNombre.isNotEmpty
                                      ? selectedTipoNombre
                                      : null,
                                  '[Seleccione una Opción]'),
                            ),
                            const SizedBox(height: 16),
                            buildSavingsFieldLabel('Estado'),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDialog<String>(
                                  context: ctx,
                                  builder: (dCtx) => AppPickerDialog<String>(
                                    title: 'Estado',
                                    titleIcon: Icons.toggle_on_rounded,
                                    items: const ['1', '0'],
                                    labelBuilder: (s) =>
                                        s == '1' ? 'Activa' : 'Inactiva',
                                  ),
                                );
                                if (picked != null) {
                                  setS(() => selectedEstado = picked);
                                }
                              },
                              child: buildDateContainer(
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
                                    builder: (c2) => AppConfirmDialog(
                                      title: '¿Desactivar cuenta?',
                                      message:
                                          'La cuenta quedará inactiva y no podrás registrar movimientos en ella.',
                                      icon: Icons.block_rounded,
                                      confirmLabel: 'Desactivar',
                                      infoText: 'Esta acción es reversible',
                                      gradientColors: const [
                                        Color(0xFF92400E),
                                        Color(0xFFF59E0B),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    setS(() => saving = true);
                                    final r = await repository.post(
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
                                    if (isMounted) {
                                      bool ok = false;
                                      try {
                                        ok = jsonDecode(r.body)['success'] ==
                                            true;
                                      } catch (_) {}
                                      showDialog(
                                        context: screenContext,
                                        builder: (_) => buildResultDialog(
                                            ok
                                                ? 'Cuenta desactivada'
                                                : 'No se pudo desactivar',
                                            ok),
                                      );
                                      if (ok) {
                                        repository.invalidateCache(
                                            '/ajax/listar_cuentas_gasto.php');
                                        unawaited(fetchAccounts(codigoUsuario)
                                            .then((_) {
                                          if (isMounted) refresh(() {});
                                        }));
                                      }
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
                                    showResult(false,
                                        'Ingrese el nombre de la cuenta');
                                    return;
                                  }
                                  setS(() => saving = true);
                                  try {
                                    final r = await repository.post(
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
                                    final rawBody = r.body.trim();
                                    final j = decodeJsonMap(r.body);
                                    final ok = r.statusCode == 200 &&
                                        (j['success'] == true ||
                                            j['resultado'] == 1 ||
                                            j['resultado'] == '1' ||
                                            rawBody == '1' ||
                                            (j.isEmpty &&
                                                !rawBody
                                                    .toLowerCase()
                                                    .contains('error')));
                                    final msg = j['msg']?.toString() ??
                                        (ok
                                            ? 'Cambios guardados exitosamente'
                                            : rawBody.isNotEmpty
                                                ? rawBody
                                                : 'No se pudo guardar');
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    showResult(
                                        ok,
                                        ok
                                            ? 'Cambios guardados exitosamente'
                                            : friendlyError(msg));
                                    if (r.statusCode == 200) {
                                      repository.invalidateCache(
                                          '/ajax/listar_cuentas_gasto.php');
                                      unawaited(fetchAccounts(codigoUsuario)
                                          .then((_) {
                                        if (isMounted) refresh(() {});
                                      }));
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) setS(() => saving = false);
                                    showResult(false, friendlyError(e));
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
                                child: CircularProgressIndicator(
                                    color: homeAccent, strokeWidth: 2.5),
                              ),
                            )
                          : movsList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: inputFill,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.receipt_long_rounded,
                                              color: homeAccent,
                                              size: 28),
                                        ),
                                        const SizedBox(height: 12),
                                        Text('Sin movimientos',
                                            style: TextStyle(
                                                color: textMain,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text('No hay registros en esta cuenta',
                                            style: TextStyle(
                                                color: textSoft, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(children: [
                                  // ── Resumen del mes ─────────────────
                                  Builder(builder: (_) {
                                    double totalIn = 0, totalOut = 0;
                                    for (final m in movsList) {
                                      final v = numberValue(
                                          m['valor'] ?? m['monto'] ?? 0);
                                      final isIn = movementIsIncome(m);
                                      if (isIn) {
                                        totalIn += v.abs();
                                      } else {
                                        totalOut += v.abs();
                                      }
                                    }
                                    final now = nowBogota();
                                    final meses = [
                                      'Enero',
                                      'Febrero',
                                      'Marzo',
                                      'Abril',
                                      'Mayo',
                                      'Junio',
                                      'Julio',
                                      'Agosto',
                                      'Septiembre',
                                      'Octubre',
                                      'Noviembre',
                                      'Diciembre'
                                    ];
                                    final total = totalIn + totalOut;
                                    final ratioIn =
                                        total > 0 ? totalIn / total : 0.0;
                                    return Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          12, 8, 12, 6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF0D1B4B),
                                            Color(0xFF1E3A8A)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                              color: const Color(0xFF1E3A8A)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4))
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(children: [
                                          Row(children: [
                                            const Icon(
                                                Icons.calendar_month_rounded,
                                                color: Colors.white38,
                                                size: 13),
                                            const SizedBox(width: 4),
                                            Text(
                                                '${meses[now.month - 1]} ${now.year}',
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                  color: Colors.white12,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              child: Text(
                                                  '${movsList.length} registros',
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ]),
                                          const SizedBox(height: 14),
                                          Row(children: [
                                            Expanded(
                                                child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF4ADE80)
                                                          .withValues(
                                                              alpha: 0.18),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons.north_rounded,
                                                        size: 11,
                                                        color:
                                                            Color(0xFF4ADE80)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text('Ingresos',
                                                      style: TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ]),
                                                const SizedBox(height: 4),
                                                Text(formatCop(totalIn),
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF4ADE80),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -0.3,
                                                        fontSize: 14)),
                                              ],
                                            )),
                                            Container(
                                                width: 1,
                                                height: 36,
                                                color: Colors.white
                                                    .withValues(alpha: 0.15)),
                                            Expanded(
                                                child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      const Text('Gastos',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white54,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        width: 18,
                                                        height: 18,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                                  0xFFF87171)
                                                              .withValues(
                                                                  alpha: 0.18),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                            Icons.south_rounded,
                                                            size: 11,
                                                            color: Color(
                                                                0xFFF87171)),
                                                      ),
                                                    ]),
                                                const SizedBox(height: 4),
                                                Text(formatCop(totalOut),
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFFF87171),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -0.3,
                                                        fontSize: 14)),
                                              ],
                                            )),
                                          ]),
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            child:
                                                TweenAnimationBuilder<double>(
                                              tween: Tween(
                                                  begin: 0,
                                                  end: ratioIn.toDouble()),
                                              duration: const Duration(
                                                  milliseconds: 800),
                                              curve: Curves.easeOut,
                                              builder: (_, v, __) {
                                                if (total <= 0) {
                                                  return Container(
                                                    height: 6,
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.12),
                                                  );
                                                }
                                                final inFlex = (v * 1000)
                                                    .round()
                                                    .clamp(0, 1000);
                                                final outFlex = 1000 - inFlex;
                                                return Row(children: [
                                                  if (inFlex > 0)
                                                    Expanded(
                                                      flex: inFlex,
                                                      child: Container(
                                                          height: 6,
                                                          color: const Color(
                                                              0xFF4ADE80)),
                                                    ),
                                                  if (outFlex > 0)
                                                    Expanded(
                                                      flex: outFlex,
                                                      child: Container(
                                                          height: 6,
                                                          color: const Color(
                                                              0xFFF87171)),
                                                    ),
                                                ]);
                                              },
                                            ),
                                          ),
                                        ]),
                                      ),
                                    );
                                  }),
                                  // ── Lista de movimientos ────────────
                                  Builder(builder: (_) {
                                    final totalPags =
                                        (movsList.length / movsPerPage)
                                            .ceil()
                                            .clamp(1, 9999);
                                    final pageItems = movsList
                                        .skip((movsPage - 1) * movsPerPage)
                                        .take(movsPerPage)
                                        .toList();
                                    return Expanded(
                                        child: Column(children: [
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 2, 12, 4),
                                          itemCount: pageItems.length,
                                          itemBuilder: (_, i) {
                                            final m = pageItems[i];
                                            final fecha = (m['fecha'] ??
                                                    m['fecha_movimiento'] ??
                                                    '')
                                                .toString()
                                                .split(' ')
                                                .first;
                                            final tipoNom =
                                                (m['tipo_nombre'] ?? '')
                                                    .toString();
                                            final valor = numberValue(
                                                m['valor'] ?? m['monto'] ?? 0);
                                            final desc = (m['descripcion'] ??
                                                    m['descripción'] ??
                                                    '')
                                                .toString();
                                            final isIngreso =
                                                movementIsIncome(m);
                                            final color = isIngreso
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFDC2626);
                                            final label =
                                                isIngreso ? 'Ingreso' : 'Gasto';
                                            return TweenAnimationBuilder<
                                                double>(
                                              tween:
                                                  Tween(begin: 0.0, end: 1.0),
                                              duration: Duration(
                                                  milliseconds: 220 +
                                                      (i.clamp(0, 12) * 30)),
                                              curve: Curves.easeOut,
                                              builder: (_, val, child) =>
                                                  Opacity(
                                                opacity: val,
                                                child: Transform.translate(
                                                    offset: Offset(
                                                        0, 14 * (1 - val)),
                                                    child: child),
                                              ),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 7),
                                                decoration: BoxDecoration(
                                                  color: cardBg,
                                                  borderRadius:
                                                      BorderRadius.circular(13),
                                                  border: Border(
                                                      left: BorderSide(
                                                          color: color,
                                                          width: 3.5)),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.05),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2))
                                                  ],
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 11,
                                                      vertical: 10),
                                                  child: Row(children: [
                                                    Container(
                                                      width: 38,
                                                      height: 38,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          colors: isIngreso
                                                              ? [
                                                                  const Color(
                                                                      0xFF16A34A),
                                                                  const Color(
                                                                      0xFF4ADE80)
                                                                ]
                                                              : [
                                                                  const Color(
                                                                      0xFFDC2626),
                                                                  const Color(
                                                                      0xFFF87171)
                                                                ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                              color: color
                                                                  .withValues(
                                                                      alpha:
                                                                          0.35),
                                                              blurRadius: 6,
                                                              offset:
                                                                  const Offset(
                                                                      0, 2))
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        isIngreso
                                                            ? Icons
                                                                .arrow_downward_rounded
                                                            : Icons
                                                                .arrow_upward_rounded,
                                                        color: Colors.white,
                                                        size: 17,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                        child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          desc.isNotEmpty
                                                              ? desc
                                                              : tipoNom,
                                                          style: TextStyle(
                                                              fontSize: 12.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: textMain),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Row(children: [
                                                          const Icon(
                                                              Icons
                                                                  .calendar_today_rounded,
                                                              size: 9,
                                                              color: Color(
                                                                  0xFF8899BB)),
                                                          const SizedBox(
                                                              width: 3),
                                                          Text(fecha,
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Color(
                                                                      0xFF8899BB))),
                                                          const SizedBox(
                                                              width: 7),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        1.5),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: color
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                            child: Text(label,
                                                                style: TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color:
                                                                        color)),
                                                          ),
                                                        ]),
                                                      ],
                                                    )),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${isIngreso ? '+' : '-'} ${formatCop(valor.abs())}',
                                                      style: TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: color),
                                                    ),
                                                  ]),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      // ── Paginación ──────────────────────
                                      if (totalPags > 1)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border(
                                                top:
                                                    BorderSide(color: lineCol)),
                                          ),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: movsPage > 1
                                                      ? () =>
                                                          setS(() => movsPage--)
                                                      : null,
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color: movsPage > 1
                                                          ? (isDarkTheme
                                                              ? homeAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.18)
                                                              : const Color(
                                                                  0xFFEEF2FF))
                                                          : inputFill,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                        Icons
                                                            .chevron_left_rounded,
                                                        size: 20,
                                                        color: movsPage > 1
                                                            ? homeAccent
                                                            : textSoft),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Text('$movsPage / $totalPags',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: textMain)),
                                                const SizedBox(width: 14),
                                                GestureDetector(
                                                  onTap: movsPage < totalPags
                                                      ? () =>
                                                          setS(() => movsPage++)
                                                      : null,
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color: movsPage <
                                                              totalPags
                                                          ? (isDarkTheme
                                                              ? homeAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.18)
                                                              : const Color(
                                                                  0xFFEEF2FF))
                                                          : inputFill,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                        Icons
                                                            .chevron_right_rounded,
                                                        size: 20,
                                                        color:
                                                            movsPage < totalPags
                                                                ? homeAccent
                                                                : textSoft),
                                                  ),
                                                ),
                                              ]),
                                        ),
                                    ]));
                                  }),
                                ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: gradBtn(
                          colors: closeRedGradient,
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cerrar',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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

  double accountBalance(Map<String, dynamic> cuenta) => numberValue(
      cuenta['saldo_actual'] ?? cuenta['saldo'] ?? cuenta['balance'] ?? 0);

  Widget _cuentaRowReal(Map<String, dynamic> c, [int index = 0]) {
    final nombre = (c['nombre'] ?? 'Cuenta').toString();
    final tipo = (c['tipo_nombre'] ?? '').toString();
    final saldo = accountBalance(c);
    final estado = c['estado']?.toString() == '1';
    final hexColor = (c['color'] ?? '#4361EE').toString();
    final color = parseHexColor(hexColor);
    final initials = nombre.trim().isNotEmpty
        ? nombre.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
        : 'C';
    final cLight = Color.lerp(color, Colors.white, 0.40)!;
    final cDark = Color.lerp(color, Colors.black, 0.20)!;

    final entryInterval = Interval(
      (index * 0.07).clamp(0.0, 0.5),
      (index * 0.07 + 0.6).clamp(0.5, 1.0),
      curve: Curves.easeOutBack,
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey('cuenta_${c['codigo'] ?? c['id'] ?? nombre}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: entryInterval,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: RepaintBoundary(child: child),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showRegistrarMovimientoDialog(cuentaInicial: c),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkTheme
                  ? [
                      Color.lerp(cardBg, color, 0.10)!,
                      Color.lerp(cardBg, color, 0.04)!,
                    ]
                  : [
                      Color.lerp(Colors.white, color, 0.03)!,
                      Color.lerp(Colors.white, color, 0.10)!,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 5)),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(children: [
              // Left accent bar
              Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cLight, color, cDark],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  )),
              // Orbe decorativo del color de la cuenta
              Positioned(
                  right: -18,
                  top: -18,
                  child: IgnorePointer(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          color.withValues(alpha: 0.14),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  )),
              // Barrido de luz animado
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: shimmer,
                    builder: (_, __) => Transform.translate(
                      offset: Offset((shimmer.value * 2 - 1) * 240, 0),
                      child: Transform.rotate(
                        angle: 0.42,
                        child: Container(
                          width: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white
                                  .withValues(alpha: isDarkTheme ? 0.05 : 0.35),
                              Colors.white.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cLight, color, cDark],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white
                              .withValues(alpha: isDarkTheme ? 0.14 : 0.55),
                          width: 1.4),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text(initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: textMain)),
                        const SizedBox(height: 5),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.25),
                                  width: 0.8),
                            ),
                            child: Text(tipo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: estado
                                  ? (isDarkTheme
                                      ? const Color(0xFF16A34A)
                                          .withValues(alpha: 0.20)
                                      : const Color(0xFFDCFCE7))
                                  : (isDarkTheme
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: estado
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(estado ? 'Activa' : 'Inactiva',
                                  style: TextStyle(
                                      color: estado
                                          ? (isDarkTheme
                                              ? const Color(0xFF6EE7A0)
                                              : const Color(0xFF15803D))
                                          : textSoft,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Balance + actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      balanceVisible
                          ? TweenAnimationBuilder<double>(
                              key: ValueKey(
                                  'saldo_${c['codigo'] ?? c['id'] ?? nombre}_$saldo'),
                              tween: Tween(begin: 0.0, end: saldo),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (_, animatedSaldo, __) => Text(
                                  formatCop(animatedSaldo),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: -0.4,
                                      color: saldo >= 0
                                          ? textMain
                                          : const Color(0xFFDC2626))),
                            )
                          : Text('• • • •',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: -0.4,
                                  color: saldo >= 0
                                      ? textMain
                                      : const Color(0xFFDC2626))),
                      const SizedBox(height: 8),
                      Row(children: [
                        _iconActionBtn(
                          icon: Icons.edit_rounded,
                          colors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                          onTap: () => _showEditarCuentaDialog(c),
                        ),
                        const SizedBox(width: 6),
                        _iconActionBtn(
                          icon: Icons.balance_rounded,
                          colors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                          onTap: () => _showAjustarSaldoDialog(c),
                        ),
                      ]),
                    ],
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _iconActionBtn({
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  Widget buildMovementItem(Map<String, dynamic> m, {bool divider = false}) {
    final desc = (m['descripcion'] ?? 'Movimiento').toString();
    final cuentaNom = (m['cuenta_nombre'] ?? '').toString();
    final hexColor = (m['cuenta_color'] ?? '#4361EE').toString();
    final color = parseHexColor(hexColor);
    final isIngreso = movementIsIncome(m);
    final valor = numberValue(m['valor'] ?? 0);
    final rawFecha = (m['fecha'] ?? '').toString();
    final fecha = rawFecha.length >= 10 ? rawFecha.substring(0, 10) : rawFecha;

    final stripColor =
        isIngreso ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final amtColor =
        isIngreso ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final cLight = Color.lerp(color, Colors.white, 0.40)!;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineCol),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          // Left accent strip — ingreso=green / gasto=red
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isIngreso
                      ? [
                          const Color(0xFF34D399),
                          const Color(0xFF059669),
                          const Color(0xFF065F46)
                        ]
                      : [
                          const Color(0xFFF87171),
                          const Color(0xFFDC2626),
                          const Color(0xFF7F1D1D)
                        ],
                  stops: const [0.0, 0.5, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(children: [
              // Icon container
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cLight,
                        color,
                        Color.lerp(color, Colors.black, 0.15)!
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isIngreso
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isIngreso
                            ? [const Color(0xFF34D399), const Color(0xFF059669)]
                            : [
                                const Color(0xFFF87171),
                                const Color(0xFFDC2626)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      isIngreso ? Icons.add_rounded : Icons.remove_rounded,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              // Description + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: textMain,
                            letterSpacing: -0.2)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: color.withValues(alpha: 0.22), width: 0.8),
                        ),
                        child: Text(
                          cuentaNom.isNotEmpty ? cuentaNom : 'SAF',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.calendar_today_rounded,
                          size: 9, color: Color(0xFFB6C0D5)),
                      const SizedBox(width: 3),
                      Text(fecha,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9AA7C2),
                            fontWeight: FontWeight.w500,
                          )),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount + type + delete
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${isIngreso ? '+' : '-'}${formatCop(valor)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: -0.4,
                      color: amtColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isIngreso
                              ? [
                                  const Color(0xFF065F46),
                                  const Color(0xFF059669)
                                ]
                              : [
                                  const Color(0xFF7F1D1D),
                                  const Color(0xFFDC2626)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: stripColor.withValues(alpha: 0.30),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isIngreso ? 'Ingreso' : 'Gasto',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _confirmEliminarMovimiento(m),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: isDarkTheme
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFFEE2E2),
                                    Color(0xFFFECDD3)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: isDarkTheme
                              ? const Color(0xFFDC2626).withValues(alpha: 0.18)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFDC2626).withValues(
                                  alpha: isDarkTheme ? 0.35 : 0.25)),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 14,
                            color: isDarkTheme
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFDC2626)),
                      ),
                    ),
                  ]),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmEliminarMovimiento(Map<String, dynamic> m) async {
    final ctx = screenContext;
    final desc = (m['descripcion'] ?? 'este movimiento').toString();
    // PK field is 'codigo' as returned by listar_movimientos_cuenta.php
    final cod = (m['codigo'] ?? m['codigo_movimiento'] ?? m['id'] ?? '')
        .toString()
        .trim();

    final confirmed = await showDialog<bool>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dCtx) => AppConfirmDialog(
        title: '¿Eliminar movimiento?',
        message: desc.isNotEmpty
            ? desc
            : 'Esta acción eliminará el movimiento de forma permanente.',
        icon: Icons.delete_outline_rounded,
        confirmLabel: 'Eliminar',
        infoText: 'Esta acción no se puede deshacer',
      ),
    );

    if (confirmed != true) return;
    if (cod.isEmpty) {
      showResult(false, 'No se pudo identificar el movimiento a eliminar');
      return;
    }
    try {
      final r = await repository.post('/ajax/eliminar_movimiento.php', {
        'codigo': cod,
      });
      final d = decodeJsonMap(r.body);
      final ok = r.statusCode == 200 && d['success'] == true;
      if (isMounted) {
        if (ok) {
          final esIngreso = movementIsIncome(m);
          final valorMov = numberValue(m['valor'] ?? 0);
          refresh(() {
            bool matchCod(Map<String, dynamic> x) =>
                (x['codigo'] ?? x['codigo_movimiento'] ?? x['id'] ?? '')
                    .toString()
                    .trim() ==
                cod;
            movements.removeWhere(matchCod);
            selectedAccountMovements.removeWhere(matchCod);
            if (esIngreso) {
              serverIncome =
                  (serverIncome - valorMov).clamp(0, double.infinity);
            } else {
              serverExpenses =
                  (serverExpenses - valorMov).clamp(0, double.infinity);
            }
            invalidateComputedCache();
          });
          // Sin esto, la caché en disco (la que loadData() muestra primero
          // en un hot restart, antes de que la red termine de reconciliar)
          // se quedaba con el movimiento ya eliminado — por eso a veces
          // reaparecía justo después de un hot restart.
          unawaited(repository.saveLocalData('movimientos', movements));
          showResult(true, 'Movimiento eliminado correctamente');
          final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
          if (usuario.isNotEmpty) {
            repository.invalidateCache('/ajax/listar_cuentas_gasto.php');
            unawaited(fetchAccounts(usuario));
          }
        } else {
          final msg =
              d['msg']?.toString() ?? 'No se pudo eliminar el movimiento';
          showResult(false, msg);
        }
      }
    } catch (e) {
      debugPrint('[SAF] eliminar movimiento: $e');
      if (isMounted) showResult(false, 'Error al eliminar el movimiento');
    }
  }

  Widget _movementsSkeleton() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: skelBox(double.infinity, 60, r: 16),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: skelBox(double.infinity, 76, r: 16)),
              const SizedBox(width: 12),
              Expanded(child: skelBox(double.infinity, 76, r: 16)),
            ]),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: skelBox(160, 16, r: 6),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: skelBox(double.infinity, 72, r: 18),
            ),
          ),
        ],
      );
}

// ── Sub-tab (Cuentas/Movimientos): press-scale + cross-fade fluido ──────────
// Antes el degradado pasaba de `null` a `LinearGradient` de golpe (un color
// "vacío" no interpola bien contra un degradado) — ahora ambos estados usan
// el mismo degradado, solo cambia el alfa, así que el cross-fade es suave.
class _SubTabButton extends StatefulWidget {
  final bool active;
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color accent;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.gradient,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_SubTabButton> createState() => _SubTabButtonState();
}

class _SubTabButtonState extends State<_SubTabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.95,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fadedGradient =
        widget.gradient.map((c) => c.withValues(alpha: 0)).toList();
    return GestureDetector(
      onTapDown: (_) => _press.reverse(),
      onTapUp: (_) {
        _press.forward();
        widget.onTap();
      },
      onTapCancel: () => _press.forward(),
      child: ScaleTransition(
        scale: _press,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.active ? widget.gradient : fadedGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color:
                    widget.accent.withValues(alpha: widget.active ? 0.42 : 0.0),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.icon,
                  key: ValueKey(widget.active),
                  size: 14,
                  color: widget.active ? Colors.white : textSoft,
                ),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.active ? Colors.white : textSoft,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Botón de acción con animación de escala al presionar ─────────────────────
class _AnimatedActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  const _AnimatedActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.94,
    upperBound: 1.0,
  )..value = 1.0;

  Color get _light => isDarkTheme
      ? (Color.lerp(widget.color, const Color(0xFF243258), 0.52) ??
          widget.color)
      : (Color.lerp(widget.color, Colors.white, 0.18) ?? widget.color);
  Color get _mid => isDarkTheme
      ? (Color.lerp(widget.color, const Color(0xFF0B1731), 0.74) ??
          widget.color)
      : widget.color;
  Color get _shade => isDarkTheme
      ? (Color.lerp(widget.color, const Color(0xFF071426), 0.86) ??
          widget.color)
      : (Color.lerp(widget.color, Colors.black, 0.22) ?? widget.color);
  Color get _deep => isDarkTheme
      ? const Color(0xFF020617)
      : (Color.lerp(widget.color, Colors.black, 0.48) ?? widget.color);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_light, _mid, _shade, _deep],
              stops: const [0.0, 0.38, 0.78, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDarkTheme
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.20),
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: isDarkTheme
                    ? Colors.black.withValues(alpha: 0.42)
                    : _shade.withValues(alpha: 0.45),
                blurRadius: isDarkTheme ? 18 : 16,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color:
                    widget.color.withValues(alpha: isDarkTheme ? 0.28 : 0.18),
                blurRadius: isDarkTheme ? 12 : 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (isDarkTheme)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 17),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tile de acción: gradiente + entrada escalonada + shimmer sweep ────────────
class _ActionTile extends StatefulWidget {
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final BorderRadius borderRadius;
  final bool trailing;
  final int entranceDelay; // ms

  const _ActionTile({
    required this.onTap,
    required this.gradient,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.borderRadius,
    this.trailing = false,
    this.entranceDelay = 0,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile>
    with TickerProviderStateMixin {
  // Press scale
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    lowerBound: 0.96,
    upperBound: 1.0,
  )..value = 1.0;

  // Entrance slide+fade
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

  // Shimmer sweep (0 → 1 → pause → repeat)
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.entranceDelay), () {
      if (!_disposed && mounted) _entrance.forward();
    });
    _loopShimmer();
  }

  Future<void> _loopShimmer() async {
    while (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 3200));
      if (_disposed || !mounted) break;
      await _shimmer.forward(from: 0);
      if (_disposed || !mounted) break;
      _shimmer.value = 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _press.dispose();
    _entrance.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTapDown: (_) => _press.reverse(),
          onTapUp: (_) {
            _press.forward();
            widget.onTap();
          },
          onTapCancel: () => _press.forward(),
          child: ScaleTransition(
            scale: _press,
            // Sombra de color que respira al mismo ritmo que el halo del
            // ícono — antes el botón se veía "pegado" sobre el fondo sin
            // ninguna sombra propia, plano frente al resto de la app.
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (_, child) => Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: widget.iconColor
                          .withValues(alpha: 0.20 + 0.16 * _shimmer.value),
                      blurRadius: 16 + 8 * _shimmer.value,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: child,
              ),
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: Stack(
                  children: [
                    // ── Fondo gradiente ──────────────────────
                    Container(
                      decoration: BoxDecoration(gradient: widget.gradient),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      child: Row(
                        children: [
                          // Ícono con halo pulsante suave
                          AnimatedBuilder(
                            animation: _shimmer,
                            builder: (_, iconChild) => Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.34),
                                    Colors.white.withValues(alpha: 0.10),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(
                                        alpha: 0.10 + 0.18 * _shimmer.value),
                                    blurRadius: 12 + 6 * _shimmer.value,
                                  ),
                                ],
                              ),
                              child: iconChild,
                            ),
                            child: Icon(widget.icon,
                                color: Colors.white, size: 21),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.1,
                                    )),
                                const SizedBox(height: 2),
                                Text(widget.subtitle,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.72),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ],
                            ),
                          ),
                          if (widget.trailing)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.30)),
                              ),
                              child: Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white.withValues(alpha: 0.90),
                                  size: 15),
                            ),
                        ],
                      ),
                    ),
                    // ── Orbe decorativo ──────────────────────
                    Positioned(
                      right: -22,
                      top: -22,
                      child: IgnorePointer(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.white.withValues(alpha: 0.16),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -16,
                      bottom: -20,
                      child: IgnorePointer(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                    ),
                    // ── Shimmer diagonal sweep ───────────────
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmer,
                        builder: (_, __) {
                          final t = Curves.easeInOut.transform(_shimmer.value);
                          return Align(
                            alignment: Alignment(-2.5 + t * 5.0, 0),
                            child: FractionallySizedBox(
                              widthFactor: 0.22,
                              heightFactor: 2.0,
                              child: Transform.rotate(
                                angle: 0.4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.22),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // ── Destello táctil al presionar ─────────
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _press,
                          builder: (_, __) => Opacity(
                            opacity:
                                ((1.0 - _press.value) / 0.04).clamp(0.0, 1.0) *
                                    0.12,
                            child: Container(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card de movimiento animada: entrada + press + shimmer en icono ────────────
class _AnimatedMovementCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  final VoidCallback? onDelete;

  const _AnimatedMovementCard({
    super.key,
    required this.data,
    required this.index,
    this.onDelete,
  });

  @override
  State<_AnimatedMovementCard> createState() => _AnimatedMovementCardState();
}

class _AnimatedMovementCardState extends State<_AnimatedMovementCard>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.28),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.97,
    upperBound: 1.0,
  )..value = 1.0;

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final delay = (widget.index * 65).clamp(0, 380);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!_disposed && mounted) _entrance.forward();
    });
    _loopShimmer();
  }

  Future<void> _loopShimmer() async {
    await Future.delayed(Duration(milliseconds: 1800 + widget.index * 180));
    while (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 4200));
      if (_disposed || !mounted) break;
      await _shimmer.forward(from: 0);
      if (_disposed || !mounted) break;
      _shimmer.value = 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _entrance.dispose();
    _press.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.data;
    final desc = (m['descripcion'] ?? 'Movimiento').toString();
    final cuentaNom = (m['cuenta_nombre'] ?? '').toString();
    final hexColor = (m['cuenta_color'] ?? '#4361EE').toString();
    final color = parseHexColor(hexColor);
    final isIngreso = movementIsIncome(m);
    final valor = numberValue(m['valor'] ?? 0);
    final rawFecha = (m['fecha'] ?? '').toString();
    final fecha = rawFecha.length >= 10 ? rawFecha.substring(0, 10) : rawFecha;
    final horaRegistro = formatHoraRegistro(m['fecha_registro']);

    final stripColor =
        isIngreso ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final amtColor =
        isIngreso ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final cLight = Color.lerp(color, Colors.white, 0.40)!;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTapDown: (_) => _press.reverse(),
          onTapUp: (_) => _press.forward(),
          onTapCancel: () => _press.forward(),
          child: ScaleTransition(
            scale: _press,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkTheme
                      ? [
                          Color.lerp(cardBg, stripColor, 0.08)!,
                          Color.lerp(cardBg, stripColor, 0.03)!,
                        ]
                      : [
                          Color.lerp(Colors.white, stripColor, 0.02)!,
                          Color.lerp(Colors.white, stripColor, 0.08)!,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: stripColor.withValues(alpha: 0.20)),
                boxShadow: [
                  BoxShadow(
                    color: stripColor.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(children: [
                  // Left accent strip
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isIngreso
                              ? [
                                  const Color(0xFF34D399),
                                  const Color(0xFF059669),
                                  const Color(0xFF065F46)
                                ]
                              : [
                                  const Color(0xFFF87171),
                                  const Color(0xFFDC2626),
                                  const Color(0xFF7F1D1D)
                                ],
                          stops: const [0.0, 0.5, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                    child: Row(children: [
                      // Icon with shimmer sweep
                      Stack(clipBehavior: Clip.none, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    cLight,
                                    color,
                                    Color.lerp(color, Colors.black, 0.18)!
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isIngreso
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _shimmer,
                                builder: (_, __) => Align(
                                  alignment: Alignment.lerp(
                                    const Alignment(-2.5, -2.5),
                                    const Alignment(2.5, 2.5),
                                    _shimmer.value,
                                  )!,
                                  child: Transform.rotate(
                                    angle: pi / 4,
                                    child: Container(
                                      width: 16,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white
                                                .withValues(alpha: 0.50),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        // Badge dot
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isIngreso
                                    ? [
                                        const Color(0xFF34D399),
                                        const Color(0xFF059669)
                                      ]
                                    : [
                                        const Color(0xFFF87171),
                                        const Color(0xFFDC2626)
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBg, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: stripColor.withValues(alpha: 0.45),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isIngreso
                                  ? Icons.add_rounded
                                  : Icons.remove_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 13),
                      // Description + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: textMain,
                                    letterSpacing: -0.2)),
                            const SizedBox(height: 5),
                            Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: color.withValues(alpha: 0.25),
                                          width: 0.8),
                                    ),
                                    child: Text(
                                      cuentaNom.isNotEmpty ? cuentaNom : 'SAF',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today_rounded,
                                            size: 9, color: Color(0xFFB6C0D5)),
                                        const SizedBox(width: 3),
                                        Text(fecha,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF9AA7C2),
                                              fontWeight: FontWeight.w500,
                                            )),
                                      ]),
                                  if (horaRegistro.isNotEmpty)
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.access_time_rounded,
                                              size: 9,
                                              color: Color(0xFFB6C0D5)),
                                          const SizedBox(width: 3),
                                          Text(horaRegistro,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF9AA7C2),
                                                fontWeight: FontWeight.w500,
                                              )),
                                        ]),
                                ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount + badge + delete
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${isIngreso ? '+' : '-'}${formatCop(valor)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: -0.4,
                              color: amtColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isIngreso
                                      ? [
                                          const Color(0xFF065F46),
                                          const Color(0xFF059669)
                                        ]
                                      : [
                                          const Color(0xFF7F1D1D),
                                          const Color(0xFFDC2626)
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: stripColor.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                isIngreso ? 'Ingreso' : 'Gasto',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (widget.onDelete != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: widget.onDelete,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    gradient: isDarkTheme
                                        ? null
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFFFEE2E2),
                                              Color(0xFFFECDD3)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    color: isDarkTheme
                                        ? const Color(0xFFDC2626)
                                            .withValues(alpha: 0.18)
                                        : null,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                        color: const Color(0xFFDC2626)
                                            .withValues(
                                                alpha:
                                                    isDarkTheme ? 0.35 : 0.25)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFDC2626)
                                            .withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.delete_outline_rounded,
                                      size: 15,
                                      color: isDarkTheme
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
