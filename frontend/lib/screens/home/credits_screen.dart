// ignore_for_file: use_build_context_synchronously

import '../../controllers/home_actions.dart';
import '../../controllers/home_data_controller.dart';
import '../../widgets/home/home_dialogs.dart';
import 'package:http/http.dart' as http;
import 'dashboard_screen.dart';
import 'home_dependencies.dart';
import 'movements_screen.dart';
import 'savings_screen.dart';

extension HomeCreditsScreen<T extends StatefulWidget> on HomeController<T> {
  Widget buildCreditsScreen() {
    if (loadingData) return buildLoadingView();

    // Totales globales (todos los registros del filtro, no solo la página actual)
    final totalPagado = creditsPaidTotal;
    final totalPendiente = creditsPendingTotal;

    final creditosFiltrados = credits;

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
                        Text(formatCop(totalPagado),
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
                          Text(formatCop(totalPendiente),
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
        if (creditSubTab == 0)
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
                              color: homeNavy)),
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
                            value: advisors.any((a) =>
                                    (a['sigla'] ?? '').toString() ==
                                    creditAdvisorFilter)
                                ? creditAdvisorFilter
                                : null,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            hint: const Text('Todos',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF8899BB))),
                            style:
                                const TextStyle(fontSize: 12, color: homeNavy),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: Color(0xFF8899BB)),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos',
                                      style: TextStyle(color: homeNavy))),
                              ...advisors.map((a) {
                                final sigla = (a['sigla'] ??
                                        a['codigo_asesor'] ??
                                        a['codigo'] ??
                                        '')
                                    .toString()
                                    .trim();
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
                                        style:
                                            const TextStyle(color: homeNavy)));
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
                                  refresh(() => queryingCredits = false);
                                }
                              }
                            },
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
                              color: homeNavy)),
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
                            value: creditStatusFilter.isEmpty
                                ? null
                                : creditStatusFilter,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            hint: const Text('Todos',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF8899BB))),
                            style:
                                const TextStyle(fontSize: 12, color: homeNavy),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: Color(0xFF8899BB)),
                            items: const [
                              DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos',
                                      style: TextStyle(color: homeNavy))),
                              DropdownMenuItem(
                                  value: '1',
                                  child: Text('Activo',
                                      style: TextStyle(color: homeNavy))),
                              DropdownMenuItem(
                                  value: '2',
                                  child: Text('Pagado',
                                      style: TextStyle(color: homeNavy))),
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
                                  refresh(() => queryingCredits = false);
                                }
                              }
                            },
                          ),
                        ),
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
                            colors: [Color(0xFF4338CA), Color(0xFF2D2A9E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    color: queryingCredits ? const Color(0xFFE2E8F0) : null,
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
                  children:
                      creditosFiltrados.map((c) => _creditoCard(c)).toList()),
            ),
          if (creditsTotal > creditsPageSize)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                buildPaginationButton(
                    Icons.chevron_left_rounded, creditsPage > 1, () async {
                  refresh(() => creditsPage--);
                  await fetchCredits('');
                  if (isMounted) refresh(() {});
                }),
                const SizedBox(width: 8),
                Expanded(
                    child: Center(
                        child: Text(
                  'Pág $creditsPage de ${((creditsTotal - 1) ~/ creditsPageSize) + 1}  ·  $creditsTotal registros',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF8899BB)),
                ))),
                const SizedBox(width: 8),
                buildPaginationButton(Icons.chevron_right_rounded,
                    creditsPage * creditsPageSize < creditsTotal, () async {
                  refresh(() => creditsPage++);
                  await fetchCredits('');
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
          else if (pendingRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildEmptyActivity(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                  children:
                      pendingRequests.map((p) => _pendienteCard(p)).toList()),
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
              child: Row(children: [
                buildPaginationButton(
                    Icons.chevron_left_rounded, pendingPage > 1, () async {
                  refresh(() => pendingPage--);
                  await fetchPending();
                  if (isMounted) refresh(() {});
                }),
                const SizedBox(width: 8),
                Expanded(
                    child: Center(
                        child: Text(
                  'Pág $pendingPage de ${((pendingTotal - 1) ~/ creditsPageSize) + 1}  ·  $pendingTotal solicitudes',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF8899BB)),
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
            _simLabel('Tiempo en Meses: ${simulationMonths.round()}'),
            Slider(
              value: simulationMonths,
              min: 1,
              max: 24,
              divisions: 23,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => refresh(() => simulationMonths = v),
            ),
            const SizedBox(height: 8),
            _simLabel('Monto solicitado: ${formatCop(simulationAmount)}'),
            Slider(
              value: simulationAmount,
              min: 100000,
              max: 3000000,
              divisions: 29,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => refresh(() => simulationAmount = v),
            ),
            const SizedBox(height: 8),
            _simLabel('Tasa interés: ${simulationRate.round()}'),
            Slider(
              value: simulationRate,
              min: 5,
              max: 20,
              divisions: 15,
              activeColor: const Color(0xFF3B3B8A),
              onChanged: (v) => refresh(() => simulationRate = v),
            ),
            const SizedBox(height: 16),

            // ── Fecha Desde / Hasta ──────────────────────────
            Row(children: [
              Expanded(
                child: _simDateField('Fecha Desde', simulationFrom, (d) {
                  refresh(() => simulationFrom = d);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _simDateField('Fecha Hasta', simulationTo, (d) {
                  refresh(() => simulationTo = d);
                }),
              ),
            ]),
            if (simulationFrom != null && simulationTo != null) ...[
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
                  Text(formatCop(cuotaReal),
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
                _simResultRow('Valor Diaria', formatCop(valorDiario)),
                if (dias > 0)
                  _simResultRow('Valor total con intereses diarios',
                      formatCop(valorTotalDiario)),
                _simResultRow(
                    '$meses Cuota(s) Mensual(es)', formatCop(cuotaMensual)),
                _simResultRow('${meses * 2} Cuota(s) Quincenal(es)',
                    formatCop(cuotaQuincenal)),
                _simResultRow('Valor a Pagar', formatCop(valorAPagar),
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
    double salidasOf(Map<String, dynamic> d) => numberValue(d['total_salidas']);
    double entradasOf(Map<String, dynamic> d) =>
        numberValue(d['total_entradas']);

    String fmtDate(DateTime? d) => d == null
        ? 'dd/mm/aaaa'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    // Fuentes = cuentas registradas (igual que la web)
    final fuenteItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '0', child: Text('Todas las fuentes')),
      ...accounts.map((c) {
        final label = (c['nombre'] ?? '').toString();
        final codigo = (c['codigo'] ?? '0').toString();
        return DropdownMenuItem(
            value: codigo, child: Text(label, overflow: TextOverflow.ellipsis));
      }),
    ];

    Future<void> pickDate(bool isDesde) async {
      final picked = await showDatePicker(
        context: screenContext,
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
    const borderCol = Color(0xFFE2E8F0);
    const bgField = Color(0xFFF8F9FC);
    const hintCol = Color(0xFF94A3B8);

    InputDecoration fieldDeco(String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: hintCol),
          prefixIcon: Icon(icon, size: 16, color: hintCol),
          filled: true,
          fillColor: bgField,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderCol)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderCol)),
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
                          color: val == null ? hintCol : homeNavy))),
              if (val != null)
                GestureDetector(
                    onTap: () => refresh(() {
                          if (label.contains('desde')) {
                            sourceStatisticsFrom = null;
                          } else {
                            sourceStatisticsTo = null;
                          }
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.bar_chart_rounded,
                    color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Balance por Fuente',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
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
              initialValue:
                  sourceStatisticsStatus.isEmpty ? '' : sourceStatisticsStatus,
              decoration: fieldDeco('Estado', Icons.filter_list_rounded),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: hintCol),
              style: const TextStyle(fontSize: 13, color: homeNavy),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(value: '1', child: Text('Activos')),
                DropdownMenuItem(value: '2', child: Text('Pagados')),
                DropdownMenuItem(value: '3', child: Text('Pendientes')),
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
                    const Text('Desde',
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
                    const Text('Hasta',
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
              initialValue: sourceStatisticsAccount,
              decoration: fieldDeco('Fuente', Icons.account_balance_outlined),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: hintCol),
              style: const TextStyle(fontSize: 13, color: homeNavy),
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
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1A3170)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: homeNavy.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                    child: sourceStatisticsLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.bar_chart_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Mostrar Gráficos',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ])),
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
            barColor: const Color(0xFF3B3B8A),
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
                      color: homeNavy))),
        ]),
        const SizedBox(height: 12),
        // Barras horizontales con color por fuente
        ...sorted.map((d) {
          final val = valueFn(d);
          final pct = val / maxVal;
          final name = labelFn(d);
          final rowColor = parseHexColor(
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
                child: Text(formatCop(val),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: homeNavy)),
              ),
            ]),
          );
        }),
        const Divider(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$totalLabel:',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: homeNavy)),
          Text(formatCop(total),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: barColor)),
        ]),
      ]),
    );
  }

  Widget _creditoTabBtn(int index, String label, IconData icon) {
    final active = creditSubTab == index;
    const dur = Duration(milliseconds: 180);
    const activeColor = Colors.white;
    const inactiveColor = Color(0xFF8899BB);
    return GestureDetector(
      onTap: () {
        refresh(() => creditSubTab = index);
        if (index == 1) unawaited(fetchPending());
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
            context: screenContext,
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
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
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
            final ok = r.statusCode == 200 &&
                r.body.toLowerCase().contains('registrado');
            if (ctx.mounted) Navigator.pop(ctx);
            if (isMounted) {
              showDialog(
                context: screenContext,
                builder: (_) => buildResultDialog(
                  ok ? 'Deudor creado exitosamente' : r.body.trim(),
                  ok,
                ),
              );
              if (ok) {
                repository.invalidateCache('/ajax/listado_json_campos.php');
                final u = repository.user;
                await fetchCredits(u?['codigo_usuario']?.toString() ?? '');
                if (isMounted) refresh(() {});
              }
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
                  buildDialogRow(
                    'Asesor',
                    buildDialogDropdown<String>(
                      value: selectedAsesor,
                      items: advisorNames.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setS(() => selectedAsesor = v),
                      validator: (v) =>
                          v == null ? 'Seleccione un asesor' : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildDialogRow(
                      'N° Documento',
                      buildDialogField(docCtrl,
                          required: true, keyboard: TextInputType.number)),
                  const SizedBox(height: 8),
                  buildDialogRow(
                      'Nombres', buildDialogField(nombresCtrl, required: true)),
                  const SizedBox(height: 8),
                  buildDialogRow('Apellidos',
                      buildDialogField(apellidosCtrl, required: true)),
                  const SizedBox(height: 8),
                  buildDialogRow('Dirección', buildDialogField(direccionCtrl)),
                  const SizedBox(height: 8),
                  buildDialogRow(
                      'Telefono',
                      buildDialogField(telefonoCtrl,
                          keyboard: TextInputType.phone)),
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
                      color: homeNavy,
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
                      style: const TextStyle(color: homeNavy, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Nombre del deudor... (${debtors.length} registrados)',
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
                                            style: const TextStyle(
                                              color: homeNavy,
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
    bool loadingDeudores = debtors.isEmpty;
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
      if (rates.isNotEmpty) {
        return rates
            .map((t) =>
                (t['tasa'] ?? t['valor'] ?? t['nombre'] ?? '').toString())
            .where((t) => t.isNotEmpty)
            .toList();
      }
      return ['0%', '8%', '10%', '15%', '17.5%', '18%', '20%'];
    }

    // Fuentes: de la API o fallback
    List<String> fuenteOpciones() {
      if (sources.isNotEmpty) {
        return sources
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

            // Siempre refrescar desde API para obtener la lista completa
            await Future.wait([
              fetchDebtors(),
              if (rates.isEmpty) fetchRates(),
              if (sources.isEmpty) fetchSources(),
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
              'total_pagar': totalAPagar.toStringAsFixed(0),
            });
            final ok =
                r.statusCode == 200 && r.body.toLowerCase().contains('creado');
            if (ctx.mounted) Navigator.pop(ctx);
            if (isMounted) {
              showDialog(
                context: screenContext,
                builder: (_) => buildResultDialog(
                  ok ? 'Crédito creado exitosamente' : r.body.trim(),
                  ok,
                ),
              );
              if (ok) {
                repository.invalidateCache('/ajax/listado_json_campos.php');
                final u = repository.user;
                await fetchCredits(u?['codigo_usuario']?.toString() ?? '');
                if (isMounted) refresh(() {});
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
                  buildDialogRow(
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
                                ? homeAccent.withValues(alpha: 0.5)
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
                                  ? homeAccent
                                  : const Color(0xFF9CA3AF),
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
                              style: dialogTextStyle.copyWith(
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
                  buildDialogRow(
                    'Valor Préstamo',
                    TextFormField(
                      controller: valorCtrl,
                      decoration: dialogInputDecoration(),
                      keyboardType: TextInputType.number,
                      style: dialogTextStyle,
                      onChanged: (_) => recalcTotal(setS),
                      validator: (v) => (v == null || v.trim().isEmpty)
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
                  buildDialogRow(
                    'Número de Cuotas',
                    TextFormField(
                      controller: numCuotasCtrl,
                      decoration: dialogInputDecoration(),
                      keyboardType: TextInputType.number,
                      style: dialogTextStyle,
                      onChanged: (_) => recalcTotal(setS),
                      validator: (v) => (v == null || v.trim().isEmpty)
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
                          .map((o) =>
                              DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                          .toList(),
                      onChanged: (v) => setS(() => selectedTipoInt = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tasa Interés
                  buildDialogRow(
                    'Tasa interés',
                    buildDialogDropdown<String>(
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
                  buildDialogRow(
                    'Fuente',
                    buildDialogDropdown<String>(
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
                  buildDialogRow(
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
                        totalAPagar > 0 ? formatCop(totalAPagar) : '',
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
  Widget buildResultDialog(String msg, bool ok) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ok
                      ? [const Color(0xFF059669), const Color(0xFF34D399)]
                      : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ok ? Icons.check_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ok ? '¡Operación exitosa!' : 'Algo salió mal',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B4B)),
            ),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(screenContext),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: ok
                        ? [const Color(0xFF059669), const Color(0xFF34D399)]
                        : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (ok
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626))
                          .withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('Aceptar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ),
          ]),
        ),
      );

  String friendlyError(dynamic e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (RegExp(r'\b(400|401|403|404|500|502|503|504)\b').hasMatch(raw)) {
      return 'No se pudo completar la operación. Por favor intenta de nuevo.';
    }
    if (raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('connection') ||
        raw.toLowerCase().contains('network')) {
      return 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
    }
    if (raw.toLowerCase().contains('timeout')) {
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
  Widget _creditoCard(Map<String, dynamic> c) {
    final cod = c['cod']?.toString() ?? '';
    final asesor = (() {
      final nombre = (c['asesor'] ?? '').toString().trim();
      final aCod = (c['asesor_cod'] ?? '').toString().trim();
      final sigla = creditAdvisorInitials(aCod).trim();
      return sigla.isNotEmpty ? sigla : nombre;
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

    bool vencido = false;
    if (activo && proxima.isNotEmpty) {
      try {
        vencido = DateTime.parse(proxima).isBefore(DateTime.now());
      } catch (_) {}
    }

    final cardKey = cod.isNotEmpty ? cod : nombre;
    final expanded = expandedCredits.contains(cardKey);

    final Color accent = !activo
        ? const Color(0xFF16A34A)
        : vencido
            ? const Color(0xFFDC2626)
            : homeNavy;

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
            : homeNavy;

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
      onTap: () => refresh(() => expanded
          ? expandedCredits.remove(cardKey)
          : expandedCredits.add(cardKey)),
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
                            color: homeNavy)),
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
                    Text(formatCop(pendiente),
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
                          color: vencido ? const Color(0xFFDC2626) : homeNavy)),
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
                  Expanded(
                      child: _statMini('Crédito', formatCop(monto), homeNavy)),
                  Expanded(
                      child: _statMini(
                          'A Pagar', formatCop(totalPagar), homeNavy)),
                  Expanded(
                      child: _statMini('Pagado', formatCop(pagado),
                          const Color(0xFF16A34A))),
                  Expanded(
                      child: _statMini('Pendiente', formatCop(pendiente),
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
                          homeNavy, () => _showCuotasDialog(c))),
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
                fontSize: 10, color: homeNavy, fontWeight: FontWeight.w600)),
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
                      color: homeNavy))),
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
              child: Text(formatCop(valor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: homeNavy))),
          // Lápiz editar (siempre visible)
          _miniIconBtn(Icons.edit_rounded, homeNavy,
              () => _showEditarSolicitudDialog(p)),
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
            ]);
            if (ctx.mounted) setS(() {});
          });
        }

        List<String> fuenteOpciones() {
          if (sources.isNotEmpty) {
            return sources
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
                  style: const TextStyle(fontSize: 13, color: homeNavy),
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
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: hintCol),
                  style: const TextStyle(fontSize: 13, color: homeNavy),
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
                                ...advisors.map((a) {
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
        creditAdvisorFilter.isNotEmpty ? creditAdvisorFilter : null;

    // Si no hay asesor preseleccionado, pedir al usuario
    if (asesorSel == null && advisors.isNotEmpty) {
      asesorSel = await showDialog<String>(
        context: screenContext,
        builder: (ctx) {
          String? tmp = advisors.first['sigla']?.toString() ?? '';
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
                          items: advisors.map((a) {
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
                    final valorPago = numberValue(q['valor_pago'] ?? 0);
                    final valorPagado = numberValue(q['valor_pagado'] ?? 0);
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
                            child: Text(formatCop(valorPago),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: txt))),
                        Expanded(
                            flex: 3,
                            child: Text(
                                valorPagado > 0 ? formatCop(valorPagado) : '',
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
                                      repository.post(
                                          '/ajax/get_cuotas_credito.php',
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
                                      repository.post(
                                          '/ajax/get_cuotas_credito.php',
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
                  ...fuentesPago.map((f) {
                    return DropdownMenuItem(
                      value: f['codigo'],
                      child:
                          Text(f['nombre']!, overflow: TextOverflow.ellipsis),
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
                        showResult(false,
                            'Ingresa el valor del pago antes de continuar');
                        return;
                      }
                      if (fuente.isEmpty) {
                        showResult(false,
                            'Selecciona la fuente donde ingresó el pago');
                        return;
                      }
                      setS(() => saving = true);
                      final r = await repository
                          .post('/ajax/registrar_cuota_credito.php', {
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
                  : const Text('Grabar'),
            ),
          ],
        );
      }),
    );
  }

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
                      final r =
                          await repository.post('/ajax/editar_cuota.php', {
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
                      if (ok) {
                        Navigator.pop(ctx);
                        onSaved();
                      }
                      showResult(
                          ok,
                          ok
                              ? 'Cuota actualizada correctamente'
                              : friendlyError(r.body));
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
      showResult(false,
          'El crédito #$cod no tiene un número de WhatsApp válido registrado.');
      return;
    }

    final mensaje = vencidas > 0
        ? 'Hola Sr(a) $cliente, tienes $vencidas cuota(s) vencida(s), recuerde que su fecha de pago'
            '${proxima.isNotEmpty ? ' es $proxima' : ' ya se encuentra vencida'}.'
        : 'Hola Sr(a) $cliente, le recordamos que su próxima fecha de pago'
            '${proxima.isNotEmpty ? ' es $proxima' : ' está próxima'}.';

    if (!isMounted) return;
    showDialog<void>(
      context: screenContext,
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

    if (!isMounted) return;
    Navigator.of(screenContext, rootNavigator: true).pop();
    showResult(enviado, resultado);
  }

  // ── Confirmar eliminar ───────────────────────────────────────────
  Future<void> _confirmarEliminarCredito(Map<String, dynamic> credito) async {
    final cod = credito['cod']?.toString() ?? '';
    final cliente = (credito['cliente'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: screenContext,
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
    if (ok != true || !isMounted) return;
    final r = await repository
        .post('/ajax/eliminar_credito.php', {'codigo_credito': cod});
    if (!isMounted) return;
    final exito =
        r.statusCode == 200 && r.body.toLowerCase().contains('eliminado');
    showResult(
        exito,
        exito
            ? 'Crédito #$cod eliminado exitosamente'
            : 'No se pudo eliminar el crédito. Por favor intenta de nuevo.');
    if (exito) {
      repository.invalidateCache('/ajax/get_creditos_lista.php');
      await fetchCredits('');
      if (isMounted) refresh(() {});
    }
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

    showDialog(
      context: screenContext,
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
                        text: formatCop(valorPrestamo),
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

  Widget buildPaginationButton(
          IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? homeNavy : const Color(0xFFE2E8F0),
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

  Widget buildSaverCard(Map<String, dynamic> a) => ExpandableSaverCard(
      data: a,
      cop: formatCop,
      num: numberValue,
      onCuotaTap: showSavingsInstallmentDialog);
}
