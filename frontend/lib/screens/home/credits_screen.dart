// ignore_for_file: use_build_context_synchronously

import 'package:pdf/widgets.dart' as pw;

import '../../controllers/home_actions.dart';
import '../../controllers/home_data_controller.dart';
import 'dashboard_screen.dart';
import 'home_dependencies.dart';
import 'movements_screen.dart';
import 'savings_screen.dart';

extension HomeCreditsScreen<T extends StatefulWidget> on HomeController<T> {
  Widget buildCreditsScreen() {
    // No esperar a que ahorradores/movimientos terminen de cargar: esta
    // pestaña solo depende de créditos y solicitudes pendientes.
    if (loadingData && credits.isEmpty && pendingRequests.isEmpty) {
      return _creditsSkeleton();
    }

    // Totales globales (todos los registros del filtro, no solo la página actual)
    final totalPagado = creditsPaidTotal;
    final totalPendiente = creditsPendingTotal;

    final creditosFiltrados = creditsBuscar.isEmpty
        ? credits
        : credits.where((c) {
            final txt = creditsBuscar.toLowerCase();
            return (c['cliente'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(txt) ||
                (c['cod'] ?? '').toString().contains(txt);
          }).toList();

    // Solicitudes: separa pendientes reales de rechazadas (estado 3).
    // get_pendientes_lista.php no filtra en servidor (ver fetchPending), así
    // que búsqueda y estado se aplican aquí, en memoria, para ambas listas.
    final buscarTxt = creditsBuscar.trim().toLowerCase();
    bool matchBusqueda(Map<String, dynamic> p) {
      if (buscarTxt.isEmpty) return true;
      final nombre = ([p['nombres'], p['apellidos']]
              .where((x) => x != null && x.toString().isNotEmpty)
              .join(' '))
          .toLowerCase();
      final cod = (p['codigo_solicitud'] ?? p['cod'] ?? '').toString();
      return nombre.contains(buscarTxt) || cod.contains(buscarTxt);
    }

    final pendientesActivas = pendingRequests
        .where((p) =>
            (int.tryParse(p['codigo_estado']?.toString() ?? '0') ?? 0) != 3)
        .where(matchBusqueda)
        .where((p) {
          if (creditSubTab != 1 || creditStatusFilter.isEmpty) return true;
          final tieneAsesorP =
              (p['codigo_asesor'] ?? '').toString().trim().isNotEmpty;
          return creditStatusFilter == 'con_asesor'
              ? tieneAsesorP
              : !tieneAsesorP;
        })
        .toList();
    final solicitudesRechazadas = pendingRequests
        .where((p) =>
            (int.tryParse(p['codigo_estado']?.toString() ?? '0') ?? 0) == 3)
        .where(matchBusqueda)
        .toList();

    // ── Cálculo del simulador (igual que web: tasa mensual simple) ──
    final meses = simulationMonths.round();
    // Interés mensual = monto × tasa% (tasa es mensual)
    final interesMensual = simulationAmount * (simulationRate / 100);
    // Amortización mensual = monto / meses
    final amortizacionMensual = meses > 0 ? simulationAmount / meses : 0.0;
    // Cuota mensual = amortización + interés
    final cuotaMensual = amortizacionMensual + interesMensual;
    final cuotaQuincenal = cuotaMensual / 2;
    // Valor total a pagar
    final valorAPagar = cuotaMensual * meses;
    // Valor diario = interés mensual / 30
    final valorDiario = interesMensual / 30;
    // Si hay fechas, calcular intereses por días exactos
    final dias = (simulationFrom != null && simulationTo != null)
        ? simulationTo!.difference(simulationFrom!).inDays.clamp(0, 100000)
        : 0;
    final valorTotalDiario =
        dias > 0 ? simulationAmount + (valorDiario * dias) : 0.0;
    final cuotaReal = cuotaMensual;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header ──────────────────────────────────────────────
      AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0F0A3C),
                Color(0xFF1E1265),
                Color(0xFF3730A3),
                Color(0xFF4F46E5),
              ],
              stops: [0.0, 0.30, 0.65, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3730A3)
                    .withValues(alpha: 0.44 + 0.14 * shimmer.value),
                blurRadius: 26 + 10 * shimmer.value,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(children: [
              Positioned(
                right: -32,
                top: -32,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                left: -24,
                bottom: -24,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                right: 55,
                bottom: -28,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset((shimmer.value * 2 - 1) * 320, 0),
                  child: Transform.rotate(
                    angle: 0.42,
                    child: Container(
                      width: 52,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(Icons.credit_card_rounded,
                                        color: Colors.white, size: 19),
                                  ),
                                  const SizedBox(width: 12),
                                  const Flexible(
                                    child: Text('Gestión de Créditos',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2)),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                Text(
                                  'Administra solicitudes, créditos aprobados y simulaciones',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.62),
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CustomPaint(
                                    painter: SafLogoPainter(Colors.white)),
                              ),
                              const SizedBox(height: 6),
                              const Text('SAF',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2)),
                            ],
                          ),
                        ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: _creditHeaderBadge(
                          Icons.check_circle_outline_rounded,
                          '${credits.length}',
                          'activos',
                          const Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _creditHeaderBadge(
                          Icons.schedule_rounded,
                          '${pendientesActivas.length}',
                          'pendientes',
                          const Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _creditHeaderBadge(
                          Icons.cancel_outlined,
                          '${solicitudesRechazadas.length}',
                          'rechazadas',
                          const Color(0xFFF87171),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),

      // ── Sub-tabs scrollables ────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _creditoTabBtn(
                  0, 'Aprobados', Icons.check_circle_outline_rounded),
              _creditoTabBtn(1, 'Pendientes', Icons.schedule_rounded),
              _creditoTabBtn(4, 'Rechazadas', Icons.cancel_outlined),
              _creditoTabBtn(2, 'Simular crédito', Icons.calculate_outlined),
              _creditoTabBtn(
                  3, 'Estadística por fuente', Icons.bar_chart_rounded),
            ]),
          ),
        ),
      ),

      // ── Contenido por sub-tab ───────────────────────────────
      if (creditSubTab == 0 || creditSubTab == 1) ...[
        // ── Botones acción (solo en Aprobados) ───────────────────
        if (creditSubTab == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              Expanded(
                  child: buildActionButton(
                      label: 'Agregar Deudor',
                      color: const Color(0xFF4338CA),
                      icon: Icons.person_add_rounded,
                      onTap: _showCrearDeudorDialog)),
              const SizedBox(width: 10),
              Expanded(
                  child: buildActionButton(
                      label: 'Agregar Crédito',
                      color: const Color(0xFF0D9488),
                      icon: Icons.add_card_rounded,
                      onTap: _showCrearCreditoDialog)),
            ]),
          ),

        // ── Stats card ──────────────────────────────────────────
        if (creditSubTab == 0)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, entryT, entryChild) => Opacity(
              opacity: entryT.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - entryT)),
                child: RepaintBoundary(child: entryChild),
              ),
            ),
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) {
                final total = totalPagado + totalPendiente;
                final ratio =
                    total > 0 ? (totalPagado / total).clamp(0.0, 1.0) : 0.0;
                return Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0A0830),
                        Color(0xFF14105A),
                        Color(0xFF2D2B96),
                        Color(0xFF4340C8),
                      ],
                      stops: [0.0, 0.28, 0.65, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D2B96)
                            .withValues(alpha: 0.46 + 0.14 * shimmer.value),
                        blurRadius: 22 + 8 * shimmer.value,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(children: [
                      Positioned(
                        right: -24,
                        top: -24,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -16,
                        bottom: -16,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset((shimmer.value * 2 - 1) * 280, 0),
                          child: Transform.rotate(
                            angle: 0.42,
                            child: Container(
                              width: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.06),
                                  Colors.white.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: _creditsTotalStat(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'TOTAL PAGADO',
                                value: totalPagado,
                                color: const Color(0xFF34D399),
                                loading: !creditsDataLoaded,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 54,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.20),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: _creditsTotalStat(
                                icon: Icons.pending_outlined,
                                label: 'TOTAL PENDIENTE',
                                value: totalPendiente,
                                color: const Color(0xFFFBBF24),
                                loading: !creditsDataLoaded,
                              ),
                            ),
                          ]),
                          if (total > 0) ...[
                            const SizedBox(height: 18),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34D399)
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF34D399)
                                          .withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                    '${(ratio * 100).toStringAsFixed(0)}% recuperado',
                                    style: const TextStyle(
                                        color: Color(0xFF6EE7B7),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const Spacer(),
                              Text(
                                  balanceVisible
                                      ? 'Total  ${formatCop(total)}'
                                      : 'Total  • • • •',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.55),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: ratio),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, animatedRatio, __) =>
                                      FractionallySizedBox(
                                    widthFactor: animatedRatio,
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF34D399),
                                            Color(0xFF059669)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF34D399)
                                                .withValues(alpha: 0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Transform.translate(
                                            offset: Offset(
                                                (shimmer.value * 2 - 1) * 30,
                                                0),
                                            child: Container(
                                              width: 16,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white
                                                        .withValues(alpha: 0),
                                                    Colors.white.withValues(
                                                        alpha: 0.55),
                                                    Colors.white
                                                        .withValues(alpha: 0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),

        // ── Filtros: completo en Aprobados, solo Estado en Pendientes
        // (sin Asesor), solo búsqueda en Rechazadas (ver más abajo) ──
        if (creditSubTab == 0)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
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
              // Header con degradado — igual al resto de cards "Filtros".
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
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
                  const Text('Filtrar resultados',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: creditsBuscarCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar por cliente o código...',
                        hintStyle: TextStyle(fontSize: 12.5, color: textSoft),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.search_rounded,
                                size: 15, color: Colors.white),
                          ),
                        ),
                        suffixIcon: creditsBuscar.isNotEmpty
                            ? GestureDetector(
                                onTap: () async {
                                  creditsBuscarDebounce?.cancel();
                                  creditsBuscarCtrl.clear();
                                  refresh(() {
                                    creditsBuscar = '';
                                    creditsPage = 1;
                                    queryingCredits = true;
                                  });
                                  await fetchCredits('');
                                  if (isMounted) {
                                    refresh(() => queryingCredits = false);
                                  }
                                },
                                child: Icon(Icons.close_rounded,
                                    size: 16, color: textSoft),
                              )
                            : null,
                        filled: true,
                        fillColor: inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: lineCol),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: lineCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF4338CA), width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: textMain),
                      onChanged: (v) {
                        refresh(() => creditsBuscar = v.trim());
                        creditsBuscarDebounce?.cancel();
                        creditsBuscarDebounce =
                            Timer(const Duration(milliseconds: 500), () async {
                          if (!isMounted) return;
                          refresh(() {
                            creditsPage = 1;
                            queryingCredits = true;
                          });
                          await fetchCredits('');
                          if (isMounted) refresh(() => queryingCredits = false);
                        });
                      },
                      onSubmitted: (_) async {
                        creditsBuscarDebounce?.cancel();
                        refresh(() {
                          creditsPage = 1;
                          queryingCredits = true;
                        });
                        await fetchCredits('');
                        if (isMounted) refresh(() => queryingCredits = false);
                      },
                    ),
                    const SizedBox(height: 10),
                    if (isAdmin && advisors.isEmpty && !advisorsFetchInFlight)
                      Builder(builder: (_) {
                        // El listado de asesores del filtro puede quedar vacío si
                        // el fetch de bootstrap falló/expiró (servidor lento). Sin
                        // este reintento, el dropdown se queda en "Todos" para
                        // siempre hasta reiniciar la app.
                        advisorsFetchInFlight = true;
                        fetchAdvisors().whenComplete(() {
                          advisorsFetchInFlight = false;
                          if (isMounted) refresh(() {});
                        });
                        return const SizedBox.shrink();
                      }),
                    Row(children: [
                      if (isAdmin)
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('ASESOR',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: textSoft,
                                      letterSpacing: 0.6)),
                              const SizedBox(height: 5),
                              Container(
                                height: 44,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  gradient: creditAdvisorFilter.isNotEmpty
                                      ? LinearGradient(
                                          colors: [
                                            const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.14),
                                            const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.05),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: creditAdvisorFilter.isEmpty
                                      ? inputFill
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: creditAdvisorFilter.isNotEmpty
                                          ? const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.45)
                                          : lineCol),
                                ),
                                child: Row(children: [
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: advisors.any((a) =>
                                                (a['sigla'] ?? '').toString() ==
                                                creditAdvisorFilter)
                                            ? creditAdvisorFilter
                                            : null,
                                        isExpanded: true,
                                        dropdownColor: dialogBg,
                                        hint: Text('Todos',
                                            style: TextStyle(
                                                fontSize: 12, color: textSoft)),
                                        style: TextStyle(
                                            fontSize: 12.5, color: textMain),
                                        icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: textSoft),
                                        items: [
                                          DropdownMenuItem(
                                              value: null,
                                              child: Row(children: [
                                                advisorAvatarMini('', size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: Text('Todos',
                                                        style: TextStyle(
                                                            color: textMain))),
                                              ])),
                                          ...advisors.map((a) {
                                            final sigla = (a['sigla'] ??
                                                    a['codigo_asesor'] ??
                                                    a['codigo'] ??
                                                    '')
                                                .toString()
                                                .trim();
                                            final nombre = ([
                                              a['nombres'],
                                              a['apellidos']
                                            ]
                                                    .where((x) =>
                                                        x != null &&
                                                        x.toString().isNotEmpty)
                                                    .join(' '))
                                                .trim();
                                            final display = nombre.isNotEmpty
                                                ? nombre
                                                : sigla;
                                            return DropdownMenuItem(
                                                value: sigla,
                                                child: Row(children: [
                                                  advisorAvatarMini(sigla,
                                                      size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                      child: Text(display,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                              color:
                                                                  textMain))),
                                                ]));
                                          }),
                                        ],
                                        onChanged: (v) async {
                                          refresh(() {
                                            creditAdvisorFilter = v ?? '';
                                            creditsPage = 1;
                                            queryingCredits = true;
                                          });
                                          try {
                                            if (creditSubTab == 0) {
                                              await fetchCredits('');
                                            } else {
                                              await fetchPending();
                                            }
                                          } finally {
                                            if (isMounted) {
                                              refresh(() =>
                                                  queryingCredits = false);
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ])),
                      if (isAdmin) const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('ESTADO',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: textSoft,
                                    letterSpacing: 0.6)),
                            const SizedBox(height: 5),
                            Container(
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                gradient: creditStatusFilter.isNotEmpty
                                    ? LinearGradient(
                                        colors: [
                                          const Color(0xFF3B82F6)
                                              .withValues(alpha: 0.14),
                                          const Color(0xFF3B82F6)
                                              .withValues(alpha: 0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: creditStatusFilter.isEmpty
                                    ? inputFill
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: creditStatusFilter.isNotEmpty
                                        ? const Color(0xFF3B82F6)
                                            .withValues(alpha: 0.45)
                                        : lineCol),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF60A5FA),
                                        Color(0xFF3B82F6),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.radio_button_checked_rounded,
                                      size: 13,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: creditStatusFilter.isEmpty
                                          ? null
                                          : creditStatusFilter,
                                      isExpanded: true,
                                      dropdownColor: dialogBg,
                                      hint: Text('Todos',
                                          style: TextStyle(
                                              fontSize: 12, color: textSoft)),
                                      style: TextStyle(
                                          fontSize: 12.5, color: textMain),
                                      icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: textSoft),
                                      items: [
                                        DropdownMenuItem(
                                            value: null,
                                            child: Text('Todos',
                                                style: TextStyle(
                                                    color: textMain))),
                                        DropdownMenuItem(
                                            value: '1',
                                            child: Row(children: [
                                              Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                          color:
                                                              Color(0xFF16A34A),
                                                          shape:
                                                              BoxShape.circle)),
                                              const SizedBox(width: 6),
                                              const Text('Activo',
                                                  style: TextStyle(
                                                      color: Color(0xFF16A34A),
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ])),
                                        DropdownMenuItem(
                                            value: '2',
                                            child: Row(children: [
                                              Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                          color:
                                                              Color(0xFF0369A1),
                                                          shape:
                                                              BoxShape.circle)),
                                              const SizedBox(width: 6),
                                              const Text('Pagado',
                                                  style: TextStyle(
                                                      color: Color(0xFF0369A1),
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ])),
                                        DropdownMenuItem(
                                            value: 'atrasado',
                                            child: Row(children: [
                                              Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                          color:
                                                              Color(0xFFDC2626),
                                                          shape:
                                                              BoxShape.circle)),
                                              const SizedBox(width: 6),
                                              const Text('Atrasados',
                                                  style: TextStyle(
                                                      color: Color(0xFFDC2626),
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ])),
                                      ],
                                      onChanged: (v) async {
                                        refresh(() {
                                          creditStatusFilter = v ?? '';
                                          creditsPage = 1;
                                          queryingCredits = true;
                                        });
                                        try {
                                          if (creditSubTab == 0) {
                                            await fetchCredits('');
                                          } else {
                                            await fetchPending();
                                          }
                                        } finally {
                                          if (isMounted) {
                                            refresh(
                                                () => queryingCredits = false);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ])),
                    ]),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: queryingCredits
                          ? null
                          : () async {
                              refresh(() => queryingCredits = true);
                              try {
                                if (creditSubTab == 0) {
                                  refresh(() => creditsPage = 1);
                                  await fetchCredits('');
                                } else {
                                  refresh(() => pendingPage = 1);
                                  await fetchPending();
                                }
                              } finally {
                                if (isMounted) {
                                  refresh(() => queryingCredits = false);
                                }
                              }
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 42,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: queryingCredits
                              ? null
                              : const LinearGradient(
                                  colors: [
                                      Color(0xFF4338CA),
                                      Color(0xFF2D2A9E)
                                    ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                          color:
                              queryingCredits ? const Color(0xFFE2E8F0) : null,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: queryingCredits
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
                          child: queryingCredits
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF4338CA))))
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                  ],
                ),
              ),
            ]),
          ),
        // ── Filtro simple: solo Estado (Pendiente/Con Asesor), sin Asesor —
        // fetchPending() no llama al servidor con esto, se filtra en
        // memoria (ver pendientesActivas más arriba) ──
        if (creditSubTab == 1)
          _buildSimpleFilterCard(
            statusOptions: const [
              ('pendiente', 'Pendiente', Color(0xFFF59E0B)),
              ('con_asesor', 'Con Asesor', Color(0xFF2563EB)),
            ],
          ),
        // ── Lista Aprobados ──
        if (creditSubTab == 0) ...[
          if (creditosFiltrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildEmptyActivity(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                  children: creditosFiltrados
                      .asMap()
                      .entries
                      .map((e) => _creditoCard(e.value, e.key))
                      .toList()),
            ),
          if (creditsTotal > creditsPageSize)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: buildPaginationBar([
                buildPaginationButton(
                    Icons.chevron_left_rounded, creditsPage > 1, () async {
                  refresh(() => creditsPage--);
                  await fetchCredits('', soloListado: true);
                  if (isMounted) refresh(() {});
                }),
                const SizedBox(width: 8),
                Expanded(
                    child: Center(
                        child: buildPaginationLabel(
                  'Pág $creditsPage de ${((creditsTotal - 1) ~/ creditsPageSize) + 1}  ·  $creditsTotal registros',
                ))),
                const SizedBox(width: 8),
                buildPaginationButton(Icons.chevron_right_rounded,
                    creditsPage * creditsPageSize < creditsTotal, () async {
                  refresh(() => creditsPage++);
                  await fetchCredits('', soloListado: true);
                  if (isMounted) refresh(() {});
                }),
              ]),
            ),
        ],
        // ── Lista Pendientes ──
        if (creditSubTab == 1) ...[
          if (pendingLoading && !pendingLoaded)
            buildPendingSkeleton()
          else if (pendingError != null && !pendingLoaded)
            _pendientesRetryCard()
          else if (pendientesActivas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildEmptyActivity(
                title: 'Sin solicitudes pendientes',
                subtitle: 'No hay solicitudes registradas',
                icon: Icons.schedule_rounded,
                accent: const Color(0xFFF59E0B),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                  children: pendientesActivas
                      .asMap()
                      .entries
                      .map((e) => _pendienteCard(e.value, e.key))
                      .toList()),
            ),
          if (pendingLoading && pendingLoaded)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (pendingError != null && pendingLoaded)
            _pendientesRetryCard(compact: true),
          if (pendingTotal > creditsPageSize)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: buildPaginationBar([
                buildPaginationButton(
                    Icons.chevron_left_rounded, pendingPage > 1, () async {
                  refresh(() => pendingPage--);
                  await fetchPending();
                  if (isMounted) refresh(() {});
                }),
                const SizedBox(width: 8),
                Expanded(
                    child: Center(
                        child: buildPaginationLabel(
                  'Pág $pendingPage de ${((pendingTotal - 1) ~/ creditsPageSize) + 1}  ·  $pendingTotal solicitudes',
                ))),
                const SizedBox(width: 8),
                buildPaginationButton(Icons.chevron_right_rounded,
                    pendingPage * creditsPageSize < pendingTotal, () async {
                  refresh(() => pendingPage++);
                  await fetchPending();
                  if (isMounted) refresh(() {});
                }),
              ]),
            ),
        ],
      ] else if (creditSubTab == 2) ...[
        // ── SIMULAR CRÉDITO ──────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: cardSheen,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lineCol, width: 1),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 5))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Sliders ──────────────────────────────────────
            _simSliderBlock(
              icon: Icons.schedule_rounded,
              label: 'Tiempo en Meses',
              displayValue: '${simulationMonths.round()} meses',
              color: const Color(0xFF4F46E5),
              slider: Slider(
                value: simulationMonths,
                min: 1,
                max: 24,
                divisions: 23,
                activeColor: const Color(0xFF4F46E5),
                inactiveColor: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                onChanged: (v) => refresh(() => simulationMonths = v),
              ),
            ),
            _simSliderBlock(
              icon: Icons.attach_money_rounded,
              label: 'Monto solicitado',
              displayValue: formatCop(simulationAmount),
              color: const Color(0xFF0EA5E9),
              slider: Slider(
                value: simulationAmount,
                min: 100000,
                max: 3000000,
                divisions: 29,
                activeColor: const Color(0xFF0EA5E9),
                inactiveColor: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                onChanged: (v) => refresh(() => simulationAmount = v),
              ),
            ),
            _simSliderBlock(
              icon: Icons.percent_rounded,
              label: 'Tasa interés',
              displayValue: '${simulationRate.round()}%',
              color: const Color(0xFF8B5CF6),
              slider: Slider(
                value: simulationRate,
                min: 5,
                max: 20,
                divisions: 15,
                activeColor: const Color(0xFF8B5CF6),
                inactiveColor: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                onChanged: (v) => refresh(() => simulationRate = v),
              ),
            ),

            // ── Fechas ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Expanded(
                    child: _simDateField('Fecha Desde', simulationFrom,
                        (d) => refresh(() => simulationFrom = d))),
                const SizedBox(width: 12),
                Expanded(
                    child: _simDateField('Fecha Hasta', simulationTo,
                        (d) => refresh(() => simulationTo = d))),
              ]),
            ),
            if (simulationFrom != null && simulationTo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Días del período: $dias',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w700)),
                ),
              ),

            const SizedBox(height: 12),

            // ── Resultado principal: Cuota mensual ───────────
            AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) => Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F0A3C),
                      Color(0xFF1E1265),
                      Color(0xFF3730A3),
                      Color(0xFF4F46E5),
                    ],
                    stops: [0.0, 0.28, 0.65, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3730A3)
                          .withValues(alpha: 0.44 + 0.14 * shimmer.value),
                      blurRadius: 22 + 8 * shimmer.value,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(children: [
                    Positioned(
                        right: -24,
                        top: -24,
                        child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  Colors.white.withValues(alpha: 0.13),
                                  Colors.transparent,
                                ])))),
                    Positioned.fill(
                      child: Transform.translate(
                          offset: Offset((shimmer.value * 2 - 1) * 280, 0),
                          child: Transform.rotate(
                              angle: 0.42,
                              child: Container(
                                  width: 44,
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.07),
                                    Colors.white.withValues(alpha: 0),
                                  ]))))),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 1),
                          ),
                          child: const Icon(Icons.calculate_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cuota mensual estimada',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.65),
                                      fontSize: 12)),
                              const SizedBox(height: 5),
                              Text(formatCop(cuotaReal),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5)),
                            ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Desglose completo ────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lineCol, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(children: [
                _simResultRow(Icons.today_rounded, 'Valor Diaria',
                    formatCop(valorDiario), const Color(0xFF0EA5E9)),
                if (dias > 0)
                  _simResultRow(
                      Icons.calendar_month_rounded,
                      'Total c/ intereses diarios',
                      formatCop(valorTotalDiario),
                      const Color(0xFF8B5CF6)),
                _simResultRow(
                    Icons.repeat_rounded,
                    '$meses Cuota(s) Mensual(es)',
                    formatCop(cuotaMensual),
                    const Color(0xFF4F46E5)),
                _simResultRow(
                    Icons.format_list_numbered_rounded,
                    '${meses * 2} Cuota(s) Quincenal(es)',
                    formatCop(cuotaQuincenal),
                    const Color(0xFF06B6D4)),
                _simResultRow(
                    Icons.account_balance_wallet_rounded,
                    'Valor a Pagar',
                    formatCop(valorAPagar),
                    const Color(0xFF16A34A),
                    destacado: true),
              ]),
            ),
          ]),
        ),
      ] else if (creditSubTab == 3) ...[
        // ── ESTADÍSTICA POR FUENTE ───────────────────────────
        _estadisticaCreditosWidget(),
      ] else if (creditSubTab == 4) ...[
        // ── Filtro simple: solo búsqueda ──
        _buildSimpleFilterCard(showStatus: false),
        // ── Lista Rechazadas ──
        if (pendingLoading && !pendingLoaded)
          buildPendingSkeleton()
        else if (pendingError != null && !pendingLoaded)
          _pendientesRetryCard()
        else if (solicitudesRechazadas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: buildEmptyActivity(
              title: 'Sin solicitudes rechazadas',
              subtitle: 'No hay solicitudes rechazadas registradas',
              icon: Icons.cancel_outlined,
              accent: const Color(0xFFDC2626),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
                children: solicitudesRechazadas
                    .asMap()
                    .entries
                    .map((e) => _pendienteCard(e.value, e.key))
                    .toList()),
          ),
      ],
    ]);
  }

  // ── Estadística por Fuente — filtros + barras horizontales ──────
  Widget _estadisticaCreditosWidget() {
    String labelOf(Map<String, dynamic> d) => (d['fuente'] ?? '?').toString();
    double salidasOf(Map<String, dynamic> d) => numberValue(d['total_salidas']);
    double entradasOf(Map<String, dynamic> d) =>
        numberValue(d['total_entradas']);

    String fmtDate(DateTime? d) => d == null
        ? 'dd/mm/aaaa'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    // Punto de color que identifica la fuente/cuenta — el mismo color que
    // ya se usa en las barras de "Balance por Fuente" (tbl_cuentas.color),
    // para que el filtro y el gráfico se lean como lo mismo.
    Widget fuenteDot(Color color) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );

    // Fuentes = las que realmente aparecen en los créditos (creditStatistics,
    // ya cargado por get_estadistica_fuente.php), NO las cuentas personales
    // del usuario logueado (`accounts`, del tab Movimientos). tbl_cuentas
    // guarda una fila POR USUARIO con el mismo nombre pero codigo distinto
    // (p.ej. "Bancolombia" del admin = codigo 2, la de un asesor = codigo
    // 24) — filtrar con el codigo personal de un asesor no encontraba nada,
    // aunque la fuente correcta sí tuviera créditos.
    final fuenteItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '0',
        child: Row(children: [
          fuenteDot(textSoft.withValues(alpha: 0.45)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Todas las fuentes')),
        ]),
      ),
      ...creditStatistics
          .where((d) => d['codigo'] != null && d['fuente'] != 'Sin fuente')
          .map((d) {
        final label = (d['fuente'] ?? '').toString();
        final codigo = d['codigo'].toString();
        final color = parseHexColor(d['color']?.toString().isNotEmpty == true
            ? d['color'].toString()
            : '94A3B8');
        return DropdownMenuItem(
          value: codigo,
          child: Row(children: [
            fuenteDot(color),
            const SizedBox(width: 8),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]),
        );
      }),
    ];

    Future<void> pickDate(bool isDesde) async {
      final picked = await showLightDatePicker(
        screenContext,
        initialDate: (isDesde ? sourceStatisticsFrom : sourceStatisticsTo) ??
            DateTime.now(),
        firstDate: DateTime(2015),
        lastDate: DateTime(2035),
      );
      if (picked != null && isMounted) {
        refresh(() {
          if (isDesde) {
            sourceStatisticsFrom = picked;
          } else {
            sourceStatisticsTo = picked;
          }
        });
      }
    }

    // helpers de estilo local
    final borderCol = lineCol;
    final bgField = cardBgAlt;
    final hintCol = textSoft;

    InputDecoration fieldDeco(String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: hintCol),
          prefixIcon: Icon(icon, size: 16, color: hintCol),
          filled: true,
          fillColor: bgField,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderCol)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderCol)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: homeNavy, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              Expanded(
                  child: Text(fmtDate(val),
                      style: TextStyle(
                          fontSize: 13,
                          color: val == null ? hintCol : textMain))),
              if (val != null)
                GestureDetector(
                    onTap: () => refresh(() {
                          if (label.contains('desde')) {
                            sourceStatisticsFrom = null;
                          } else {
                            sourceStatisticsTo = null;
                          }
                        }),
                    child: Icon(Icons.close, size: 14, color: hintCol)),
            ]),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ────────────────────────────────────────────
        AnimatedBuilder(
          animation: shimmer,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0A0830),
                  Color(0xFF14105A),
                  Color(0xFF2D2B96),
                  Color(0xFF4340C8),
                ],
                stops: [0.0, 0.28, 0.65, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D2B96)
                      .withValues(alpha: 0.46 + 0.14 * shimmer.value),
                  blurRadius: 22 + 8 * shimmer.value,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(children: [
                Positioned(
                    right: -22,
                    top: -22,
                    child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.white.withValues(alpha: 0.13),
                              Colors.transparent,
                            ])))),
                Positioned.fill(
                    child: Transform.translate(
                        offset: Offset((shimmer.value * 2 - 1) * 280, 0),
                        child: Transform.rotate(
                            angle: 0.42,
                            child: Container(
                                width: 44,
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.06),
                                  Colors.white.withValues(alpha: 0),
                                ])))))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1),
                      ),
                      child: const Icon(Icons.bar_chart_rounded,
                          color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Balance por Fuente',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2)),
                            const SizedBox(height: 3),
                            Text('Créditos otorgados vs cuotas recibidas',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.60),
                                    fontSize: 11)),
                          ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Card de filtros ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Estado
            DropdownButtonFormField<String>(
              // El valor puede haber quedado guardado de una sesión previa
              // con una opción que ya no existe (p.ej. el antiguo '3' de
              // "Pendientes") — sin este resguardo, Flutter lanza una
              // excepción de valor no encontrado que deja la pantalla en
              // blanco con un loop infinito de errores de layout.
              initialValue: const {'', '1', '2', 'atrasado'}
                      .contains(sourceStatisticsStatus)
                  ? sourceStatisticsStatus
                  : '',
              decoration: fieldDeco('Estado', Icons.filter_list_rounded),
              dropdownColor: dialogBg,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: hintCol),
              style: TextStyle(fontSize: 13, color: textMain),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Row(children: [
                    fuenteDot(textSoft.withValues(alpha: 0.45)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Todos')),
                  ]),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Row(children: [
                    fuenteDot(const Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Activos')),
                  ]),
                ),
                DropdownMenuItem(
                  value: '2',
                  child: Row(children: [
                    fuenteDot(const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Pagados')),
                  ]),
                ),
                // "Atrasado" no es un codigo_estado del servidor: es un
                // crédito Activo cuya próxima cuota ya venció (igual que
                // el filtro "Atrasados" del listado de Créditos).
                DropdownMenuItem(
                  value: 'atrasado',
                  child: Row(children: [
                    fuenteDot(const Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Atrasados')),
                  ]),
                ),
              ],
              onChanged: (v) {
                refresh(() => sourceStatisticsStatus = v ?? '');
                applyStatisticsFilters();
              },
            ),
            const SizedBox(height: 10),

            // Fechas
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Desde',
                        style: TextStyle(
                            fontSize: 11,
                            color: hintCol,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    datePicker(
                        'desde', sourceStatisticsFrom, () => pickDate(true)),
                  ])),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Hasta',
                        style: TextStyle(
                            fontSize: 11,
                            color: hintCol,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    datePicker(
                        'hasta', sourceStatisticsTo, () => pickDate(false)),
                  ])),
            ]),
            const SizedBox(height: 10),

            // Fuente
            DropdownButtonFormField<String>(
              // Igual que el resguardo de "Estado": si el valor guardado ya
              // no existe entre las fuentes actuales (p.ej. creditStatistics
              // aún no había cargado cuando se seleccionó, o cambió de
              // usuario), Flutter lanza una excepción de valor no encontrado
              // que deja la pantalla en blanco con un loop de errores.
              initialValue:
                  fuenteItems.any((i) => i.value == sourceStatisticsAccount)
                      ? sourceStatisticsAccount
                      : '0',
              decoration: fieldDeco('Fuente', Icons.account_balance_outlined),
              dropdownColor: dialogBg,
              // Los items ahora llevan un punto de color + Expanded(Text) —
              // sin isExpanded:true, Flutter mide el ancho intrínseco sin
              // acotar y el Expanded revienta con un error de layout en
              // cascada (RenderBox was not laid out) que deja la pantalla
              // en blanco con un loop infinito de excepciones.
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: hintCol),
              style: TextStyle(fontSize: 13, color: textMain),
              items: fuenteItems,
              onChanged: (v) {
                refresh(() => sourceStatisticsAccount = v ?? '0');
                applyStatisticsFilters();
              },
            ),
            const SizedBox(height: 14),

            // Botón
            GestureDetector(
              onTap: sourceStatisticsLoading ? null : applyStatisticsFilters,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: sourceStatisticsLoading ? 0.7 : 1.0,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F0A3C),
                        Color(0xFF1E1265),
                        Color(0xFF3730A3),
                        Color(0xFF4F46E5),
                      ],
                      stops: [0.0, 0.28, 0.65, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFF3730A3).withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 6)),
                      BoxShadow(
                          color:
                              const Color(0xFF4F46E5).withValues(alpha: 0.20),
                          blurRadius: 30,
                          spreadRadius: -4,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Center(
                      child: sourceStatisticsLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  Icon(Icons.bar_chart_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 10),
                                  Text('Mostrar Gráficos',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: 0.2)),
                                ])),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Gráficas ───────────────────────────────────────────
        if (creditStatistics.isEmpty)
          buildEmptyActivity()
        else ...[
          _barChartSection(
            title: 'Salidas por fuente (Créditos otorgados)',
            barColor: const Color(0xFFDC2626),
            data: creditStatistics,
            labelFn: labelOf,
            valueFn: salidasOf,
            total: creditStatistics.fold(0.0, (s, d) => s + salidasOf(d)),
            totalLabel: 'Total salidas',
          ),
          const SizedBox(height: 20),
          _barChartSection(
            title: 'Entradas por fuente (Cuotas pagadas)',
            barColor: const Color(0xFF16A34A),
            data: creditStatistics,
            labelFn: labelOf,
            valueFn: entradasOf,
            total: creditStatistics.fold(0.0, (s, d) => s + entradasOf(d)),
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
        gradient: LinearGradient(
          colors: cardSheen,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineCol, width: 1),
        boxShadow: [
          BoxShadow(
              color: barColor.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Título con pill de color
        Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: barColor.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(
              barColor == const Color(0xFF16A34A)
                  ? Icons.south_rounded
                  : Icons.north_rounded,
              size: 14,
              color: barColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textMain))),
        ]),
        const SizedBox(height: 14),
        // Barras horizontales con gradiente y animación
        ...sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          final val = valueFn(d);
          final pct = val / maxVal;
          final name = labelFn(d);
          final rowColor = parseHexColor(
              d['color']?.toString() ?? barColor.toARGB32().toRadixString(16));
          final darkRowColor =
              Color.lerp(rowColor, Colors.black, 0.30) ?? rowColor;
          final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';

          return TweenAnimationBuilder<double>(
            key: ValueKey('bar_${title}_$i'),
            tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
            duration: Duration(milliseconds: 600 + i * 80),
            curve: Curves.easeOutCubic,
            builder: (_, animPct, __) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 80,
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7A99))),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: rowColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: animPct.clamp(0.04, 1.0),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.lerp(rowColor, Colors.white, 0.18) ??
                                    rowColor,
                                rowColor,
                                darkRowColor,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: rowColor.withValues(alpha: 0.45),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                // Badge de porcentaje: siempre visible, ya no depende de que
                // la barra sea lo bastante ancha para contener el texto.
                SizedBox(
                  width: 34,
                  child: Text(pctLabel,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: rowColor)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: Text(formatCop(val),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: rowColor)),
                ),
              ]),
            ),
          );
        }),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              barColor.withValues(alpha: 0.08),
              barColor.withValues(alpha: 0.35),
              barColor.withValues(alpha: 0.08),
            ]),
          ),
        ),
        Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.functions_rounded, size: 12, color: barColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(totalLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textMain)),
          ),
          Text(formatCop(total),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: barColor)),
        ]),
      ]),
    );
  }

  // Colores por pestaña: 0 Aprobados=verde, 1 Pendientes=amarillo,
  // 2 Simular crédito=azul/índigo, 3 Estadística=fucsia, 4 Rechazadas=rojo
  static const _tabGradients = <int, List<Color>>{
    0: [Color(0xFF064E3B), Color(0xFF10B981)],
    1: [Color(0xFF92400E), Color(0xFFF59E0B)],
    2: [Color(0xFF0F0A3C), Color(0xFF2D2B96), Color(0xFF4F46E5)],
    3: [Color(0xFF701A75), Color(0xFFEC4899)],
    4: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
  };
  static const _tabAccents = <int, Color>{
    0: Color(0xFF10B981),
    1: Color(0xFFF59E0B),
    2: Color(0xFF4F46E5),
    3: Color(0xFFEC4899),
    4: Color(0xFFDC2626),
  };

  // Filtro reducido para Pendientes (solo Estado, sin Asesor — ver
  // pendientesActivas más arriba) y Rechazadas (solo búsqueda). Mismo
  // lenguaje visual que el filtro completo de Aprobados, sin duplicar toda
  // esa lógica de Asesor/paginación de servidor que no aplica aquí.
  Widget _buildSimpleFilterCard({
    bool showStatus = true,
    List<(String, String, Color)> statusOptions = const [],
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
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
            const Text('Filtrar resultados',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: creditsBuscarCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente o código...',
                  hintStyle: TextStyle(fontSize: 12.5, color: textSoft),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.search_rounded,
                          size: 15, color: Colors.white),
                    ),
                  ),
                  suffixIcon: creditsBuscar.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            creditsBuscarCtrl.clear();
                            refresh(() => creditsBuscar = '');
                          },
                          child: Icon(Icons.close_rounded,
                              size: 16, color: textSoft),
                        )
                      : null,
                  filled: true,
                  fillColor: inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF4338CA), width: 1.5),
                  ),
                ),
                style: TextStyle(fontSize: 13, color: textMain),
                // Filtrado en memoria (pendientesActivas/solicitudesRechazadas
                // ya aplican creditsBuscar) — no hace falta debounce ni
                // llamada al servidor, solo refrescar el build.
                onChanged: (v) => refresh(() => creditsBuscar = v.trim()),
              ),
              if (showStatus) ...[
                const SizedBox(height: 10),
                Text('ESTADO',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textSoft,
                        letterSpacing: 0.6)),
                const SizedBox(height: 5),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: creditStatusFilter.isNotEmpty
                            ? (statusOptions.firstWhere(
                                        (o) => o.$1 == creditStatusFilter,
                                        orElse: () => ('', '', lineCol))
                                    .$3)
                                .withValues(alpha: 0.45)
                            : lineCol),
                  ),
                  child: Row(children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.radio_button_checked_rounded,
                          size: 13, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: creditStatusFilter.isEmpty
                              ? null
                              : creditStatusFilter,
                          isExpanded: true,
                          dropdownColor: dialogBg,
                          hint: Text('Todos',
                              style: TextStyle(fontSize: 12, color: textSoft)),
                          style: TextStyle(fontSize: 12.5, color: textMain),
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: textSoft),
                          items: [
                            DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todos',
                                    style: TextStyle(color: textMain))),
                            ...statusOptions.map((o) => DropdownMenuItem<String>(
                                value: o.$1,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                              color: o.$3,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(o.$2,
                                          style: TextStyle(
                                              color: o.$3,
                                              fontWeight: FontWeight.w600)),
                                    ]))),
                          ]
                              .toList(),
                          onChanged: (v) =>
                              refresh(() => creditStatusFilter = v ?? ''),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _creditoTabBtn(int index, String label, IconData icon) {
    final active = creditSubTab == index;
    final accent = _tabAccents[index] ?? const Color(0xFF4F46E5);
    final gradientColors = _tabGradients[index] ?? _tabGradients[2]!;
    return _CreditoTabButton(
      active: active,
      icon: icon,
      label: label,
      gradient: gradientColors,
      accent: accent,
      onTap: () {
        // creditStatusFilter usa claves distintas por tab ('1'/'2'/'atrasado'
        // en Aprobados vs 'pendiente'/'con_asesor' en Pendientes) — sin
        // resetear, un valor residual del tab anterior no coincidiría con
        // ningún option visible pero seguiría filtrando en memoria.
        refresh(() {
          creditSubTab = index;
          creditStatusFilter = '';
        });
        if (index == 1 || index == 4) unawaited(fetchPending());
      },
    );
  }

  Widget _pendientesRetryCard({bool compact = false}) => Container(
        margin: EdgeInsets.fromLTRB(20, compact ? 0 : 8, 20, 14),
        padding: EdgeInsets.all(compact ? 10 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded,
              color: Color(0xFFEA580C), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              pendingError ??
                  'No fue posible cargar las solicitudes pendientes.',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: pendingLoading ? null : () => unawaited(fetchPending()),
            child: const Text('Reintentar'),
          ),
        ]),
      );

  Widget _simSliderBlock({
    required IconData icon,
    required String label,
    required String displayValue,
    required Color color,
    required Widget slider,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: color.withValues(alpha: 0.22), width: 1),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 0.80))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: color.withValues(alpha: 0.25), width: 1),
              ),
              child: Text(displayValue,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
            ),
            child: slider,
          ),
        ]),
      );

  // Campo de fecha (Desde/Hasta) del simulador.
  Widget _simDateField(
      String label, DateTime? value, ValueChanged<DateTime> onPick) {
    final navy = textMain;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: navy)),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          final hoy = DateTime.now();
          final d = await showLightDatePicker(
            screenContext,
            initialDate: value ?? hoy,
            firstDate: DateTime(2015),
            lastDate: DateTime(hoy.year + 5),
          );
          if (d != null) onPick(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: lineCol),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                value == null
                    ? 'dd/mm/aaaa'
                    : '${value.day.toString().padLeft(2, '0')}/'
                        '${value.month.toString().padLeft(2, '0')}/${value.year}',
                style: TextStyle(
                    fontSize: 13, color: value == null ? textSoft : navy),
              ),
            ),
            Icon(Icons.calendar_today_rounded, size: 16, color: textSoft),
          ]),
        ),
      ),
    ]);
  }

  // Fila de resultado del simulador.
  Widget _simResultRow(IconData icon, String label, String valor, Color color,
      {bool destacado = false}) {
    if (destacado) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.04)
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textMain)),
          ),
          Text(valor,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13, color: color.withValues(alpha: 0.80)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: textSoft)),
        ),
        Text(valor,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: textMain)),
      ]),
    );
  }

  void _showCrearDeudorDialog() {
    final formKey = GlobalKey<FormState>();
    String? selectedAsesor;
    final docCtrl = TextEditingController();
    final nombresCtrl = TextEditingController();
    final apellidosCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    bool saving = false;
    bool loadingAdvisors = advisors.isEmpty;
    bool advisorsStarted = false;

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (!advisorsStarted) {
          advisorsStarted = true;
          if (advisors.isEmpty) {
            Future(() async {
              await fetchAdvisors();
              if (ctx.mounted) {
                setS(() => loadingAdvisors = false);
              }
            });
          } else {
            loadingAdvisors = false;
          }
        }

        final advisorOptions = advisors
            .map((advisor) {
              final code = (advisor['codigo_asesor'] ?? advisor['codigo'] ?? '')
                  .toString()
                  .trim();
              final name = [advisor['nombres'], advisor['apellidos']]
                  .where((part) =>
                      part != null && part.toString().trim().isNotEmpty)
                  .map((part) => part.toString().trim())
                  .join(' ');
              final acronym = (advisor['sigla'] ?? '').toString().trim();
              final label = name.isNotEmpty
                  ? name
                  : (advisorNames[acronym.toUpperCase()] ?? acronym);
              return (code: code, label: label);
            })
            .where((advisor) => advisor.code.isNotEmpty)
            .toList();

        Future<void> grabar() async {
          if (!formKey.currentState!.validate()) return;
          setS(() => saving = true);
          try {
            final r = await repository.post('/ajax/registrar_deudor.php', {
              'codigo_asesor': selectedAsesor ?? '',
              'num_documento': docCtrl.text.trim(),
              'nombres': nombresCtrl.text.trim(),
              'apellidos': apellidosCtrl.text.trim(),
              'direccion': direccionCtrl.text.trim(),
              'telefono': telefonoCtrl.text.trim(),
            });
            final bodyLower = r.body.toLowerCase();
            final serverScriptError = bodyLower.contains('fatal error') ||
                bodyLower.contains('warning:') ||
                bodyLower.contains('require_once') ||
                bodyLower.contains('<br') ||
                bodyLower.contains('<b>');
            final ok = r.statusCode == 200 &&
                bodyLower.contains('registrado') &&
                !serverScriptError;

            if (!ok) {
              setS(() => saving = false);
              if (ctx.mounted) {
                await showDialog<void>(
                  context: ctx,
                  builder: (_) => buildResultDialog(
                    serverScriptError
                        ? 'El servicio para registrar deudores no está disponible en este momento. Intenta nuevamente más tarde.'
                        : friendlyError(r.body),
                    false,
                  ),
                );
              }
              return;
            }

            if (ctx.mounted) Navigator.pop(ctx);
            if (isMounted) {
              showDialog(
                context: screenContext,
                builder: (_) => buildResultDialog(
                  'Deudor creado exitosamente',
                  true,
                ),
              );
              repository.invalidateCache('/ajax/listado_json_campos.php');
              final u = repository.user;
              await fetchCredits(u?['codigo_usuario']?.toString() ?? '');
              if (isMounted) refresh(() {});
            }
          } catch (e) {
            setS(() => saving = false);
            if (ctx.mounted) {
              showDialog(
                context: ctx,
                builder: (_) =>
                    buildResultDialog('Error de conexión: $e', false),
              );
            }
          }
        }

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: dialogBg,
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
                      Expanded(
                          child: Text('Crear Deudor',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: textMain))),
                      IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints()),
                    ]),
                    const Divider(height: 20),
                    // Asesor
                    buildDialogRow(
                      'Asesor',
                      buildDialogDropdown<String>(
                        value: selectedAsesor,
                        hint: loadingAdvisors
                            ? 'Cargando asesores...'
                            : '[Seleccione]',
                        items: advisorOptions
                            .map((advisor) => DropdownMenuItem(
                                value: advisor.code,
                                child: Text(advisor.label)))
                            .toList(),
                        onChanged: (v) {
                          if (!loadingAdvisors) {
                            setS(() => selectedAsesor = v);
                          }
                        },
                        validator: (v) => v == null || v.isEmpty
                            ? 'Seleccione un asesor'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildDialogRow(
                        'N° Documento',
                        buildDialogField(docCtrl,
                            required: true, keyboard: TextInputType.number)),
                    const SizedBox(height: 8),
                    buildDialogRow('Nombres',
                        buildDialogField(nombresCtrl, required: true)),
                    const SizedBox(height: 8),
                    buildDialogRow('Apellidos',
                        buildDialogField(apellidosCtrl, required: true)),
                    const SizedBox(height: 8),
                    buildDialogRow(
                        'Dirección', buildDialogField(direccionCtrl)),
                    const SizedBox(height: 8),
                    buildDialogRow(
                        'Telefono',
                        buildDialogField(telefonoCtrl,
                            keyboard: TextInputType.phone)),
                    const SizedBox(height: 20),
                    // Botones
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      appCancelButton(
                          'Cerrar', saving ? null : () => Navigator.pop(ctx)),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: saving ? null : grabar,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: btnPrimary,
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
          final allFiltered = debtors.where((d) {
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

          return AppAnimatedDialog(
            child: Dialog(
              backgroundColor: dialogBg,
              surfaceTintColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
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
                        color: homeNavy,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
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
                          appCloseX(() => Navigator.pop(dCtx)),
                        ],
                      ),
                    ),
                    // Buscador
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setD(() => query = v.trim()),
                        style: TextStyle(color: textMain, fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Nombre del deudor... (${debtors.length} registrados)',
                          hintStyle: const TextStyle(
                              color: Color(0xFFB0BBCC), fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: textSoft, size: 20),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded,
                                      color: textSoft, size: 18),
                                  onPressed: () => setD(() => query = ''),
                                )
                              : null,
                          filled: true,
                          fillColor: inputFill,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: lineCol),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: lineCol),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: homeAccent, width: 1.5),
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
                          style: TextStyle(color: textSoft, fontSize: 11),
                        ),
                      ),
                    ),
                    // Lista
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 40, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 10),
                                  Text('No se encontró ningún deudor',
                                      style: TextStyle(color: textSoft)),
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
                                              color: homeAccent.withValues(
                                                  alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                label.isNotEmpty
                                                    ? label[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: homeAccent,
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
                                              style: TextStyle(
                                                color: textMain,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(0xFFCBD5E1),
                                              size: 18),
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
    String? selectedTiempoC =
        '1'; // 1=Mensual, 2=Quincenal, 4=Semanal, 30=Diario
    String? selectedTipoInt = '1'; // 1=Fijo, 2=Variable
    String? selectedTasa;
    String? selectedFuente;
    String? selectedCuentaDestino;
    DateTime? fechaPrestamo;
    final valorCtrl = TextEditingController();
    final numCuotasCtrl = TextEditingController();
    double totalAPagar = 0;
    // Empieza cargando si no tenemos deudores aún
    bool loadingDeudores = debtors.isEmpty;
    bool listsStarted = false;

    // Opciones estáticas — valor = código numérico que espera el backend
    const tiempoOpciones = [
      ('1', 'Mensual'),
      ('2', 'Quincenal'),
      ('4', 'Semanal'),
      ('30', 'Diario'),
    ];
    const tipoIntOpciones = [
      ('1', 'Interés Fijo'),
      ('2', 'Interés Variable'),
    ];

    // Tasas: devuelve porcentaje como string ('8', '10', etc.)
    List<String> tasaOpciones() {
      if (rates.isNotEmpty) {
        return rates
            .map((t) => (t['tasa'] ??
                    t['porcentaje'] ??
                    t['valor'] ??
                    t['nombre'] ??
                    '')
                .toString()
                .replaceAll('%', '')
                .trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
      return ['0', '8', '10', '15', '17.5', '18', '20'];
    }

    // Fuentes: mismas cuentas que Movimientos (accounts = listar_cuentas_gasto)
    List<(String, String)> fuenteOpciones() {
      if (accounts.isNotEmpty) {
        return accounts
            .map((a) {
              final cod = (a['codigo'] ?? '').toString().trim();
              final nom = (a['nombre'] ?? '').toString().trim();
              return (cod.isNotEmpty ? cod : nom, nom);
            })
            .where((p) => p.$2.isNotEmpty)
            .toList();
      }
      return [];
    }

    // Si el usuario ya marcó una cuenta como destino de Préstamos (en la
    // pantalla de Cuentas), no hace falta pedirla de nuevo en cada crédito.
    bool hayCuentaPrestamosMarcada() =>
        accounts.any((a) => a['es_cuenta_prestamos']?.toString() == '1');

    void recalcTotal(void Function(void Function()) setS) {
      final valor = double.tryParse(
              valorCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
      final cuotas = int.tryParse(numCuotasCtrl.text) ?? 0;
      final tasaStr = (selectedTasa ?? '0').replaceAll('%', '').trim();
      final tasa = double.tryParse(tasaStr) ?? 0;
      final diasPorCuota = {
            '1': 30, // Mensual
            '2': 15, // Quincenal
            '4': 7, // Semanal
            '30': 1, // Diario
          }[selectedTiempoC ?? '1'] ??
          30;
      final totalDias = cuotas * diasPorCuota;
      final tasaDiaria = tasa / 100 / 30;
      final total = valor + (valor * tasaDiaria * totalDias);
      setS(() => totalAPagar = total);
    }

    bool saving = false;

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        // Arranca fetch la primera vez que el builder corre
        if (!listsStarted) {
          listsStarted = true;
          Future(() async {
            // Mostrar datos locales de inmediato (sin red)
            tryBuildDebtorsFromLocal();
            if (ctx.mounted) {
              setS(() => loadingDeudores = debtors.isEmpty);
            }

            // Siempre refrescar desde API para obtener la lista completa.
            // fetchRates() sin condición: las tasas cambian en el servidor
            // (ej. se agrega una nueva) y una carga vieja en memoria no debe
            // impedir que este formulario muestre la lista actual.
            await Future.wait([
              fetchDebtors(),
              fetchRates(),
              if (accounts.isEmpty)
                fetchAccounts(
                    repository.user?['codigo_usuario']?.toString() ?? ''),
            ]);
            if (ctx.mounted) setS(() => loadingDeudores = false);
          });
        }

        Future<void> grabar() async {
          if (!formKey.currentState!.validate()) return;
          if (fechaPrestamo == null) {
            showDialog(
                context: ctx,
                builder: (_) => buildResultDialog(
                    'Seleccione la fecha de préstamo', false));
            return;
          }
          setS(() => saving = true);
          try {
            final r = await repository.post('/ajax/registrar_credito.php', {
              'codigo_deudor': selectedDeudor ?? '',
              'fecha_prestamo':
                  '${fechaPrestamo!.year}-${fechaPrestamo!.month.toString().padLeft(2, '0')}-${fechaPrestamo!.day.toString().padLeft(2, '0')}',
              'valor_prestamo': valorCtrl.text.trim(),
              'tiempo_cuota': selectedTiempoC ?? '',
              'num_cuotas': numCuotasCtrl.text.trim(),
              'tipo_interes': selectedTipoInt ?? '',
              'codigo_tasa_interes_reg': selectedTasa ?? '',
              'fuente_credito_reg': selectedFuente ?? '',
              'cuenta_destino_reg': selectedCuentaDestino ?? '',
              'total_pagar': totalAPagar.toStringAsFixed(0),
            });
            final bodyLower = r.body.toLowerCase();
            final isPhpError = bodyLower.contains('<b>') ||
                bodyLower.contains('fatal error') ||
                bodyLower.contains('warning:') ||
                bodyLower.contains('require_once');
            final ok = r.statusCode == 200 &&
                bodyLower.contains('creado') &&
                !isPhpError;
            if (ctx.mounted) Navigator.pop(ctx);
            if (isMounted) {
              final errMsg = isPhpError
                  ? 'Error del servidor al procesar el crédito. Por favor intente de nuevo.'
                  : friendlyError(r.body);
              showDialog(
                context: screenContext,
                builder: (_) => buildResultDialog(
                  ok ? 'Crédito creado exitosamente' : errMsg,
                  ok,
                ),
              );
              if (ok) {
                repository.invalidateCache('/ajax/listado_json_campos.php');
                final u = repository.user;
                await fetchCredits(u?['codigo_usuario']?.toString() ?? '');
                // El crédito genera movimientos/cambios de saldo automáticos
                // (ver registrar_credito.php): sin esto, Movimientos y el
                // saldo de Cuentas quedaban desactualizados hasta un
                // pull-to-refresh manual en Inicio.
                await refreshAfterMovementChange();
              }
            }
          } catch (e) {
            setS(() => saving = false);
            if (ctx.mounted) {
              showDialog(
                  context: ctx,
                  builder: (_) =>
                      buildResultDialog('Error de conexión: $e', false));
            }
          }
        }

        final tasas = tasaOpciones();
        final fuentes = fuenteOpciones();

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: min(460, MediaQuery.of(ctx).size.width - 32),
                  maxHeight: MediaQuery.of(ctx).size.height * 0.92),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: homeNavy.withValues(alpha: 0.18),
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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            homeNavy,
                            const Color(0xFF1E3A8A),
                            homeAccent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
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
                          child: const Icon(Icons.add_card_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Crear Crédito',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 2),
                              Text('Nuevo préstamo a un deudor',
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
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const SizedBox(height: 4),
                            // Deudor — campo buscable
                            buildDialogRow(
                              'Deudor:',
                              GestureDetector(
                                onTap: loadingDeudores
                                    ? null
                                    : () async {
                                        final result =
                                            await _showDeudorPicker(ctx);
                                        if (result != null) {
                                          setS(() {
                                            selectedDeudor = result['valor'];
                                            deudorLabel =
                                                result['etiqueta'] ?? '';
                                          });
                                        }
                                      },
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: inputFill,
                                    border: Border.all(
                                      color: selectedDeudor != null
                                          ? homeAccent.withValues(alpha: 0.5)
                                          : lineCol,
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
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Color(
                                                              0xFF9CA3AF)),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('Cargando deudores...',
                                                    style: TextStyle(
                                                        color: textSoft,
                                                        fontSize: 13)),
                                              ])
                                            : Text(
                                                deudorLabel.isNotEmpty
                                                    ? deudorLabel
                                                    : 'Toca para buscar deudor...',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: deudorLabel.isNotEmpty
                                                      ? textMain
                                                      : textSoft,
                                                  fontSize: 13,
                                                ),
                                              ),
                                      ),
                                      Icon(
                                        Icons.search_rounded,
                                        size: 18,
                                        color: selectedDeudor != null
                                            ? homeAccent
                                            : textSoft,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Fecha Préstamo
                            buildDialogRow(
                              'Fecha de Préstamo',
                              GestureDetector(
                                onTap: () async {
                                  final d = await showLightDatePicker(
                                    ctx,
                                    initialDate:
                                        fechaPrestamo ?? DateTime.now(),
                                    firstDate: DateTime(2015),
                                    lastDate: DateTime(2035),
                                  );
                                  if (d != null) setS(() => fechaPrestamo = d);
                                },
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                      color: inputFill,
                                      border: Border.all(color: lineCol),
                                      borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.centerLeft,
                                  child: Row(children: [
                                    Expanded(
                                      child: Text(
                                        fechaPrestamo != null
                                            ? '${fechaPrestamo!.day.toString().padLeft(2, '0')}/${fechaPrestamo!.month.toString().padLeft(2, '0')}/${fechaPrestamo!.year}'
                                            : 'dd/mm/aaaa',
                                        style: dialogTextStyle.copyWith(
                                            color: fechaPrestamo != null
                                                ? const Color(0xFF374151)
                                                : const Color(0xFF9CA3AF)),
                                      ),
                                    ),
                                    Icon(Icons.calendar_today_outlined,
                                        size: 16, color: textSoft),
                                  ]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Valor Préstamo
                            buildDialogRow(
                              'Valor Préstamo',
                              TextFormField(
                                controller: valorCtrl,
                                decoration: dialogInputDecoration(),
                                keyboardType: TextInputType.number,
                                style: dialogTextStyle,
                                onChanged: (_) => recalcTotal(setS),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Ingrese el valor'
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tiempo Cuotas
                            buildDialogRow(
                              'Tiempo Cuotas',
                              buildDialogDropdown<String>(
                                value: selectedTiempoC,
                                hint: 'Seleccione',
                                items: tiempoOpciones
                                    .map((o) => DropdownMenuItem(
                                        value: o.$1, child: Text(o.$2)))
                                    .toList(),
                                onChanged: (v) {
                                  setS(() => selectedTiempoC = v);
                                  recalcTotal(setS);
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Número de Cuotas
                            buildDialogRow(
                              'Número de Cuotas',
                              TextFormField(
                                controller: numCuotasCtrl,
                                decoration: dialogInputDecoration(),
                                keyboardType: TextInputType.number,
                                style: dialogTextStyle,
                                onChanged: (_) => recalcTotal(setS),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Ingrese el número de cuotas'
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tipo de Interés
                            buildDialogRow(
                              'Tipo de Interés',
                              buildDialogDropdown<String>(
                                value: selectedTipoInt,
                                hint: 'Seleccione',
                                items: tipoIntOpciones
                                    .map((o) => DropdownMenuItem(
                                        value: o.$1, child: Text(o.$2)))
                                    .toList(),
                                onChanged: (v) =>
                                    setS(() => selectedTipoInt = v),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tasa Interés
                            buildDialogRow(
                              'Tasa interés',
                              buildDialogDropdown<String>(
                                value: tasas.contains(selectedTasa)
                                    ? selectedTasa
                                    : null,
                                hint: '[Seleccione]',
                                items: tasas
                                    .map((t) => DropdownMenuItem(
                                        value: t, child: Text('$t%')))
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
                            buildDialogRow(
                              'Fuente',
                              buildDialogDropdown<String>(
                                value:
                                    fuentes.any((p) => p.$1 == selectedFuente)
                                        ? selectedFuente
                                        : null,
                                hint: '[Seleccione]',
                                items: fuentes
                                    .map((p) => DropdownMenuItem(
                                        value: p.$1,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: sourceColor(p.$2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(p.$2),
                                          ],
                                        )))
                                    .toList(),
                                onChanged: (v) =>
                                    setS(() => selectedFuente = v),
                                validator: (v) =>
                                    v == null ? 'Seleccione una fuente' : null,
                              ),
                            ),
                            // Cuenta destino del total a pagar — solo si el
                            // usuario no marcó ya una cuenta fija en Cuentas.
                            if (!hayCuentaPrestamosMarcada()) ...[
                              const SizedBox(height: 8),
                              buildDialogRow(
                                'Cuenta destino',
                                buildDialogDropdown<String>(
                                  value: fuentes.any(
                                          (p) => p.$1 == selectedCuentaDestino)
                                      ? selectedCuentaDestino
                                      : null,
                                  hint: '[Seleccione]',
                                  items: fuentes
                                      .map((p) => DropdownMenuItem(
                                          value: p.$1,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: sourceColor(p.$2),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(p.$2),
                                            ],
                                          )))
                                      .toList(),
                                  onChanged: (v) =>
                                      setS(() => selectedCuentaDestino = v),
                                  validator: (v) => v == null
                                      ? 'Seleccione la cuenta destino'
                                      : null,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Total a Pagar (read-only calculado)
                            buildDialogRow(
                              'Total a Pagar',
                              Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                    color: inputFill,
                                    border: Border.all(color: lineCol),
                                    borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  totalAPagar > 0 ? formatCop(totalAPagar) : '',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: textMain,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Botones
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  appCancelButton('Cerrar',
                                      saving ? null : () => Navigator.pop(ctx)),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                      onPressed: saving ? null : grabar,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: btnPrimary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      child: saving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Text('Grabar')),
                                ]),
                          ]),
                        ),
                      ),
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

  // ── Diálogo de resultado (éxito / error) ─────────────────────────
  Widget buildResultDialog(String msg, bool ok,
          {String? title, IconData? icon}) =>
      AppResultDialog(message: msg, success: ok, title: title, icon: icon);

  String friendlyError(dynamic e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('fatal error') ||
        lower.contains('warning:') ||
        lower.contains('require_once') ||
        lower.contains('<br') ||
        lower.contains('<b>')) {
      return 'El servidor no pudo procesar la solicitud. Por favor intenta de nuevo más tarde.';
    }
    if (RegExp(r'\b(400|401|403|404|500|502|503|504)\b').hasMatch(raw)) {
      return 'No se pudo completar la operación. Por favor intenta de nuevo.';
    }
    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network')) {
      return 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
    }
    if (lower.contains('timeout')) {
      return 'La operación tardó demasiado. Por favor intenta de nuevo.';
    }
    if (raw.isEmpty || raw.length > 300) {
      return 'Ocurrió un error inesperado. Por favor intenta de nuevo.';
    }
    return raw;
  }

  void showResult(bool ok, String msg) {
    if (!isMounted) return;
    showDialog(
        context: screenContext, builder: (_) => buildResultDialog(msg, ok));
  }

  // ── Helpers de formulario ────────────────────────────────────────
  Widget _creditoCard(Map<String, dynamic> c, [int index = 0]) {
    final cod = c['cod']?.toString() ?? '';
    final asesor = (() {
      final nombre = (c['asesor'] ?? '').toString().trim();
      final aCod = (c['asesor_cod'] ?? '').toString().trim();
      final sigla = creditAdvisorInitials(aCod).trim();
      final resuelto = sigla.isNotEmpty ? advisorName(sigla) : nombre;
      // Si no hay nombre real (solo quedó el código numérico del asesor),
      // no mostrar un dato críptico como "· 1".
      return RegExp(r'^[0-9]*$').hasMatch(resuelto) ? '' : resuelto;
    })();
    final nombre = (c['cliente'] ?? 'Cliente').toString();
    final monto = numberValue(c['valor_prestamo'] ?? 0);
    final totalPagar = numberValue(c['total_pagar'] ?? 0);
    final numCuotas = c['num_cuotas']?.toString() ?? '';
    final tipo = (c['tipo'] ?? '').toString();
    final pagado = numberValue(c['total_pagado'] ?? 0);
    final pendiente = numberValue(c['saldo_pendiente'] ?? 0);
    final fecha = (c['fecha_prestamo'] ?? '').toString();
    final proxima = (c['proxima_fecha'] ?? '').toString();
    final estado = (c['estado'] ?? 'Activo').toString();
    final activo = estado.toLowerCase().contains('activ');
    final vencido = isCreditoVencido(c);

    final cardKey = cod.isNotEmpty ? cod : nombre;
    final expanded = expandedCredits.contains(cardKey);

    // Todas las cards de "Aprobados" usan el mismo verde de la sección — la
    // mora ya no se marca tiñendo la card entera de rojo (se perdía la
    // identidad visual del tab); se señala en el LED/etiqueta de estado y en
    // el recuadro de "PRÓX. CUOTA" en su lugar.
    const Color accent = Color(0xFF16A34A);
    final Color borderColor =
        isDarkTheme ? const Color(0xFF1E5A3C) : const Color(0xFF86EFAC);

    final initials = nombre
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    final progress =
        totalPagar > 0 ? (pagado / totalPagar).clamp(0.0, 1.0) : 0.0;

    final entryInterval = Interval(
      (index * 0.08).clamp(0.0, 0.45),
      (index * 0.08 + 0.70).clamp(0.5, 1.0),
      curve: Curves.easeOutBack,
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey(cardKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: entryInterval,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - v)),
          child: RepaintBoundary(child: child),
        ),
      ),
      child: GestureDetector(
        onTap: () => refresh(() => expanded
            ? expandedCredits.remove(cardKey)
            : expandedCredits.add(cardKey)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: expanded ? 0.28 : 0.18),
                blurRadius: expanded ? 26 : 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Banner de estado (color sólido, siempre visible) ────
              ClipRect(
                child: Stack(children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: const BoxDecoration(
                      // Mismo par exacto del tab "Aprobados" (no un lerp
                      // automático desde accent) — el lerp daba un verde más
                      // apagado que el verde oscuro→esmeralda vivo del tab.
                      gradient: LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1.4),
                        ),
                        child: Center(
                            child: Text(initials,
                                style: const TextStyle(
                                    color: Colors.white,
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            if (asesor.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.badge_outlined,
                                          size: 11, color: Colors.white),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(asesor,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white)),
                                      ),
                                    ]),
                              ),
                          ])),
                      const SizedBox(width: 8),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              if (cod.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('#$cod',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Builder(builder: (_) {
                                // Chip siempre en fondo blanco sólido con LED
                                // y texto en el color real del estado: verde
                                // Activo, rojo En mora, azul Pagado (antes
                                // Pagado y Activo compartían el mismo verde y
                                // no se distinguían de un vistazo).
                                final estadoColor = (activo && vencido)
                                    ? const Color(0xFFDC2626)
                                    : !activo
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF16A34A);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    // cardBg (no blanco fijo) — en modo
                                    // oscuro un fondo blanco puro no combina
                                    // con el resto de la UI.
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: estadoColor, width: 1),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _PulsingDot(color: estadoColor),
                                        const SizedBox(width: 5),
                                        Text(
                                            activo && vencido
                                                ? 'Atrasado'
                                                : estado,
                                            style: TextStyle(
                                                color: estadoColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700)),
                                      ]),
                                );
                              }),
                            ]),
                            const SizedBox(height: 6),
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 18),
                            ),
                          ]),
                    ]),
                  ),
                  // Glow decorativo
                  Positioned(
                    right: -20,
                    top: -20,
                    child: IgnorePointer(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                  // Barrido de luz animado (shimmer)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: shimmer,
                        builder: (_, __) => Transform.translate(
                          offset: Offset((shimmer.value * 2 - 1) * 220, 0),
                          child: Transform.rotate(
                            angle: 0.42,
                            child: Container(
                              width: 34,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Pendiente + Próxima cuota ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                child: Row(children: [
                  Expanded(
                    child: Builder(builder: (_) {
                      // Saldo pendiente ≠ atrasado: un crédito al día puede
                      // seguir teniendo saldo por pagar, así que este
                      // recuadro usa el amarillo de la tab "Pendientes" (no
                      // rojo, que ya se reserva para "Atrasado" en el chip de
                      // estado y en "PRÓX. CUOTA"). En $0, usa el mismo azul
                      // del chip "Pagado", no verde.
                      final boxColor = pendiente > 0
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF2563EB);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: boxColor
                              .withValues(alpha: isDarkTheme ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: boxColor.withValues(alpha: 0.30)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                // Par fijo de dos tonos, igual que el resto
                                // de estados (amarillo/verde/rojo) — un lerp
                                // automático se veía más plano que un
                                // gradiente de marca real.
                                colors: pendiente > 0
                                    ? const [
                                        Color(0xFF92400E),
                                        Color(0xFFF59E0B)
                                      ]
                                    : const [
                                        Color(0xFF1D4ED8),
                                        Color(0xFF3B82F6)
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: boxColor.withValues(alpha: 0.40),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.attach_money_rounded,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PENDIENTE',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: textSoft,
                                          letterSpacing: 0.5,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey('pend_${cardKey}_$pendiente'),
                                    tween: Tween(begin: 0.0, end: pendiente),
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, animatedPendiente, __) => Text(
                                        formatCop(animatedPendiente),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: boxColor)),
                                  ),
                                ]),
                          ),
                        ]),
                      );
                    }),
                  ),
                  if (proxima.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(builder: (_) {
                        final boxColor =
                            vencido ? const Color(0xFFDC2626) : accent;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: boxColor
                                .withValues(alpha: isDarkTheme ? 0.12 : 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: boxColor.withValues(alpha: 0.30)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  // Mismo par exacto del tab "Aprobados" (o
                                  // "Rechazadas" si está vencido) — un lerp
                                  // automático daba tonos más apagados que
                                  // los headers reales de esas secciones.
                                  colors: vencido
                                      ? const [
                                          Color(0xFF7F1D1D),
                                          Color(0xFFDC2626)
                                        ]
                                      : const [
                                          Color(0xFF064E3B),
                                          Color(0xFF10B981)
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: boxColor.withValues(alpha: 0.40),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                  vencido
                                      ? Icons.warning_amber_rounded
                                      : Icons.event_rounded,
                                  color: Colors.white,
                                  size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('PRÓX. CUOTA',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: textSoft,
                                            letterSpacing: 0.5,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(proxima,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: boxColor)),
                                  ]),
                            ),
                          ]),
                        );
                      }),
                    ),
                  ],
                ]),
              ),

              // ── Barra de progreso ─────────────────────────────────
              if (totalPagar > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 14, 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  '${(progress * 100).toStringAsFixed(0)}% pagado',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: progress >= 1.0
                                          ? const Color(0xFF16A34A)
                                          : textSoft,
                                      fontWeight: FontWeight.w600)),
                              if (numCuotas.isNotEmpty || tipo.isNotEmpty)
                                Text(
                                    [
                                      if (numCuotas.isNotEmpty)
                                        '$numCuotas cuotas',
                                      if (tipo.isNotEmpty) tipo
                                    ].join(' · '),
                                    style: TextStyle(
                                        fontSize: 9, color: textSoft)),
                            ]),
                        const SizedBox(height: 5),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) {
                            // Barra por escala de avance, con los mismos
                            // gradientes exactos de las tabs: 0-33% rojo
                            // (Rechazadas), 34-66% amarillo (Pendientes),
                            // 67-100% verde (Aprobados).
                            final List<Color> progressColors = progress <= 0.33
                                ? const [Color(0xFF7F1D1D), Color(0xFFDC2626)]
                                : progress <= 0.66
                                    ? const [
                                        Color(0xFF92400E),
                                        Color(0xFFF59E0B)
                                      ]
                                    : const [
                                        Color(0xFF064E3B),
                                        Color(0xFF10B981)
                                      ];
                            final Color glowColor = progressColors.last;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(children: [
                                Container(
                                  height: 7,
                                  color: lineCol,
                                ),
                                FractionallySizedBox(
                                  widthFactor: v,
                                  child: Container(
                                    height: 7,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: progressColors),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              glowColor.withValues(alpha: 0.55),
                                          blurRadius: 7,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
                      ]),
                ),

              // ── Detalle expandido ─────────────────────────────────
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Divider(height: 1, color: lineCol),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(children: [
                          Expanded(
                              child: _staggerIn(
                                  expanded,
                                  0,
                                  _statMini(
                                      Icons.account_balance_wallet_outlined,
                                      'Crédito',
                                      formatCop(monto),
                                      isDarkTheme
                                          ? const Color(0xFF9AA8FF)
                                          : homeNavy))),
                          const SizedBox(width: 6),
                          Expanded(
                              child: _staggerIn(
                                  expanded,
                                  1,
                                  _statMini(
                                      Icons.payments_outlined,
                                      'A Pagar',
                                      formatCop(totalPagar),
                                      const Color(0xFF4F46E5)))),
                          const SizedBox(width: 6),
                          Expanded(
                              child: _staggerIn(
                                  expanded,
                                  2,
                                  _statMini(
                                      Icons.check_circle_outline_rounded,
                                      'Pagado',
                                      formatCop(pagado),
                                      const Color(0xFF16A34A)))),
                          const SizedBox(width: 6),
                          Expanded(
                              child: _staggerIn(
                                  expanded,
                                  3,
                                  _statMini(
                                      Icons.hourglass_bottom_rounded,
                                      'Pendiente',
                                      formatCop(pendiente),
                                      const Color(0xFFDC2626)))),
                        ]),
                      ),
                      if (fecha.isNotEmpty ||
                          tipo.isNotEmpty ||
                          numCuotas.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Wrap(spacing: 6, runSpacing: 6, children: [
                            if (fecha.isNotEmpty)
                              _staggerIn(
                                  expanded,
                                  4,
                                  _infoBadgeGrad(Icons.calendar_today_rounded,
                                      fecha, const Color(0xFF2563EB))),
                            if (tipo.isNotEmpty)
                              _staggerIn(
                                  expanded,
                                  5,
                                  _infoBadgeGrad(Icons.repeat_rounded, tipo,
                                      const Color(0xFF7C3AED))),
                            if (numCuotas.isNotEmpty)
                              _staggerIn(
                                  expanded,
                                  6,
                                  _infoBadgeGrad(
                                      Icons.format_list_numbered_rounded,
                                      '$numCuotas cuotas',
                                      const Color(0xFF0D9488))),
                          ]),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Row(children: [
                          Expanded(
                              child: _staggerIn(
                                  expanded,
                                  7,
                                  _miniActionBtn(
                                      Icons.list_alt_rounded,
                                      'Cuotas',
                                      isDarkTheme
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF1D4ED8),
                                      () => _showCuotasDialog(c)))),
                          const SizedBox(width: 6),
                          if (activo)
                            Expanded(
                                child: _staggerIn(
                                    expanded,
                                    8,
                                    _miniActionBtn(
                                        Icons.request_quote_outlined,
                                        'Liquidar',
                                        const Color(0xFF7C3AED),
                                        () => _showLiquidarCreditoDialog(c)))),
                          if (activo) const SizedBox(width: 6),
                          Expanded(
                              child: _staggerIn(
                                  expanded,
                                  9,
                                  _miniActionBtn(
                                      Icons.verified_outlined,
                                      'Paz y Salvo',
                                      const Color(0xFF0D9488),
                                      () => _showPazYSalvoDialog(c)))),
                          const SizedBox(width: 6),
                          _staggerIn(
                              expanded,
                              10,
                              _miniIconBtn(
                                  Icons.delete_outline_rounded,
                                  const Color(0xFFDC2626),
                                  () => _confirmarEliminarCredito(c))),
                        ]),
                      ),
                    ]),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ]), // closes Column children
          ), // closes ClipRRect
        ), // closes AnimatedContainer
      ), // closes GestureDetector
    ); // closes TweenAnimationBuilder
  }

  Widget _creditHeaderBadge(
          IconData icon, String count, String label, Color color) =>
      AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(color, Colors.white, 0.10)!
                      .withValues(alpha: 0.55 + 0.20 * shimmer.value),
                  color.withValues(alpha: 0.20),
                ],
              ),
              border: Border.all(
                  color: color.withValues(alpha: 0.55 + 0.20 * shimmer.value),
                  width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.30 + 0.18 * shimmer.value),
                  blurRadius: 14 + 6 * shimmer.value,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset((shimmer.value * 2 - 1) * 70, 0),
                  child: Transform.rotate(
                    angle: 0.4,
                    child: Container(
                      width: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.30),
                          Colors.white.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 12, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(count,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ]),
                    const SizedBox(height: 3),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.88))),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _creditsTotalStat({
    required IconData icon,
    required String label,
    required double value,
    required Color color,
    bool loading = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.32),
                    color.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: 0.40)),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ),
          ]),
          const SizedBox(height: 8),
          // Mientras creditsDataLoaded sigue en false el valor real aún no
          // llegó del servidor — mostrar "$0" en ese momento se confunde con
          // un total que ya cargó y de verdad es cero, así que se muestra un
          // placeholder shimmer hasta que el dato definitivo esté listo.
          if (loading)
            AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) => Container(
                width: 74,
                height: 19,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.14 + 0.08 * shimmer.value),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )
          else if (!balanceVisible)
            const Text('• • • •',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3))
          else
            TweenAnimationBuilder<double>(
              key: ValueKey('credits_total_${label}_$value'),
              tween: Tween(begin: 0.0, end: value),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, animatedValue, __) => Text(formatCop(animatedValue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
            ),
        ],
      );

  Widget _statMini(IconData icon, String label, String value, Color color) {
    final topColor = isDarkTheme
        ? Color.lerp(color, Colors.white, 0.16) ?? color
        : Color.lerp(color, Colors.white, 0.72) ?? color;
    final bottomColor = isDarkTheme
        ? Color.lerp(color, const Color(0xFF050816), 0.46) ?? color
        : Color.lerp(color, Colors.white, 0.88) ?? color;
    final labelColor = isDarkTheme
        ? Color.lerp(color, Colors.white, 0.30) ?? color
        : Color.lerp(color, Colors.black, 0.08) ?? color;
    final valueColor = isDarkTheme
        ? Color.lerp(color, Colors.white, 0.18) ?? color
        : Color.lerp(color, Colors.black, 0.10) ?? color;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkTheme
                ? [
                    topColor.withValues(alpha: 0.42),
                    color.withValues(alpha: 0.22),
                    bottomColor.withValues(alpha: 0.32),
                  ]
                : [
                    topColor.withValues(alpha: 0.98),
                    color.withValues(alpha: 0.20),
                    bottomColor.withValues(alpha: 1.0),
                  ],
            stops: const [0.0, 0.52, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: isDarkTheme ? 0.38 : 0.30),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDarkTheme ? 0.18 : 0.13),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 10, color: valueColor.withValues(alpha: 0.85)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 8.5,
                      color: labelColor.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: valueColor)),
        ]));
  }

  // Anima la entrada de un widget del panel expandido con un pequeño
  // stagger por índice (fade + scale), reiniciando cada vez que se abre.
  Widget _staggerIn(bool trigger, int index, Widget child) =>
      TweenAnimationBuilder<double>(
        key: ValueKey('stagger_${trigger}_$index'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 380),
        curve: Interval(
          (index * 0.05).clamp(0.0, 0.6),
          (index * 0.05 + 0.5).clamp(0.5, 1.0),
          curve: Curves.easeOutBack,
        ),
        builder: (_, t, __) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.85 + 0.15 * t,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - t)),
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      );

  // Chip con gradiente (usado en las cards de Pendientes/Rechazadas)
  Widget _infoBadgeGrad(IconData icon, String text, Color color) {
    return Container(
        padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: isDarkTheme ? 0.22 : 0.14),
              color.withValues(alpha: isDarkTheme ? 0.10 : 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(color, Colors.white, 0.18)!,
                  color,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 10.5,
                  color: textMain,
                  fontWeight: FontWeight.w700)),
        ]));
  }

  Widget _miniActionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    final colorTop =
        Color.lerp(color, Colors.white, isDarkTheme ? 0.20 : 0.12) ?? color;
    final colorDark =
        Color.lerp(color, Colors.black, isDarkTheme ? 0.30 : 0.22) ?? color;
    return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [colorTop, color, colorDark],
                  stops: const [0.0, 0.46, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    Colors.white.withValues(alpha: isDarkTheme ? 0.18 : 0.14),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: isDarkTheme ? 0.40 : 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
                BoxShadow(
                    color: colorDark.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Stack(children: [
              Positioned(
                left: -12,
                top: -18,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Center(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ]),
              ),
            ]),
          ),
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

  Widget _pendienteCard(Map<String, dynamic> p, [int index = 0]) {
    final cod = (p['codigo_solicitud'] ?? p['cod'] ?? '').toString();
    final solicitante = ([p['nombres'], p['apellidos']]
            .where((x) => x != null && x.toString().isNotEmpty)
            .join(' '))
        .trim();
    final doc = (p['num_documento'] ?? p['documento'] ?? '').toString();
    final email = (p['email'] ?? p['correo'] ?? '').toString();
    final tel = (p['telefono'] ?? '').toString();
    final valor =
        numberValue(p['valor_solicitado'] ?? p['valor_prestamo'] ?? 0);
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
    final nombreAsesorRaw = (p['nombre_asesor'] ?? '').toString().trim();
    final asesorSigla = creditAdvisorInitials(codigoAsesor).trim();
    final nombreAsesor = nombreAsesorRaw.isNotEmpty
        ? nombreAsesorRaw
        : (asesorSigla.isNotEmpty ? advisorName(asesorSigla) : codigoAsesor);
    final estadoCod = int.tryParse(p['codigo_estado']?.toString() ?? '0') ?? 0;

    // Todas las cards de "Pendientes" usan el mismo amarillo de la sección,
    // tenga o no asesor asignado — esa distinción ahora se marca solo en el
    // chip de estado (azul SAF para "Con Asesor"), no tiñendo la card entera.
    final tieneAsesor = codigoAsesor.isNotEmpty;
    final rechazado = estadoCod == 3;
    final cardBorder = rechazado
        ? (isDarkTheme ? const Color(0xFF6B2837) : const Color(0xFFEF9A9A))
        : (isDarkTheme ? const Color(0xFF6B4A1E) : const Color(0xFFFDE68A));

    final accentColor =
        rechazado ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
    // El monto "SOLICITADO" se pinta con accentColor sobre un fondo teñido
    // con ese mismo color (ver container más abajo) — en modo oscuro el
    // índigo sobre índigo oscuro casi no se distinguía. Aquí sí se aclara
    // solo para texto, sin tocar accentColor (bordes/ícono/banner ya tenían
    // buen contraste).
    final amountTextColor = isDarkTheme
        ? Color.lerp(accentColor, Colors.white, 0.35)!
        : accentColor;

    final estadoLabel = rechazado
        ? 'Rechazado'
        : tieneAsesor
            ? 'Con Asesor'
            : 'Pendiente';

    final initials = solicitante.isNotEmpty
        ? solicitante
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase()
        : '?';

    final cardKey = cod.isNotEmpty ? cod : '$solicitante|$doc';
    final expanded = expandedPending.contains(cardKey);

    final entryInterval = Interval(
      (index * 0.08).clamp(0.0, 0.45),
      (index * 0.08 + 0.70).clamp(0.5, 1.0),
      curve: Curves.easeOutBack,
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey(cardKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: entryInterval,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - v)),
          child: RepaintBoundary(child: child),
        ),
      ),
      child: GestureDetector(
        onTap: () => refresh(() => expanded
            ? expandedPending.remove(cardKey)
            : expandedPending.add(cardKey)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: expanded ? 0.26 : 0.16),
                blurRadius: expanded ? 24 : 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Banner de estado (color sólido) ────────────────
              ClipRect(
                child: Stack(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        // Todas las cards no rechazadas usan el mismo par
                        // exacto de colores del tab "Pendientes" (no un lerp
                        // automático desde accentColor), para que el amarillo
                        // calce siempre, tengan o no asesor asignado.
                        colors: !rechazado
                            ? const [Color(0xFF92400E), Color(0xFFF59E0B)]
                            : [
                                Color.lerp(accentColor, Colors.white, 0.14) ??
                                    accentColor,
                                accentColor,
                                Color.lerp(accentColor, Colors.black, 0.24) ??
                                    accentColor,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1.4),
                        ),
                        child: Center(
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  solicitante.isNotEmpty
                                      ? solicitante
                                      : 'Sin nombre',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: Colors.white)),
                              const SizedBox(height: 2),
                              if (doc.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Doc: $doc',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ),
                            ]),
                      ),
                      const SizedBox(width: 8),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (cod.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('#$cod',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Builder(builder: (_) {
                          // Mismo patrón "chip blanco + acento" que el resto
                          // de estados de la app — un chip con gradiente de
                          // color saturado (probado antes) chocaba fuerte
                          // contra el header naranja/rojo.
                          final chipColor = (tieneAsesor && !rechazado)
                              ? const Color(0xFF2563EB)
                              : accentColor;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              // cardBg (no blanco fijo): en modo oscuro un
                              // fondo blanco puro rompía con el resto de la
                              // UI, aunque el contraste contra el header de
                              // color siga funcionando igual.
                              color: cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: chipColor, width: 1),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PulsingDot(color: chipColor),
                                  const SizedBox(width: 5),
                                  Text(estadoLabel,
                                      style: TextStyle(
                                          color: chipColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ]),
                          );
                        }),
                      ]),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 18),
                      ),
                    ]),
                  ),
                  Positioned(
                    right: -20,
                    top: -20,
                    child: IgnorePointer(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: shimmer,
                        builder: (_, __) => Transform.translate(
                          offset: Offset((shimmer.value * 2 - 1) * 220, 0),
                          child: Transform.rotate(
                            angle: 0.42,
                            child: Container(
                              width: 34,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withValues(
                                  alpha: isDarkTheme ? 0.20 : 0.12),
                              accentColor.withValues(
                                  alpha: isDarkTheme ? 0.08 : 0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.30)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.lerp(accentColor, Colors.white, 0.20)!,
                                  accentColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.40),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.request_quote_rounded,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SOLICITADO',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: textSoft,
                                        letterSpacing: 0.5,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                TweenAnimationBuilder<double>(
                                  key: ValueKey('sol_${cardKey}_$valor'),
                                  tween: Tween(begin: 0.0, end: valor),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, __) => Text(formatCop(v),
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                          color: amountTextColor)),
                                ),
                              ]),
                        ]),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 6, children: [
                                if (tel.isNotEmpty)
                                  _infoBadgeGrad(Icons.phone_outlined, tel,
                                      const Color(0xFF3B82F6)),
                                if (email.isNotEmpty)
                                  _infoBadgeGrad(Icons.email_outlined, email,
                                      const Color(0xFF8B5CF6)),
                                if (tipo.isNotEmpty || numCuotas.isNotEmpty)
                                  _infoBadgeGrad(
                                      Icons.repeat_rounded,
                                      [
                                        if (numCuotas.isNotEmpty)
                                          '$numCuotas cuotas',
                                        if (tipo.isNotEmpty) tipo,
                                      ].join(' · '),
                                      const Color(0xFF14B8A6)),
                                if (interes.isNotEmpty)
                                  _infoBadgeGrad(Icons.percent_rounded,
                                      '$interes%', const Color(0xFFF59E0B)),
                                if (nombreAsesor.isNotEmpty)
                                  _infoBadgeGrad(Icons.person_outline_rounded,
                                      nombreAsesor, const Color(0xFF16A34A)),
                              ]),
                              const SizedBox(height: 10),
                              Container(height: 1, color: cardBorder),
                              const SizedBox(height: 10),
                              IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (tieneAsesor && !rechazado)
                                        Expanded(
                                          child: _miniActionBtn(
                                              Icons.cancel_outlined,
                                              'Rechazar',
                                              const Color(0xFFDC2626),
                                              () => _rechazarSolicitud(p)),
                                        )
                                      else if (rechazado)
                                        Expanded(
                                          child: _miniActionBtn(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              'Aprobar',
                                              const Color(0xFF16A34A),
                                              () => _aprobarSolicitud(p)),
                                        )
                                      else ...[
                                        Expanded(
                                          child: _miniActionBtn(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              'Aprobar',
                                              const Color(0xFF16A34A),
                                              () => _aprobarSolicitud(p)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _miniActionBtn(
                                              Icons.cancel_outlined,
                                              'Rechazar',
                                              const Color(0xFFDC2626),
                                              () => _rechazarSolicitud(p)),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      _miniIconBtn(Icons.edit_rounded, homeNavy,
                                          () => _showEditarSolicitudDialog(p)),
                                      if (rechazado) ...[
                                        const SizedBox(width: 8),
                                        _miniIconBtn(
                                            Icons.delete_rounded,
                                            const Color(0xFFDC2626),
                                            () => _confirmarEliminarSolicitud(
                                                p)),
                                      ],
                                    ]),
                              ),
                            ]),
                        crossFadeState: expanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),
                    ]),
              ),
            ]),
          ), // closes ClipRRect
        ), // closes AnimatedContainer
      ), // closes GestureDetector
    ); // closes TweenAnimationBuilder
  }

  // Igual criterio que gestion_usuarios.php: 'foto' (subida real) tiene
  // prioridad sobre 'imagen' (asignada al crear el asesor, a veces solo el
  // isotipo genérico de SAF) — cualquiera de las dos puede venir vacía.
  String _advisorPhotoUrl(Map<String, dynamic> a) {
    for (final k in ['foto', 'imagen']) {
      final raw = (a[k] ?? '').toString().trim();
      if (raw.isNotEmpty && !isNoPhotoValue(raw)) {
        return raw.startsWith('http')
            ? raw
            : 'https://www.jorgemario.co/ext/saf/img/icons/$raw';
      }
    }
    return '';
  }

  Widget _advisorAvatar(Map<String, dynamic> a, String nombre) {
    final photoUrl = _advisorPhotoUrl(a);
    final initials = nombre.trim().isNotEmpty
        ? nombre
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase()
        : '?';
    final fallback = Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: homeAccent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
    );
    if (photoUrl.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        photoUrl,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
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

    // Tipo de interés (1=Fijo, 2=Variable)
    final tipoIntRaw = (p['tipo_interes'] ?? '').toString().trim();
    String? selectedTipoInt = tipoIntRaw.isNotEmpty ? tipoIntRaw : '1';
    const tipoIntOpciones = [
      ('1', 'Interés Fijo'),
      ('2', 'Interés Variable'),
    ];

    // Tasa de interés (porcentaje, ej. '6.6')
    String? selectedTasa = (p['tasa_interes'] ?? p['interes'] ?? '')
        .toString()
        .replaceAll('%', '')
        .trim();
    if (selectedTasa.isEmpty) selectedTasa = null;

    List<String> tasaOpciones() {
      if (rates.isNotEmpty) {
        return rates
            .map((t) => (t['tasa'] ??
                    t['porcentaje'] ??
                    t['valor'] ??
                    t['nombre'] ??
                    '')
                .toString()
                .replaceAll('%', '')
                .trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
      return ['0', '8', '10', '15', '17.5', '18', '20'];
    }

    bool saving = false;
    bool listsLoaded = sources.isNotEmpty;

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (!listsLoaded) {
          listsLoaded = true;
          Future(() async {
            await Future.wait([
              if (sources.isEmpty) fetchSources(),
              if (advisors.isEmpty) fetchAdvisors(),
              fetchRates(),
            ]);
            if (ctx.mounted) setS(() {});
          });
        }

        // ── Proyección de cuotas (recalcula con cada cambio) ──
        List<Map<String, dynamic>> cuotasProyectadas() {
          final valor = double.tryParse(
                  valorCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ??
              0;
          final cuotas = int.tryParse(cuotasCtrl.text) ?? 0;
          if (valor <= 0 || cuotas <= 0) return [];
          final tasa = double.tryParse(
                  (selectedTasa ?? '0').replaceAll('%', '').trim()) ??
              0;
          final tiempoCod = tiempoMap[selectedTiempo] ?? '1';
          final diasPorCuota = {
                '1': 30,
                '2': 15,
                '4': 7,
                '30': 1,
              }[tiempoCod] ??
              30;
          final totalDias = cuotas * diasPorCuota;
          final tasaDiaria = tasa / 100 / 30;
          final total = valor + (valor * tasaDiaria * totalDias);
          final valorCuota = total / cuotas;
          final hoy = DateTime.now();
          return List.generate(cuotas, (i) {
            final fecha = hoy.add(Duration(days: diasPorCuota * (i + 1)));
            return {'fecha': fecha, 'valor': valorCuota};
          });
        }

        // Fuentes: mismas cuentas que Movimientos
        List<(String, String)> fuenteOpciones() {
          if (accounts.isNotEmpty) {
            return accounts
                .map((a) {
                  final cod = (a['codigo'] ?? '').toString().trim();
                  final nom = (a['nombre'] ?? '').toString().trim();
                  return (cod.isNotEmpty ? cod : nom, nom);
                })
                .where((p) => p.$2.isNotEmpty)
                .toList();
          }
          return [];
        }

        Future<void> grabar() async {
          if (!formKey.currentState!.validate()) return;
          setS(() => saving = true);
          try {
            final tiempoCod = tiempoMap[selectedTiempo] ?? selectedTiempo ?? '';
            final r = await repository.post('/ajax/actualizar_registro.php', {
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
              'tipo_interes': selectedTipoInt ?? '',
              'tasa_interes': selectedTasa ?? '',
            });
            final ok =
                r.statusCode == 200 && !r.body.toLowerCase().contains('error');
            if (ctx.mounted) Navigator.pop(ctx);
            if (isMounted) {
              showDialog(
                  context: screenContext,
                  builder: (_) => buildResultDialog(
                      ok
                          ? 'Solicitud actualizada correctamente'
                          : r.body.trim(),
                      ok));
              if (ok) {
                await fetchPending();
                if (isMounted) refresh(() {});
              }
            }
          } catch (e) {
            setS(() => saving = false);
            if (ctx.mounted) {
              showDialog(
                  context: ctx,
                  builder: (_) => buildResultDialog('Error: $e', false));
            }
          }
        }

        // Helpers de estilo
        final indigo =
            isDarkTheme ? const Color(0xFF6366F1) : const Color(0xFF0D1B4B);
        final accentBlue =
            isDarkTheme ? const Color(0xFF4F46E5) : const Color(0xFF1A3170);
        final borderCol = lineCol;
        final hintCol = textSoft;
        final bgField = cardBgAlt;

        InputDecoration fieldDeco(String label, IconData icon) =>
            InputDecoration(
              labelText: label,
              labelStyle: TextStyle(fontSize: 12, color: hintCol),
              prefixIcon: Icon(icon, size: 16, color: hintCol),
              filled: true,
              fillColor: bgField,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderCol)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accentBlue, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEF4444))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            );

        Widget field(String label, TextEditingController ctrl, IconData icon,
                {TextInputType? kb,
                bool required = false,
                ValueChanged<String>? onChanged}) =>
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: ctrl,
                  keyboardType: kb,
                  decoration: fieldDeco(label, icon),
                  style: TextStyle(fontSize: 13, color: textMain),
                  onChanged: onChanged,
                  validator: required
                      ? (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null
                      : null,
                ));

        Widget dropdown<ValueType>(
                String label,
                IconData icon,
                ValueType? val,
                List<DropdownMenuItem<ValueType>> items,
                ValueChanged<ValueType?> onChange) =>
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<ValueType>(
                  initialValue: val,
                  items: items,
                  onChanged: onChange,
                  decoration: fieldDeco(label, icon),
                  dropdownColor: dialogBg,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: hintCol),
                  style: TextStyle(fontSize: 13, color: textMain),
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
                  style: TextStyle(
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

        Widget cuotasTable() {
          final cuotas = cuotasProyectadas();
          if (cuotas.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Container(
                color: indigo,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: const Row(children: [
                  Expanded(
                      child: Text('Fecha',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12))),
                  Expanded(
                      child: Text('Valor',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12))),
                ]),
              ),
              ...List.generate(cuotas.length, (i) {
                final fecha = cuotas[i]['fecha'] as DateTime;
                final valor = cuotas[i]['valor'] as double;
                final fechaStr =
                    '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
                return Container(
                  color: i.isOdd ? const Color(0xFFF8F9FC) : Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(children: [
                    Expanded(
                        child: Text(fechaStr,
                            style: TextStyle(fontSize: 12.5, color: textMain))),
                    Expanded(
                        child: Text(formatCop(valor),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textMain))),
                  ]),
                );
              }),
            ]),
          );
        }

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: dialogBg,
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
                                    color:
                                        Colors.white.withValues(alpha: 0.75))),
                          ])),
                      appCloseX(() => Navigator.pop(ctx)),
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
                                      value: null,
                                      child: Text('[Sin asignar]')),
                                  ...advisors.map((a) {
                                    final sigla =
                                        (a['sigla'] ?? a['codigo_asesor'] ?? '')
                                            .toString();
                                    final nombre = ([
                                      a['nombres'],
                                      a['apellidos']
                                    ]
                                            .where((x) =>
                                                x != null &&
                                                x.toString().isNotEmpty)
                                            .join(' '))
                                        .trim();
                                    return DropdownMenuItem(
                                        value: sigla,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _advisorAvatar(a, nombre),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                  nombre.isNotEmpty
                                                      ? nombre
                                                      : sigla,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ));
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
                            field('Dirección', dirCtrl,
                                Icons.location_on_outlined),

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
                                fuenteOpciones()
                                        .any((p) => p.$1 == selectedFuente)
                                    ? selectedFuente
                                    : null,
                                [
                                  const DropdownMenuItem(
                                      value: null, child: Text('[Seleccione]')),
                                  ...fuenteOpciones().map((p) =>
                                      DropdownMenuItem(
                                          value: p.$1,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: sourceColor(p.$2),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                  child: Text(p.$2,
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                            ],
                                          ))),
                                ],
                                (v) => setS(() => selectedFuente = v)),

                            field('Valor Solicitado', valorCtrl,
                                Icons.attach_money_rounded,
                                kb: TextInputType.number,
                                required: true,
                                onChanged: (_) => setS(() {})),
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
                                  kb: TextInputType.number,
                                  onChanged: (_) => setS(() {})),
                            ),
                            rowFields(
                              dropdown<String>(
                                  'Tipo de Interés',
                                  Icons.percent_rounded,
                                  selectedTipoInt,
                                  tipoIntOpciones
                                      .map((o) => DropdownMenuItem(
                                          value: o.$1, child: Text(o.$2)))
                                      .toList(),
                                  (v) => setS(() => selectedTipoInt = v)),
                              dropdown<String>(
                                  'Tasa interés',
                                  Icons.percent_rounded,
                                  tasaOpciones().contains(selectedTasa)
                                      ? selectedTasa
                                      : null,
                                  tasaOpciones()
                                      .map((t) => DropdownMenuItem(
                                          value: t, child: Text('$t%')))
                                      .toList(),
                                  (v) => setS(() => selectedTasa = v)),
                            ),

                            sectionLabel('Proyección de cuotas'),
                            cuotasTable(),

                            const SizedBox(height: 16),
                            // ── Botones ──
                            Row(children: [
                              Expanded(
                                  child: appCancelButton(
                                      'Cerrar', () => Navigator.pop(ctx),
                                      height: 46)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: GestureDetector(
                                onTap: saving ? null : grabar,
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
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
          ),
        );
      }),
    );
  }

  Future<void> _aprobarSolicitud(Map<String, dynamic> p) async {
    final cod = (p['codigo_solicitud'] ?? '').toString();
    String? asesorSel =
        creditAdvisorFilter.isNotEmpty ? creditAdvisorFilter : null;

    // Si no hay asesor preseleccionado, pedir al usuario
    if (asesorSel == null && advisors.isNotEmpty) {
      asesorSel = await showDialog<String>(
        context: screenContext,
        builder: (ctx) {
          String? tmp = advisors.first['sigla']?.toString() ?? '';
          return StatefulBuilder(
              builder: (ctx, setS) => AppAnimatedDialog(
                    child: Dialog(
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 48,
                                offset: const Offset(0, 20)),
                          ],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 26),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF065F46), Color(0xFF16A34A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: Column(children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      width: 2),
                                ),
                                child: const Icon(Icons.person_add_alt_1_rounded,
                                    color: Colors.white, size: 30),
                              ),
                              const SizedBox(height: 14),
                              const Text('Asignar asesor',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3)),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                            child: Column(children: [
                              Text(
                                  'Selecciona el asesor responsable de esta solicitud.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13, color: textSoft, height: 1.4)),
                              const SizedBox(height: 16),
                              InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Asesor',
                                  filled: true,
                                  fillColor: inputFill,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: tmp,
                                    dropdownColor: dialogBg,
                                    isExpanded: true,
                                    items: advisors.map((a) {
                                      final sigla = (a['sigla'] ??
                                              a['codigo_asesor'] ??
                                              '')
                                          .toString();
                                      final nombre = ([
                                        a['nombres'],
                                        a['apellidos']
                                      ]
                                              .where((x) =>
                                                  x != null &&
                                                  x.toString().isNotEmpty)
                                              .join(' '))
                                          .trim();
                                      return DropdownMenuItem(
                                          value: sigla,
                                          child: Text(nombre.isNotEmpty
                                              ? nombre
                                              : sigla));
                                    }).toList(),
                                    onChanged: (v) => setS(() => tmp = v),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textSoft,
                                      side: BorderSide(
                                          color: lineCol, width: 1.5),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, null),
                                    child: const Text('Cancelar',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF065F46),
                                          Color(0xFF16A34A)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF16A34A)
                                              .withValues(alpha: 0.38),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      onPressed: () => Navigator.pop(ctx, tmp),
                                      child: const Text('Aprobar',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                    ),
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ));
        },
      );
      if (asesorSel == null || !isMounted) return;
    }

    final r = await repository.post('/ajax/aprobar_solicitud.php', {
      'codigo_solicitud': cod,
      'codigo_asesor': asesorSel ?? '',
    });
    if (!isMounted) return;
    final exito =
        r.statusCode == 200 && r.body.toLowerCase().contains('aprobado');
    showResult(
        exito,
        exito
            ? 'Solicitud #$cod aprobada exitosamente'
            : friendlyError(r.body));
    if (exito) {
      await fetchPending();
      if (isMounted) refresh(() {});
    }
  }

  Future<void> _rechazarSolicitud(Map<String, dynamic> p) async {
    final cod = (p['codigo_solicitud'] ?? '').toString();
    final nombre = ([p['nombres'], p['apellidos']]
            .where((x) => x != null && x.toString().isNotEmpty)
            .join(' '))
        .trim();
    final ok = await showDialog<bool>(
      context: screenContext,
      builder: (ctx) => AppConfirmDialog(
        title: '¿Rechazar solicitud?',
        message: 'La solicitud #$cod de $nombre será rechazada y no podrá deshacerse desde aquí.',
        icon: Icons.cancel_rounded,
        confirmLabel: 'Rechazar',
        cancelLabel: 'No',
        gradientColors: const [Color(0xFF7F1D1D), Color(0xFFEF4444)],
      ),
    );
    if (ok != true || !isMounted) return;
    final r = await repository
        .post('/ajax/rechazar_solicitud.php', {'codigo_solicitud': cod});
    if (!isMounted) return;
    final exito =
        r.statusCode == 200 && r.body.toLowerCase().contains('rechazado');
    showResult(
        exito, exito ? 'Solicitud #$cod rechazada' : friendlyError(r.body));
    if (exito) {
      await fetchPending();
      if (isMounted) refresh(() {});
    }
  }

  Future<void> _showCuotasDialog(Map<String, dynamic> credito) async {
    final cod = credito['cod']?.toString() ?? '';
    final cliente = (credito['cliente'] ?? '').toString();
    List<Map<String, dynamic>> cuotas = [];
    bool loading = true;
    bool requestStarted = false;
    final hoy = DateTime.now();

    await showDialog(
      context: screenContext,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (loading && !requestStarted) {
          requestStarted = true;
          repository.post('/ajax/get_cuotas_credito.php',
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
              (numberValue(q['valor_pagado'] ?? 0) >=
                      numberValue(q['valor_pago'] ?? 1) &&
                  numberValue(q['valor_pagado'] ?? 0) > 0);
          if (pagada) {
            return isDarkTheme
                ? const Color(0xFF12341F)
                : const Color(0xFFC8E6C9);
          }
          try {
            final fp = DateTime.parse((q['fecha_pago'] ?? '').toString());
            if (fp.isBefore(hoy)) {
              return isDarkTheme
                  ? const Color(0xFF3A1A22)
                  : const Color(0xFFFFCDD2);
            }
          } catch (_) {}
          return cardBg;
        }

        Color cuotaTextColor(Map<String, dynamic> q) {
          final pagadoFlag = (q['pagado'] ?? '').toString().toLowerCase();
          final pagada = pagadoFlag == 'si' ||
              (numberValue(q['valor_pagado'] ?? 0) >=
                      numberValue(q['valor_pago'] ?? 1) &&
                  numberValue(q['valor_pagado'] ?? 0) > 0);
          if (pagada) {
            return isDarkTheme
                ? const Color(0xFF6EE7A0)
                : const Color(0xFF1B5E20);
          }
          try {
            final fp = DateTime.parse((q['fecha_pago'] ?? '').toString());
            if (fp.isBefore(hoy)) {
              return isDarkTheme
                  ? const Color(0xFFF87171)
                  : const Color(0xFFB71C1C);
            }
          } catch (_) {}
          return textMain;
        }

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: dialogBg,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header con gradiente compartido (mismo estilo que el resto de
              // diálogos). appDialogHeader ya se recorta a sí mismo con
              // radio 20 (ver home_constants.dart): el shape de este Dialog
              // debe coincidir en 20 para que no quede un borde cuadrado del
              // Dialog asomando detrás de la esquina redondeada del header.
              appDialogHeader(
                icon: Icons.list_alt_rounded,
                title: 'Listado de cuotas',
                subtitle: '$cliente · Cód #$cod',
                gradientColors: const [
                  Color(0xFF1E1B4B),
                  Color(0xFF3B3B8A),
                  Color(0xFF4F46E5),
                ],
                onClose: () => Navigator.pop(ctx),
              ),
              // Cabecera tabla, con degradado a juego con el header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF3B3B8A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Sin cuotas registradas',
                        style: TextStyle(color: textSoft)))
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cuotas.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: lineCol),
                    itemBuilder: (_, i) {
                      final q = cuotas[i];
                      final bg = cuotaColor(q);
                      final txt = cuotaTextColor(q);
                      final valorPago = numberValue(q['valor_pago'] ?? 0);
                      final valorPagado = numberValue(q['valor_pagado'] ?? 0);
                      final pagadoFlag = (q['pagado'] ?? '').toString();
                      final pagadoSi = pagadoFlag.toLowerCase() == 'si' ||
                          (valorPagado >= valorPago && valorPagado > 0);
                      final fechaPago = (q['fecha_pago'] ?? '').toString();
                      final accentPill = pagadoSi
                          ? (isDarkTheme
                              ? const Color(0xFF6EE7A0)
                              : const Color(0xFF1B5E20))
                          : (isDarkTheme
                              ? const Color(0xFFF87171)
                              : const Color(0xFFB71C1C));
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(
                            'cuota_${q['codigo_cuota'] ?? q['numero_cuota'] ?? i}'),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 380),
                        curve: Interval(
                          (i * 0.05).clamp(0.0, 0.6),
                          (i * 0.05 + 0.5).clamp(0.5, 1.0),
                          curve: Curves.easeOutCubic,
                        ),
                        builder: (_, v, child) => Opacity(
                          opacity: v.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(12 * (1 - v), 0),
                            child: RepaintBoundary(child: child),
                          ),
                        ),
                        child: Container(
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
                                    style:
                                        TextStyle(fontSize: 10, color: txt))),
                            Expanded(
                                flex: 3,
                                child: Text(formatCop(valorPago),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: txt))),
                            Expanded(
                                flex: 3,
                                child: Text(
                                    valorPagado > 0
                                        ? formatCop(valorPagado)
                                        : '',
                                    style:
                                        TextStyle(fontSize: 10, color: txt))),
                            SizedBox(
                                width: 28,
                                child: Center(
                                  child: Container(
                                    width: 22,
                                    height: 18,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: accentPill.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                        pagadoSi
                                            ? Icons.check_rounded
                                            : Icons.close_rounded,
                                        size: 12,
                                        color: accentPill),
                                  ),
                                )),
                            SizedBox(
                                width: 48,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showRegistroPagoDialog(ctx, q, () {
                                      repository.post(
                                          '/ajax/get_cuotas_credito.php', {
                                        'codigo_credito': cod
                                      }).then((r) {
                                        if (r.statusCode == 200) {
                                          try {
                                            final d = jsonDecode(r.body);
                                            if (d is List) {
                                              cuotas = d
                                                  .whereType<Map>()
                                                  .map((e) => Map<String,
                                                      dynamic>.from(e))
                                                  .toList();
                                            }
                                          } catch (_) {}
                                        }
                                        if (ctx.mounted) setS(() {});
                                        repository.invalidateCache(
                                            '/ajax/get_creditos_lista.php');
                                        fetchCredits('').then((_) {
                                          if (isMounted) refresh(() {});
                                        });
                                      });
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: btnPrimary.withValues(
                                            alpha: isDarkTheme ? 0.28 : 0.12),
                                        borderRadius:
                                            BorderRadius.circular(7),
                                        border: isDarkTheme
                                            ? Border.all(
                                                color: btnPrimary.withValues(
                                                    alpha: 0.5),
                                                width: 1)
                                            : null,
                                      ),
                                      child: Icon(
                                          Icons.assignment_turned_in_outlined,
                                          size: 14,
                                          color: isDarkTheme
                                              ? const Color(0xFFA5B4FC)
                                              : btnPrimary),
                                    ),
                                  ),
                                )),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              // Botón Cerrar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: appCancelButton('Cerrar', () => Navigator.pop(ctx)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _showRegistroPagoDialog(BuildContext parentCtx,
      Map<String, dynamic> cuota, VoidCallback onSaved) async {
    final codigoCuota = cuota['codigo_cuota']?.toString() ?? '';
    String interes = '1'; // 1=No interés, 2=Con interés, 3=Abono parcial
    String fuente = '';
    final valorCtrl = TextEditingController(
        text: (cuota['valor_pago'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), ''));
    final comentCtrl = TextEditingController();
    DateTime fechaPago = DateTime.now();
    double moraVal = 0;
    double tasaMensual = 0;
    double tiempoCuotaDiv = 1;
    double interesCuotaServidor = 0;
    // Saldo pendiente real de la cuota (valor_pago menos abonos ya
    // registrados) y su historial, usados por la opción "Abono".
    double saldoPendiente = double.tryParse((cuota['valor_pago'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
    double totalAbonado = 0;
    List<Map<String, dynamic>> historialAbonos = [];
    final valorCuota = double.tryParse((cuota['valor_pago'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
    bool loadingMora = codigoCuota.isNotEmpty;
    bool loadingAbonos = codigoCuota.isNotEmpty;
    bool saving = false;
    // Pestaña activa: registrar pago (formulario) o ver el historial de
    // abonos ya registrados para esta cuota. Ambas conviven en el mismo
    // diálogo para no agregar un botón nuevo en la fila de cuotas.
    bool mostrarHistorial = false;
    final fuentesPago = <Map<String, String>>[];
    final codigosFuente = <String>{};
    for (final cuenta in accounts) {
      final codigo =
          (cuenta['codigo'] ?? cuenta['codigo_cuenta'] ?? '').toString().trim();
      final nombre =
          (cuenta['nombre'] ?? cuenta['cuenta'] ?? '').toString().trim();
      final activa = (cuenta['estado'] ?? '1').toString() != '0';
      if (codigo.isNotEmpty &&
          nombre.isNotEmpty &&
          activa &&
          codigosFuente.add(codigo)) {
        fuentesPago.add({'codigo': codigo, 'nombre': nombre});
      }
    }
    fuentesPago.sort((a, b) =>
        a['nombre']!.toLowerCase().compareTo(b['nombre']!.toLowerCase()));

    await showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (loadingMora && codigoCuota.isNotEmpty) {
          loadingMora = false;
          repository.post('/ajax/consultar_datos_cuota.php',
              {'codigo_cuota': codigoCuota}).then((r) {
            if (r.statusCode == 200) {
              try {
                final d = jsonDecode(r.body);
                if (d is Map && d['success'] == true) {
                  final inc = double.tryParse(
                          d['valor_incremento']?.toString() ?? '0') ??
                      0;
                  final tasa = double.tryParse(
                          d['tasa_interes_mensual']?.toString() ?? '0') ??
                      0;
                  final tiempo = double.tryParse(
                          d['tiempo_cuota']?.toString() ?? '1') ??
                      1;
                  final interesCuota = double.tryParse(
                          d['interes_cuota']?.toString() ?? '0') ??
                      0;
                  final saldo = double.tryParse(
                          d['saldo_pendiente']?.toString() ?? '0') ??
                      valorCuota;
                  final abonado = double.tryParse(
                          d['total_abonado']?.toString() ?? '0') ??
                      0;
                  if (ctx.mounted) {
                    setS(() {
                      moraVal = inc;
                      tasaMensual = tasa;
                      tiempoCuotaDiv = tiempo > 0 ? tiempo : 1;
                      interesCuotaServidor = interesCuota;
                      saldoPendiente = saldo;
                      totalAbonado = abonado;
                    });
                  }
                }
              } catch (_) {}
            }
          });
        }
        if (loadingAbonos && codigoCuota.isNotEmpty) {
          loadingAbonos = false;
          repository.post('/ajax/listar_abonos_cuota.php',
              {'codigo_cuota': codigoCuota}).then((r) {
            if (r.statusCode == 200) {
              try {
                final d = jsonDecode(r.body);
                if (d is Map && d['success'] == true) {
                  final lista = (d['abonos'] as List? ?? [])
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                  if (ctx.mounted) setS(() => historialAbonos = lista);
                }
              } catch (_) {}
            }
          });
        }

        String fechaStr() {
          return '${fechaPago.year}-${fechaPago.month.toString().padLeft(2, '0')}-${fechaPago.day.toString().padLeft(2, '0')}';
        }

        // Vista previa: marcar Interés=Sí sobre un pago MENOR a la cuota
        // indica que ese abono cubre el interés de ESTA cuota
        // (interesCuotaServidor, calculado por el servidor según
        // tipo_interes: Fijo = prorrateo del interés total del crédito;
        // Variable = interés sobre saldo); el resto abona a capital y el
        // saldo se proyecta a una cuota nueva con la tasa vigente.
        // Pago MENOR sin marcar interés no modifica nada (queda pendiente).
        // Pago MAYOR siempre recalcula las cuotas futuras pendientes (el
        // servidor decide la fórmula exacta según tipo_interes; el cliente
        // solo avisa).
        final valPagadoPrev = double.tryParse(valorCtrl.text.trim()) ?? 0;
        final tasaPeriodo =
            tiempoCuotaDiv > 0 ? (tasaMensual / 100) / tiempoCuotaDiv : 0.0;
        final esPagoParcial = interes == '2' &&
            valPagadoPrev > 0 &&
            valorCuota > 0 &&
            valPagadoPrev < valorCuota;
        final esPagoMenorSinInteres = interes == '1' &&
            valPagadoPrev > 0 &&
            valorCuota > 0 &&
            valPagadoPrev < valorCuota;
        final esPagoMayor = valPagadoPrev > 0 &&
            valorCuota > 0 &&
            valPagadoPrev > valorCuota;
        final excedentePrev = valPagadoPrev - valorCuota;
        final interesCuotaPrev =
            interesCuotaServidor > valPagadoPrev ? valPagadoPrev : interesCuotaServidor;
        final abonoCapitalPrev = (valPagadoPrev - interesCuotaPrev) > 0
            ? valPagadoPrev - interesCuotaPrev
            : 0.0;
        final capitalCuotaPrev = valorCuota - interesCuotaPrev;
        final saldoCapitalPrev = capitalCuotaPrev - abonoCapitalPrev;
        final nuevaCuotaPrev =
            (saldoCapitalPrev * (1 + tasaPeriodo)).roundToDouble();

        Widget tabChip(String label, bool selected, VoidCallback onTap,
            {required List<Color> gradient, required Color glow}) {
          return Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : inputFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? gradient.first : lineCol),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : textMain)),
              ),
            ),
          );
        }

        Widget summaryRow(String label, String value,
            {bool emphasize = false}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: emphasize ? textMain : textSoft)),
                  Text(value,
                      style: TextStyle(
                          fontSize: emphasize ? 15 : 13,
                          fontWeight:
                              emphasize ? FontWeight.w800 : FontWeight.w600,
                          color: emphasize
                              ? const Color(0xFFF87171)
                              : textMain)),
                ]),
          );
        }

        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Registro de pago',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: textMain)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 4),
              // Pestañas: formulario de pago vs. historial de abonos ya
              // registrados para esta cuota (evita agregar otro botón en la
              // fila de cuotas).
              Row(children: [
                tabChip('Registrar pago', !mostrarHistorial,
                    () => setS(() => mostrarHistorial = false),
                    gradient: const [Color(0xFF4338CA), Color(0xFF2D2A9E)],
                    glow: const Color(0xFF4338CA)),
                const SizedBox(width: 10),
                tabChip(
                    historialAbonos.isEmpty
                        ? 'Historial'
                        : 'Historial (${historialAbonos.length})',
                    mostrarHistorial,
                    () => setS(() => mostrarHistorial = true),
                    gradient: const [Color(0xFF34D399), Color(0xFF047857)],
                    glow: const Color(0xFF10B981)),
              ]),
              const SizedBox(height: 20),
              if (mostrarHistorial) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkTheme
                          ? [
                              const Color(0xFF10B981).withValues(alpha: 0.16),
                              const Color(0xFF047857).withValues(alpha: 0.08),
                            ]
                          : [
                              const Color(0xFFDCFCE7),
                              const Color(0xFFECFDF5),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF10B981)
                            .withValues(alpha: isDarkTheme ? 0.35 : 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summaryRow('Valor de la cuota', formatCop(valorCuota)),
                      if (totalAbonado > 0) ...[
                        Divider(
                            height: 12,
                            color: lineCol.withValues(alpha: 0.6)),
                        summaryRow(
                            'Total abonado', formatCop(totalAbonado)),
                      ],
                      Divider(
                          height: 12, color: lineCol.withValues(alpha: 0.6)),
                      summaryRow(
                          'Saldo pendiente', formatCop(saldoPendiente),
                          emphasize: true),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (historialAbonos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(children: [
                      Icon(Icons.inbox_outlined,
                          size: 32, color: textSoft.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('Aún no se han registrado abonos',
                          style: TextStyle(fontSize: 12, color: textSoft)),
                    ]),
                  )
                else
                  ...historialAbonos.map((a) {
                    final valor = double.tryParse(
                            a['valor_abonado']?.toString() ?? '0') ??
                        0;
                    final fecha = (a['fecha_abono'] ?? '').toString();
                    final comentarios =
                        (a['comentarios'] ?? '').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: lineCol),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(fecha,
                                      style: TextStyle(
                                          fontSize: 12, color: textSoft)),
                                  Text(formatCop(valor),
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textMain)),
                                ]),
                            if (comentarios.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(comentarios,
                                  style: TextStyle(
                                      fontSize: 11, color: textSoft)),
                            ],
                          ]),
                    );
                  }),
              ] else ...[
              // Interés
              Row(children: [
                SizedBox(
                    width: 80,
                    child: Text('Interés',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMain))),
                Expanded(
                    child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lineCol),
                  ),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                    value: interes,
                    isExpanded: true,
                    dropdownColor: dialogBg,
                    iconEnabledColor: formAccent,
                    style: TextStyle(
                      fontSize: 13,
                      color: textMain,
                      fontWeight: FontWeight.w500,
                    ),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('No')),
                      DropdownMenuItem(value: '2', child: Text('Si')),
                      DropdownMenuItem(value: '3', child: Text('Abono')),
                    ],
                    onChanged: (v) => setS(() => interes = v ?? '1'),
                  )),
                )),
              ]),
              const SizedBox(height: 16),
              // Valor pagado / Valor del abono
              TextField(
                controller: valorCtrl,
                onChanged: (_) => setS(() {}),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: textMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: formAccent,
                decoration: InputDecoration(
                  labelText: interes == '3' ? 'Valor del abono' : 'Valor pagado',
                  labelStyle: TextStyle(
                    color: formLabel,
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: formAccent,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: formAccent,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              // Vista previa en tiempo real del saldo tras el abono
              if (interes == '3') ...[
                Builder(builder: (_) {
                  final valorEscrito =
                      double.tryParse(valorCtrl.text.trim()) ?? 0;
                  if (valorEscrito <= 0) return const SizedBox.shrink();
                  final excede = valorEscrito > saldoPendiente + 0.01;
                  final saldoTrasAbono = (saldoPendiente - valorEscrito)
                      .clamp(0.0, saldoPendiente);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      excede
                          ? 'El abono supera el saldo pendiente'
                          : 'Saldo tras este abono: ${formatCop(saldoTrasAbono)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: excede
                            ? const Color(0xFFB71C1C)
                            : const Color(0xFF1B5E20),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 18),
              // Mora calculada (read-only)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: moraVal > 0
                      ? const Color(0xFFFFD7DB)
                      : const Color(0xFFDDF2E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: moraVal > 0
                        ? const Color(0xFFF3A8B0)
                        : const Color(0xFFB8DFC0),
                  ),
                ),
                child: Text(
                  moraVal > 0
                      ? 'Incremento por mora: ${formatCop(moraVal)}'
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
              const SizedBox(height: 16),
              // Vista previa de pago parcial a capital (Interés = Sí)
              if (esPagoParcial) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E8FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB6C2EE)),
                  ),
                  child: Text(
                    'Pago parcial: cubre interés (${formatCop(interesCuotaPrev)}) '
                    'y abona ${formatCop(abonoCapitalPrev)} a capital. '
                    'Se creará una cuota nueva de ${formatCop(nuevaCuotaPrev)}.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3A8C),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Aviso: pago menor sin marcar interés no modifica la cuota
              if (esPagoMenorSinInteres) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF0D68A)),
                  ),
                  child: const Text(
                    'El valor es menor a la cuota. Así no se registrará ningún '
                    'cambio: la cuota seguirá pendiente. Marca "Interés = Sí" '
                    'si este abono cubre el interés y el resto a capital.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A6D1D),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Vista previa de pago mayor: excedente a la cuota siguiente
              if (esPagoMayor) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF2E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB8DFC0)),
                  ),
                  child: Text(
                    'Pago mayor: se cobra esta cuota completa y el excedente '
                    '(${formatCop(excedentePrev)}) abona a capital, recalculando '
                    'las cuotas futuras pendientes (quedan más bajas).',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Fuente
              DropdownButtonFormField<String>(
                initialValue: fuente,
                isExpanded: true,
                dropdownColor: dialogBg,
                iconEnabledColor: formAccent,
                style: TextStyle(
                  color: textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                selectedItemBuilder: (context) => [
                  Text('[Seleccione]',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSoft)),
                  ...fuentesPago.map((f) => Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                              color: sourceColor(f['nombre']!),
                              shape: BoxShape.circle),
                        ),
                        Flexible(
                          child: Text(f['nombre']!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textMain)),
                        ),
                      ])),
                ],
                decoration: InputDecoration(
                  labelText: 'Fuente',
                  labelStyle: TextStyle(
                    color: formLabel,
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: formAccent,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: formAccent,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(
                      '[Seleccione]',
                      style: TextStyle(color: textSoft),
                    ),
                  ),
                  ...fuentesPago.map((f) {
                    return DropdownMenuItem(
                      value: f['codigo'],
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: sourceColor(f['nombre']!),
                              shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Text(f['nombre']!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textMain)),
                        ),
                      ]),
                    );
                  }),
                ],
                onChanged: (v) => setS(() => fuente = v ?? ''),
              ),
              const SizedBox(height: 16),
              // Fecha de Pago
              GestureDetector(
                onTap: () async {
                  final d = await showLightDatePicker(
                    ctx,
                    initialDate: fechaPago,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null && ctx.mounted) setS(() => fechaPago = d);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lineCol),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 15, color: formAccent),
                    const SizedBox(width: 10),
                    Text(
                      '${fechaPago.day.toString().padLeft(2, '0')}/${fechaPago.month.toString().padLeft(2, '0')}/${fechaPago.year}',
                      style: TextStyle(fontSize: 13, color: textMain),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              // Comentarios
              TextField(
                controller: comentCtrl,
                maxLines: 3,
                style: TextStyle(
                  color: textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: formAccent,
                decoration: InputDecoration(
                  hintText: 'Comentarios (opcional)',
                  hintStyle: TextStyle(
                    color: textSoft,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: lineCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: formAccent,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              ],
            ]),
          ),
          actions: [
            Row(children: [
              Expanded(
                  child: appCancelButton('Cerrar', () => Navigator.pop(ctx))),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mostrarHistorial
                          ? btnPrimary.withValues(alpha: 0.35)
                          : btnPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            if (mostrarHistorial) {
                              setS(() => mostrarHistorial = false);
                              return;
                            }
                            final val =
                                double.tryParse(valorCtrl.text.trim()) ?? 0;
                            if (val <= 0) {
                              showResult(
                                  false,
                                  interes == '3'
                                      ? 'Ingresa el valor del abono antes de continuar'
                                      : 'Ingresa el valor del pago antes de continuar');
                              return;
                            }
                            if (fuente.isEmpty) {
                              showResult(false,
                                  'Selecciona la fuente donde ingresó el pago');
                              return;
                            }

                            if (interes == '3') {
                              // Abono parcial ligado a la cuota: suma un
                              // movimiento nuevo (no sobrescribe abonos
                              // previos), la cuota solo queda pagada cuando
                              // la suma alcanza el valor completo.
                              if (val > saldoPendiente + 0.01) {
                                showResult(false,
                                    'El abono no puede ser mayor al saldo pendiente (${formatCop(saldoPendiente)})');
                                return;
                              }
                              setS(() => saving = true);
                              final r = await repository
                                  .post('/ajax/registrar_abono_cuota.php', {
                                'codigo_cuota': codigoCuota,
                                'valor_abonado': valorCtrl.text.trim(),
                                'fuente_abono': fuente,
                                'fecha_abono': fechaStr(),
                                'comentarios': comentCtrl.text.trim(),
                              });
                              setS(() => saving = false);
                              if (!ctx.mounted) return;
                              final decoded = decodeJsonMap(r.body);
                              final ok = r.statusCode == 200 &&
                                  decoded['success'] == true;
                              if (ok) {
                                Navigator.pop(ctx);
                                onSaved();
                              }
                              showResult(
                                  ok,
                                  ok
                                      ? (decoded['mensaje']?.toString() ??
                                          'Abono registrado correctamente')
                                      : friendlyError(r.body));
                              return;
                            }

                            if (interes == '1' &&
                                valorCuota > 0 &&
                                val < valorCuota) {
                              showResult(
                                  false,
                                  'El valor es menor a la cuota. Marca "Interés = Sí" '
                                  'si este abono cubre el interés y el resto a capital, '
                                  'o completa el valor de la cuota.');
                              return;
                            }
                            setS(() => saving = true);
                            final r = await repository
                                .post('/ajax/registrar_cuota_credito.php', {
                              'codigo_cuota': codigoCuota,
                              'interes': interes,
                              'valor_pagado': valorCtrl.text.trim(),
                              'fuente_cuota': fuente,
                              'fecha_pago': fechaStr(),
                              'comentarios': comentCtrl.text.trim(),
                            });
                            setS(() => saving = false);
                            if (!ctx.mounted) return;
                            final bodyLowerCuota = r.body.toLowerCase();
                            final decodedCuota = decodeJsonMap(r.body);
                            final ok = r.statusCode == 200 &&
                                (decodedCuota['success'] == true ||
                                    decodedCuota['resultado'] == 1 ||
                                    bodyLowerCuota
                                        .contains('pago registrado') ||
                                    bodyLowerCuota.contains('registrado') ||
                                    bodyLowerCuota.contains('exitoso') ||
                                    bodyLowerCuota.contains('success'));
                            if (ok) {
                              Navigator.pop(ctx);
                              onSaved();
                            }
                            showResult(
                                ok,
                                ok
                                    ? 'Pago registrado correctamente'
                                    : friendlyError(r.body));
                          },
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(mostrarHistorial ? 'Volver' : 'Grabar'),
                  ),
                ),
              ),
            ]),
          ],
        );
      }),
    );
  }

  // ── Liquidación anticipada ────────────────────────────────────────
  Future<void> _showLiquidarCreditoDialog(Map<String, dynamic> credito) async {
    final cod = credito['cod']?.toString() ?? '';
    final cliente = (credito['cliente'] ?? '').toString();
    DateTime fechaLiquidacion = DateTime.now();
    String fuente = '';
    final comentCtrl = TextEditingController();
    final fuentesPago = <Map<String, String>>[];
    final codigosFuente = <String>{};
    for (final cuenta in accounts) {
      final codigo =
          (cuenta['codigo'] ?? cuenta['codigo_cuenta'] ?? '').toString().trim();
      final nombre =
          (cuenta['nombre'] ?? cuenta['cuenta'] ?? '').toString().trim();
      final activa = (cuenta['estado'] ?? '1').toString() != '0';
      if (codigo.isNotEmpty &&
          nombre.isNotEmpty &&
          activa &&
          codigosFuente.add(codigo)) {
        fuentesPago.add({'codigo': codigo, 'nombre': nombre});
      }
    }
    fuentesPago.sort((a, b) =>
        a['nombre']!.toLowerCase().compareTo(b['nombre']!.toLowerCase()));

    bool calculando = false;
    bool confirmando = false;
    String? errorCalculo;
    Map<String, dynamic>? calculo; // resultado de la simulación vigente

    await showDialog(
      context: screenContext,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        String fechaStr() {
          return '${fechaLiquidacion.year}-${fechaLiquidacion.month.toString().padLeft(2, '0')}-${fechaLiquidacion.day.toString().padLeft(2, '0')}';
        }

        Future<void> calcular() async {
          setS(() {
            calculando = true;
            errorCalculo = null;
            calculo = null;
          });
          final r =
              await repository.post('/ajax/simular_liquidacion_credito.php', {
            'codigo_credito': cod,
            'fecha_liquidacion': fechaStr(),
          });
          final decoded = decodeJsonMap(r.body);
          if (!ctx.mounted) return;
          if (r.statusCode == 200 && decoded['success'] == true) {
            setS(() {
              calculando = false;
              calculo = decoded;
            });
          } else {
            setS(() {
              calculando = false;
              errorCalculo =
                  (decoded['error'] ?? 'No se pudo calcular la liquidación')
                      .toString();
            });
          }
        }

        final valorLiquidacion =
            numberValue(calculo?['valor_liquidacion'] ?? 0);
        final capitalPendiente =
            numberValue(calculo?['capital_pendiente'] ?? 0);
        final interesTotal = numberValue(calculo?['interes_total'] ?? 0);
        final cuotasPendientes =
            int.tryParse(calculo?['cuotas_pendientes']?.toString() ?? '0') ?? 0;

        return AppAnimatedDialog(
          child: Dialog(
            backgroundColor: dialogBg,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // appDialogHeader ya se recorta a sí mismo con radio 20 (ver
              // home_constants.dart): el shape de este Dialog debe coincidir
              // en 20 para que no quede un borde cuadrado del Dialog
              // asomando detrás de la esquina redondeada del header.
              appDialogHeader(
                icon: Icons.request_page_rounded,
                title: 'Liquidar crédito #$cod',
                subtitle: 'Cliente: $cliente',
                gradientColors: const [
                  Color(0xFF1E1B4B),
                  Color(0xFF3B3B8A),
                  Color(0xFF7C3AED),
                ],
                onClose: () => Navigator.pop(ctx),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Fecha de liquidación
                GestureDetector(
                  onTap: () async {
                    final d = await showLightDatePicker(
                      ctx,
                      initialDate: fechaLiquidacion,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (d != null && ctx.mounted) {
                      setS(() {
                        fechaLiquidacion = d;
                        calculo = null;
                        errorCalculo = null;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: lineCol),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 15, color: Color(0xFF3B3B8A)),
                      const SizedBox(width: 10),
                      Text(
                        'Fecha de liquidación: ${fechaLiquidacion.day.toString().padLeft(2, '0')}/${fechaLiquidacion.month.toString().padLeft(2, '0')}/${fechaLiquidacion.year}',
                        style: TextStyle(fontSize: 13, color: textMain),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: calculando ? null : calcular,
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3B3B8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF3B3B8A).withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (calculando)
                            const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                          else
                            const Icon(Icons.calculate_outlined,
                                size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                              calculando
                                  ? 'Calculando...'
                                  : 'Calcular valor a pagar',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ]),
                  ),
                ),
                if (errorCalculo != null) ...[
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('err_$errorCalculo'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    builder: (_, v, child) => Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Transform.scale(
                          scale: 0.9 + 0.1 * v,
                          child: RepaintBoundary(child: child)),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDarkTheme
                            ? const Color(0xFF3A1A22)
                            : const Color(0xFFFFD7DB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDarkTheme
                                ? const Color(0xFF6B2837)
                                : const Color(0xFFF3A8B0)),
                      ),
                      child: Text(errorCalculo!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkTheme
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFFB71C1C))),
                    ),
                  ),
                ],
                if (calculo != null) ...[
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('calc_$valorLiquidacion'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (_, v, child) => Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Transform.scale(
                          scale: 0.9 + 0.1 * v,
                          child: RepaintBoundary(child: child)),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDarkTheme
                            ? const Color(0xFF12341F)
                            : const Color(0xFFDDF2E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDarkTheme
                                ? const Color(0xFF1E5A3C)
                                : const Color(0xFFB8DFC0)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Capital pendiente: ${formatCop(capitalPendiente)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkTheme
                                        ? const Color(0xFF6EE7A0)
                                        : const Color(0xFF1B5E20))),
                            const SizedBox(height: 6),
                            Text(
                                'Interés prorateado: ${formatCop(interesTotal)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkTheme
                                        ? const Color(0xFF6EE7A0)
                                        : const Color(0xFF1B5E20))),
                            const SizedBox(height: 6),
                            Text(
                                'Cuotas que se cancelan/fusionan: $cuotasPendientes',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkTheme
                                        ? const Color(0xFF6EE7A0)
                                        : const Color(0xFF1B5E20))),
                            const SizedBox(height: 10),
                            Text(
                                'Total a pagar: ${formatCop(valorLiquidacion)}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkTheme
                                        ? const Color(0xFF6EE7A0)
                                        : const Color(0xFF1B5E20))),
                          ]),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: fuente,
                  isExpanded: true,
                  dropdownColor: dialogBg,
                  iconEnabledColor: const Color(0xFF3B3B8A),
                  style: TextStyle(
                    color: textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Fuente',
                    labelStyle: const TextStyle(
                      color: Color(0xFF5B5BB0),
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: lineCol),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text('[Seleccione]',
                          style: TextStyle(color: textSoft)),
                    ),
                    ...fuentesPago.map((f) => DropdownMenuItem(
                        value: f['codigo'],
                        child: Text(f['nombre']!,
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setS(() => fuente = v ?? ''),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: comentCtrl,
                  maxLines: 3,
                  style: TextStyle(
                      color: textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  cursorColor: const Color(0xFF3B3B8A),
                  decoration: InputDecoration(
                    hintText: 'Comentarios (opcional)',
                    hintStyle: TextStyle(color: textSoft),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: lineCol),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFDC2626)
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('Cerrar',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: (calculo == null || confirmando)
                          ? null
                          : () async {
                              if (fuente.isEmpty) {
                                showResult(false,
                                    'Selecciona la fuente donde ingresó el pago');
                                return;
                              }
                              setS(() => confirmando = true);
                              final r = await repository
                                  .post('/ajax/liquidar_credito.php', {
                                'codigo_credito': cod,
                                'fecha_liquidacion': fechaStr(),
                                'fuente_cuota': fuente,
                                'comentarios': comentCtrl.text.trim(),
                              });
                              setS(() => confirmando = false);
                              if (!ctx.mounted) return;
                              final decoded = decodeJsonMap(r.body);
                              final ok = r.statusCode == 200 &&
                                  decoded['success'] == true;
                              if (ok) {
                                Navigator.pop(ctx);
                                repository.invalidateCache(
                                    '/ajax/get_creditos_lista.php');
                                await fetchCredits('');
                                if (isMounted) refresh(() {});
                              }
                              showResult(
                                  ok,
                                  ok
                                      ? 'Crédito liquidado correctamente'
                                      : friendlyError(
                                          (decoded['error'] ?? r.body)
                                              .toString()));
                            },
                      child: Opacity(
                        opacity: (calculo == null || confirmando) ? 0.4 : 1,
                        child: RepaintBoundary(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: confirmando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Confirmar liquidación',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── Confirmar eliminar ───────────────────────────────────────────
  Future<void> _confirmarEliminarCredito(Map<String, dynamic> credito) async {
    final cod = credito['cod']?.toString() ?? '';
    final cliente = (credito['cliente'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: screenContext,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _EliminarCreditoDialog(cod: cod, cliente: cliente),
    );
    if (ok != true || !isMounted) return;
    final r = await repository
        .post('/ajax/eliminar_credito.php', {'codigo_credito': cod});
    if (!isMounted) return;
    final bodyLowerDel = r.body.toLowerCase();
    final decodedDel = decodeJsonMap(r.body);
    final exito = r.statusCode == 200 &&
        (decodedDel['success'] == true ||
            decodedDel['resultado'] == 1 ||
            bodyLowerDel.contains('eliminado') ||
            bodyLowerDel.contains('exitoso') ||
            bodyLowerDel.contains('success'));
    if (exito) {
      repository.invalidateCache('/ajax/get_creditos_lista.php');
      await fetchCredits('');
      if (isMounted) refresh(() {});
    }
    if (!isMounted) return;
    showDialog(
      context: screenContext,
      builder: (_) => buildResultDialog(
        exito
            ? 'El crédito #$cod de $cliente fue eliminado.'
            : 'No se pudo eliminar el crédito. Por favor intenta de nuevo.',
        exito,
        title: exito ? 'Crédito eliminado' : 'Algo salió mal',
        icon:
            exito ? Icons.delete_forever_rounded : Icons.error_outline_rounded,
      ),
    );
  }

  // ── Confirmar eliminar solicitud rechazada ──────────────────────
  Future<void> _confirmarEliminarSolicitud(Map<String, dynamic> p) async {
    final cod = (p['codigo_solicitud'] ?? p['cod'] ?? '').toString();
    final cliente = ([p['nombres'], p['apellidos']]
            .where((x) => x != null && x.toString().isNotEmpty)
            .join(' '))
        .trim();
    final ok = await showDialog<bool>(
      context: screenContext,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _EliminarCreditoDialog(
        cod: cod,
        cliente: cliente,
        titulo: 'Eliminar solicitud',
        etiquetaItem: 'Solicitud',
      ),
    );
    if (ok != true || !isMounted) return;
    final r = await repository.post(
        '/ajax/eliminar_solicitud_credito.php', {'codigo_solicitud': cod});
    if (!isMounted) return;
    final bodyLower = r.body.toLowerCase().trim();
    final decoded = decodeJsonMap(r.body);
    final exito = r.statusCode == 200 &&
        (decoded['success'] == true ||
            decoded['resultado'] == 1 ||
            bodyLower == '1' ||
            bodyLower.contains('eliminad') ||
            bodyLower.contains('exitoso') ||
            bodyLower.contains('success'));
    if (exito) {
      // Las solicitudes (pendientes/rechazadas) viven en pendingRequests,
      // no en credits — invalidar/refrescar get_creditos_lista.php (como
      // hace el eliminar de créditos aprobados) no actualizaba esta lista,
      // por eso solo se veía el cambio tras un pull-to-refresh manual.
      repository.invalidateCache('/ajax/get_pendientes_lista.php');
      await fetchPending();
      if (isMounted) refresh(() {});
    }
    if (!isMounted) return;
    showDialog(
      context: screenContext,
      builder: (_) => buildResultDialog(
        exito
            ? 'La solicitud #$cod de $cliente fue eliminada.'
            : 'No se pudo eliminar la solicitud. Por favor intenta de nuevo.',
        exito,
        title: exito ? 'Solicitud eliminada' : 'Algo salió mal',
        icon:
            exito ? Icons.delete_forever_rounded : Icons.error_outline_rounded,
      ),
    );
  }

  Future<Uint8List> _generarPazYSalvoPdf({
    required String cliente,
    required String numDoc,
    required String cod,
    required String fechaPrestamo,
    required double valorPrestamo,
    required String ultimaPago,
    required String fechaFirma,
  }) async {
    final documento = pw.Document(
      title: 'Paz y Salvo - Crédito #$cod',
      author: 'SAF - Sistema de Ahorro y Financiamiento',
      subject: 'Certificado de Paz y Salvo',
    );

    const navy = PdfColor(0.051, 0.106, 0.294); // #0D1B4B
    const blue = PdfColor(0.082, 0.396, 0.753); // #1565C0
    const grey700 = PdfColors.grey700;

    documento.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SAF',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 20,
                            color: navy)),
                    pw.Text('Dirección · Tel: (316) 270-5951',
                        style: pw.TextStyle(fontSize: 9, color: grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(fechaFirma,
                        style: pw.TextStyle(fontSize: 9, color: grey700)),
                    pw.Text('Paz y salvo',
                        style: pw.TextStyle(fontSize: 9, color: grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: navy, thickness: 1.5),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text('CERTIFICADO DE PAZ Y SALVO',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                      color: navy,
                      letterSpacing: 1)),
            ),
            pw.SizedBox(height: 20),
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: 11, color: navy, lineSpacing: 3),
                children: [
                  const pw.TextSpan(
                      text: 'La presente certifica que el(la) señor(a) '),
                  pw.TextSpan(
                      text: cliente,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(
                      text: ' identificado(a) con cédula de ciudadanía No. '),
                  pw.TextSpan(
                      text: numDoc,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(
                      text:
                          ' ha cancelado en su totalidad las obligaciones relacionadas con el crédito identificado con número '),
                  pw.TextSpan(
                      text: cod,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: ', realizado el dia '),
                  pw.TextSpan(
                      text: fechaPrestamo,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: ', por valor de '),
                  pw.TextSpan(
                      text: formatCop(valorPrestamo),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: '.'),
                ],
              ),
            ),
            if (ultimaPago.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.RichText(
                text: pw.TextSpan(
                  style:
                      pw.TextStyle(fontSize: 11, color: navy, lineSpacing: 3),
                  children: [
                    pw.TextSpan(
                        text: 'Última Fecha de Pago: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: '$ultimaPago.'),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 12),
            pw.Text(
              'Este certificado se expide a solicitud del interesado para los fines que estime convenientes.',
              style: pw.TextStyle(fontSize: 11, color: navy, lineSpacing: 3),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'En constancia de lo anterior, se firma a los $fechaFirma.',
              style: pw.TextStyle(fontSize: 11, color: navy, lineSpacing: 3),
            ),
            pw.SizedBox(height: 36),
            pw.Center(
              child: pw.Container(
                width: 90,
                height: 90,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: blue, width: 2),
                ),
                child: pw.Center(
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('SAF',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: blue)),
                      pw.Text('PAZ Y SALVO',
                          style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                              color: blue)),
                    ],
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Row(children: [
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Divider(color: navy),
                  pw.Text('Asesor',
                      style: pw.TextStyle(fontSize: 10, color: grey700)),
                ]),
              ),
              pw.SizedBox(width: 32),
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Divider(color: navy),
                  pw.Text('Deudor',
                      style: pw.TextStyle(fontSize: 10, color: grey700)),
                ]),
              ),
            ]),
          ],
        ),
      ),
    );

    return documento.save();
  }

  void _showPazYSalvoDialog(Map<String, dynamic> credito) {
    final cliente = (credito['cliente'] ?? '').toString();
    final numDoc = (credito['num_documento'] ?? '').toString();
    final cod = credito['cod']?.toString() ?? '';
    final fechaPrestamo = (credito['fecha_prestamo'] ?? '').toString();
    final valorPrestamo = numberValue(credito['valor_prestamo'] ?? 0);
    final ultimaPago = (credito['ultima_fecha_pago'] ?? '').toString();
    final hoy = DateTime.now();
    final fechaFirma = '${hoy.day}/${hoy.month}/${hoy.year}';
    bool generandoPdf = false;

    Future<void> descargarPdf(StateSetter setS) async {
      setS(() => generandoPdf = true);
      try {
        final bytes = await _generarPazYSalvoPdf(
          cliente: cliente,
          numDoc: numDoc,
          cod: cod,
          fechaPrestamo: fechaPrestamo,
          valorPrestamo: valorPrestamo,
          ultimaPago: ultimaPago,
          fechaFirma: fechaFirma,
        );
        final nombreSeguro = cliente
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_|_$'), '');
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'paz_y_salvo_${nombreSeguro.isEmpty ? 'credito' : nombreSeguro}_$cod.pdf',
        );
      } on MissingPluginException {
        if (isMounted) {
          showResult(false,
              'La descarga de PDF requiere instalar la nueva versión de SAF. Cierra y reinstala la aplicación; el hot reload no carga este componente.');
        }
      } catch (_) {
        if (isMounted) {
          showResult(false, 'No se pudo generar el PDF del certificado.');
        }
      } finally {
        setS(() => generandoPdf = false);
      }
    }

    showDialog(
      context: screenContext,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AppAnimatedDialog(
        child: Dialog(
          backgroundColor: dialogBg,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header empresa
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0D1B4B), width: 2),
                            ),
                            child: Icon(Icons.savings_rounded,
                                color: textMain, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('SAF',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: textMain)),
                                Text('Dirección · Tel: (316) 270-5951',
                                    style: TextStyle(
                                        fontSize: 10, color: textSoft)),
                              ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(fechaFirma,
                                    style: TextStyle(
                                        fontSize: 11, color: textSoft)),
                                Text('Paz y salvo',
                                    style: TextStyle(
                                        fontSize: 11, color: textSoft)),
                              ]),
                        ]),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF0D1B4B), thickness: 1.5),
                    const SizedBox(height: 16),
                    // Título
                    Center(
                      child: Text('CERTIFICADO DE PAZ Y SALVO',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: textMain,
                              letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 20),
                    // Cuerpo
                    RichText(
                        text: TextSpan(
                            style: TextStyle(
                                fontSize: 12, color: textMain, height: 1.6),
                            children: [
                          const TextSpan(
                              text:
                                  'La presente certifica que el(la) señor(a) '),
                          TextSpan(
                              text: cliente,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(
                              text:
                                  ' identificado(a) con cédula de ciudadanía No. '),
                          TextSpan(
                              text: numDoc,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(
                              text:
                                  ' ha cancelado en su totalidad las obligaciones relacionadas con el crédito identificado con número '),
                          TextSpan(
                              text: cod,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ', realizado el dia '),
                          TextSpan(
                              text: fechaPrestamo,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ', por valor de '),
                          TextSpan(
                              text: formatCop(valorPrestamo),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: '.'),
                        ])),
                    const SizedBox(height: 12),
                    if (ultimaPago.isNotEmpty)
                      RichText(
                          text: TextSpan(
                              style: TextStyle(
                                  fontSize: 12, color: textMain, height: 1.6),
                              children: [
                            const TextSpan(
                                text: 'Ultima Fecha de Pago: ',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: '$ultimaPago.'),
                          ])),
                    const SizedBox(height: 12),
                    Text(
                      'Este certificado se expide a solicitud del interesado para los fines que estime convenientes.',
                      style:
                          TextStyle(fontSize: 12, color: textMain, height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'En constancia de lo anterior, se firma a los $fechaFirma.',
                      style:
                          TextStyle(fontSize: 12, color: textMain, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    // Sello
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF1565C0), width: 2),
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
                        Text('Asesor',
                            style: TextStyle(fontSize: 11, color: textSoft)),
                      ])),
                      const SizedBox(width: 32),
                      Expanded(
                          child: Column(children: [
                        const Divider(color: Color(0xFF0D1B4B)),
                        Text('Deudor',
                            style: TextStyle(fontSize: 11, color: textSoft)),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    // Botones: Cerrar + Descargar como PDF
                    Row(children: [
                      Expanded(
                          child: appCancelButton(
                              'Cerrar', () => Navigator.pop(ctx))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4338CA), Color(0xFF2D2A9E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4338CA)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: generandoPdf
                                  ? null
                                  : () => descargarPdf(setS),
                              icon: generandoPdf
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.download_rounded,
                                      size: 18),
                              label: Text(generandoPdf
                                  ? 'Generando…'
                                  : 'Descargar PDF'),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ]),
            ),
          ),
        ),
        );
      }),
    );
  }

  Widget buildPaginationButton(
          IconData icon, bool enabled, VoidCallback onTap) =>
      _PaginationButton(icon: icon, enabled: enabled, onTap: onTap);

  // Cross-fade + deslizamiento del texto "Pág X de Y" al cambiar de página,
  // en vez de saltar de golpe al nuevo valor.
  Widget buildPaginationLabel(String text) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
                    .animate(anim),
            child: child,
          ),
        ),
        child: Text(
          text,
          key: ValueKey(text),
          style: TextStyle(fontSize: 12, color: textSoft),
        ),
      );

  // Tarjeta contenedora compartida por la paginación de Créditos, Pendientes,
  // Movimientos y Ahorros — antes cada pantalla envolvía sus botones de forma
  // distinta (algunas sin tarjeta, otras con); ahora todas usan el mismo marco.
  Widget buildPaginationBar(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cardSheen,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: children),
      );

  Widget buildSaverCard(Map<String, dynamic> a) => ExpandableSaverCard(
      data: a,
      cop: formatCop,
      num: numberValue,
      onCuotaTap: showSavingsInstallmentDialog);

  Widget _creditsSkeleton() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: skelBox(double.infinity, 110, r: 22),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: skelBox(double.infinity, 80, r: 16)),
              const SizedBox(width: 12),
              Expanded(child: skelBox(double.infinity, 80, r: 16)),
            ]),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: skelBox(160, 16, r: 6),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: skelBox(double.infinity, 88, r: 18),
            ),
          ),
        ],
      );
}

// ── Tab de Créditos (Aprobados/Pendientes/Rechazadas/...): press-scale +
// cross-fade fluido ─────────────────────────────────────────────────────────
// Antes el degradado pasaba de `null` a `LinearGradient` de golpe (un color
// "vacío" no interpola bien contra un degradado) y no había feedback táctil
// al tocar — de ahí el micro tirón. Ahora ambos estados usan el mismo
// degradado, solo cambia el alfa, así el cross-fade es suave.
class _CreditoTabButton extends StatefulWidget {
  final bool active;
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color accent;
  final VoidCallback onTap;

  const _CreditoTabButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.gradient,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_CreditoTabButton> createState() => _CreditoTabButtonState();
}

class _CreditoTabButtonState extends State<_CreditoTabButton>
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
    const dur = Duration(milliseconds: 260);
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
          duration: dur,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.active ? widget.gradient : fadedGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.active
                  ? widget.accent.withValues(alpha: 0.55)
                  : lineCol,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    widget.accent.withValues(alpha: widget.active ? 0.38 : 0),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: dur,
              child: Icon(widget.icon,
                  size: 14,
                  key: ValueKey(widget.active),
                  color: widget.active ? Colors.white : textSoft),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: dur,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.active ? Colors.white : textSoft),
              child: Text(widget.label),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Botón de paginación: press-scale + transición fluida activo/inactivo ────
// Compartido por Créditos, Pendientes, Movimientos y Ahorros — antes era un
// GestureDetector plano sin animación, con un cambio de color de golpe al
// (des)habilitarse.
// Punto tipo "LED en vivo": pulso continuo de opacidad + escala, usado en el
// badge de estado "Activo" de la tarjeta de crédito.
class _PulsingDot extends StatefulWidget {
  final Color color;
  static const double size = 8;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  // El punto siempre queda a opacidad plena — solo el halo (boxShadow)
  // respira entre 0.5 y 1.0. Antes el color base también se desvanecía con
  // el pulso, así que en su punto más bajo el LED casi desaparecía sobre el
  // chip translúcido.
  late final Animation<double> _pulse =
      Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: 0.9 + (_pulse.value * 0.25),
        child: Container(
          width: _PulsingDot.size,
          height: _PulsingDot.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _pulse.value * 0.9),
                blurRadius: _PulsingDot.size * 2.0,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_PaginationButton> createState() => _PaginationButtonState();
}

class _PaginationButtonState extends State<_PaginationButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.88,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      onTapDown: enabled ? (_) => _press.reverse() : null,
      onTapUp: enabled
          ? (_) {
              _press.forward();
              widget.onTap();
            }
          : null,
      onTapCancel: enabled ? () => _press.forward() : null,
      child: ScaleTransition(
        scale: _press,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [
                      Color.lerp(btnPrimary, Colors.white, 0.16) ?? btnPrimary,
                      btnPrimary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : inputFill,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: btnPrimary.withValues(alpha: 0.38),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.icon,
              key: ValueKey(enabled),
              color: enabled ? Colors.white : textSoft,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated delete-confirmation dialog ─────────────────────────────────────
class _EliminarCreditoDialog extends StatefulWidget {
  const _EliminarCreditoDialog({
    required this.cod,
    required this.cliente,
    this.titulo = 'Eliminar crédito',
    this.etiquetaItem = 'Crédito',
  });
  final String cod;
  final String cliente;
  final String titulo;
  final String etiquetaItem;

  @override
  State<_EliminarCreditoDialog> createState() => _EliminarCreditoDialogState();
}

class _EliminarCreditoDialogState extends State<_EliminarCreditoDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _iconCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconWiggle;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _scale = Tween<double>(begin: 0.90, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _iconCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)));
    _iconWiggle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
        parent: _iconCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeInOut)));

    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _iconCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Ícono de advertencia (neutro, con leve acento rojo) ──
                AnimatedBuilder(
                  animation: _iconCtrl,
                  builder: (context, child) => Transform.scale(
                    scale: _iconScale.value,
                    child: Transform.rotate(
                        angle: _iconWiggle.value, child: child),
                  ),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDarkTheme
                          ? const Color(0xFFDC2626).withValues(alpha: 0.16)
                          : const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDarkTheme
                              ? const Color(0xFFDC2626).withValues(alpha: 0.45)
                              : const Color(0xFFFCA5A5),
                          width: 1.5),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444), size: 30),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.titulo,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                        letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Text('Esta acción no se puede deshacer',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textSoft)),
                const SizedBox(height: 20),
                // Credit info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBgAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lineCol),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: chipIndigo,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.credit_card_rounded,
                          color: btnPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.etiquetaItem} #${widget.cod}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: textMain)),
                            const SizedBox(height: 2),
                            Text(widget.cliente,
                                style:
                                    TextStyle(fontSize: 12, color: textSoft)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                // Buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: isDarkTheme
                                  ? lineCol
                                  : const Color(0xFFCBD5E1),
                              width: isDarkTheme ? 1 : 1.4),
                        ),
                        child: Text('Cancelar',
                            style: TextStyle(
                                color: textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFDC2626).withValues(alpha: 0.32),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Eliminar',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
