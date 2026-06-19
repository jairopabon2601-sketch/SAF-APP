// ignore_for_file: use_build_context_synchronously

import '../../controllers/home_data_controller.dart';
import '../../widgets/home/home_dialogs.dart';
import 'credits_screen.dart';
import 'dashboard_screen.dart';
import 'home_dependencies.dart';
import 'savings_screen.dart';

extension HomeMovementsScreen<T extends StatefulWidget> on HomeController<T> {
  Widget buildMovementsScreen() {
    if (loadingData) return buildLoadingView();

    final filtrados = filteredMovements;
    final isMovementsLoading =
        accountFilter.isNotEmpty && selectedAccountMovementsLoading;

    // Check if dates differ from the 31-day defaults
    final now = DateTime.now();
    final defaultDesde = now.subtract(const Duration(days: 31));
    final datesAreDefault = filterFrom == null ||
        (filterFrom!.difference(defaultDesde).inDays.abs() <= 1 &&
            (filterTo == null || filterTo!.difference(now).inDays.abs() <= 1));
    final hasUserFilter = accountFilter.isNotEmpty ||
        movementTypeFilter.isNotEmpty ||
        !datesAreDefault;

    // Server totals: default range → serverExpenses/serverIncome; filtered → filteredExpenses/filteredIncome
    final gastos = hasUserFilter
        ? (filteredTotalsLoaded
            ? filteredExpenses
            : filtrados
                .where((m) => (m['tipo_movimiento'] ?? '').toString() == '2')
                .fold(0.0, (s, m) => s + numberValue(m['valor'] ?? 0)))
        : (serverTotalsLoaded ? serverExpenses : 0.0);
    final ingresos = hasUserFilter
        ? (filteredTotalsLoaded
            ? filteredIncome
            : filtrados.where((m) {
                final t = (m['tipo_movimiento'] ?? '').toString();
                return t == '3' || t == '1';
              }).fold(0.0, (s, m) => s + numberValue(m['valor'] ?? 0)))
        : (serverTotalsLoaded ? serverIncome : 0.0);
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

        if (movementSubTab == 0) ...[
          // ── CUENTAS: botones de acción ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(children: [
              buildActionButton(
                label: '+ Nueva Cuenta/Fuente',
                color: const Color(0xFF10B981),
                onTap: () => _showNuevaCuentaDialog(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: buildActionButton(
                  label: '⇄ Movimientos',
                  color: homeNavy,
                  onTap: () => _showRegistrarMovimientoDialog(),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: buildActionButton(
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
                    formatCop(accounts.fold(0.0,
                        (s, c) => s + numberValue(c['saldo_actual'] ?? 0))),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
          // Lista de cuentas
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildEmptyActivity(),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _cuentaRowReal(accounts[i]),
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
            child: Container(
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
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.55),
                      blurRadius: 32,
                      spreadRadius: -4,
                      offset: const Offset(0, 14)),
                  BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                      blurRadius: 48,
                      offset: const Offset(0, 6)),
                ],
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
                        const Text('Balance del período',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: isMovementsLoading
                              ? _movementSkeletonBox(
                                  width: 42,
                                  height: 10,
                                  color: Colors.white.withValues(alpha: 0.22),
                                )
                              : Text('${filtrados.length} mov.',
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
                                        ? Colors.white
                                        : const Color(0xFFF87171),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                    shadows: [
                                      Shadow(
                                        color: (balance >= 0
                                                ? const Color(0xFF6366F1)
                                                : const Color(0xFFDC2626))
                                            .withValues(alpha: 0.4),
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
                    ],
                  ),
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
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF059669).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 7),
                          Text('Nuevo Movimiento',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showTransferirDialog(),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.40),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ],
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
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  if (hasUserFilter) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color:
                              const Color(0xFF6EE7B7).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('activo',
                          style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF6EE7B7),
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  if (hasUserFilter)
                    GestureDetector(
                      onTap: () => refresh(() {
                        accountFilter = '';
                        movementTypeFilter = '';
                        filterFrom = null;
                        filterTo = null;
                        filteredTotalsLoaded = false;
                        movementsPage = 1;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2))),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(children: [
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _filterDropdown<String>(
                      label: 'Cuenta',
                      value: accountFilter.isEmpty ? null : accountFilter,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Todas')),
                        ...accounts.map((c) => DropdownMenuItem(
                              value: (c['nombre'] ?? '').toString(),
                              child: Text((c['nombre'] ?? '').toString(),
                                  overflow: TextOverflow.ellipsis),
                            )),
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
                      value: movementTypeFilter.isEmpty
                          ? null
                          : movementTypeFilter,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Todos')),
                        DropdownMenuItem(value: '2', child: Text('Gasto')),
                        DropdownMenuItem(value: '3', child: Text('Ingreso')),
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
                        refresh(() {
                          filterTo = d;
                          filteredTotalsLoaded = false;
                          movementsPage = 1;
                        });
                        unawaited(onDateFilterChanged());
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
                  child: isMovementsLoading
                      ? _movementSkeletonBox(
                          width: 54,
                          height: 11,
                          color: const Color(0xFFCBD5F5),
                        )
                      : Text('${filtrados.length} registros',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4361EE),
                              fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          if (isMovementsLoading)
            _movementsLoadingSkeleton()
          else if (filtrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildEmptyActivity(),
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
              return Column(children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                    children: pagina
                        .asMap()
                        .entries
                        .map((e) => buildMovementItem(e.value,
                            divider: e.key < pagina.length - 1))
                        .toList(),
                  ),
                ),
                if (totalPags > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(children: [
                      buildPaginationButton(Icons.chevron_left_rounded, pag > 1,
                          () {
                        refresh(() => movementsPage = pag - 1);
                      }),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Pág $pag de $totalPags  ·  ${filtrados.length} registros',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF8899BB)),
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

  Widget _movementsLoadingSkeleton() => Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: List.generate(
            6,
            (index) => Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: index < 5
                    ? const Border(
                        bottom: BorderSide(color: Color(0xFFE8EDF6)),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  _movementSkeletonBox(width: 42, height: 42, radius: 13),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _movementSkeletonBox(
                          width: index.isEven ? 130 : 105,
                          height: 13,
                        ),
                        const SizedBox(height: 8),
                        _movementSkeletonBox(width: 115, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _movementSkeletonBox(width: 72, height: 13),
                      const SizedBox(height: 8),
                      _movementSkeletonBox(width: 48, height: 18, radius: 9),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _movementSkeletonBox({
    required double width,
    required double height,
    double radius = 6,
    Color? color,
  }) =>
      AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) {
          final skeletonColor = color ??
              Color.lerp(
                const Color(0xFFE3E8F2),
                const Color(0xFFF2F5FA),
                shimmer.value,
              )!;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(radius),
            ),
          );
        },
      );

  Widget buildActionButton({
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

  Widget _filterDropdown<ValueType>({
    required String label,
    required ValueType? value,
    required List<DropdownMenuItem<ValueType>> items,
    required ValueChanged<ValueType?> onChanged,
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
            child: DropdownButton<ValueType>(
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
              context: screenContext,
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
        dropdownColor: Colors.white,
        style: dialogTextStyle,
        hint: Text(hint ?? '[Seleccione]', style: dialogHintStyle),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            size: 18, color: Color(0xFF9CA3AF)),
        items: items,
        onChanged: onChanged,
        validator: validator,
      );

  InputDecoration dialogInputDecoration() => InputDecoration(
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

  Widget _subTab(int index, String label) => Expanded(
        child: GestureDetector(
          onTap: () => refresh(() => movementSubTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:
                  movementSubTab == index ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: movementSubTab == index
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
                  color: movementSubTab == index
                      ? homeNavy
                      : const Color(0xFF8899BB),
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
                  readonlyField('Saldo Actual', formatCop(saldoActual)),
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
                                  final r = await repository
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
                                    final d = decodeJsonMap(r.body);
                                    final ok = d['success'] == true ||
                                        d['resultado'] == 1;
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    showResult(
                                        ok,
                                        ok
                                            ? 'Saldo ajustado correctamente.'
                                            : friendlyError(d['msg'] ??
                                                d['mensaje'] ??
                                                'No se pudo ajustar el saldo'));
                                    if (ok) unawaited(loadData());
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
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
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
                                  showResult(
                                      false, 'Seleccione la cuenta de origen');
                                  return;
                                }
                                if (destinoCod == null) {
                                  showResult(
                                      false, 'Seleccione la cuenta de destino');
                                  return;
                                }
                                if (origenCod == destinoCod) {
                                  showResult(false,
                                      'La cuenta de origen y destino no pueden ser la misma');
                                  return;
                                }
                                if (!formKey.currentState!.validate()) return;
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
                                  if (r.statusCode == 200) {
                                    final d = decodeJsonMap(r.body);
                                    final ok = d['success'] == true ||
                                        d['resultado'] == 1;
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    showResult(
                                        ok,
                                        ok
                                            ? 'Transferencia realizada correctamente.'
                                            : friendlyError(d['msg'] ??
                                                d['mensaje'] ??
                                                'No se pudo completar la transferencia'));
                                    if (ok) unawaited(loadData());
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
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
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
                                    if (ok) unawaited(loadData());
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
                              color: homeNavy)),
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
                          color: homeNavy)),
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
                          color: homeNavy)),
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
                                color: sel ? homeNavy : Colors.transparent,
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
                          color: homeNavy)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDialog<Map<String, dynamic>>(
                        context: ctx,
                        builder: (dCtx) => SimpleDialog(
                          backgroundColor: Colors.white,
                          title: const Text('Seleccionar Tipo',
                              style: TextStyle(
                                  color: homeNavy,
                                  fontWeight: FontWeight.w700)),
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
                                ? homeAccent.withValues(alpha: 0.6)
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
                                    ? homeNavy
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
                                  showResult(
                                      false, 'Selecciona el tipo de cuenta');
                                  return;
                                }
                                setS(() => saving = true);
                                try {
                                  final r = await repository
                                      .post('/ajax/guardar_cuenta_gasto.php', {
                                    'nombre': nombreCtrl.text.trim(),
                                    'color': selectedHex,
                                    'tipo_cuenta': selectedTipo!,
                                    'usuario': codigoUsuario,
                                  });
                                  final d = decodeJsonMap(r.body);
                                  final ok = d['success'] == true;
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (ok) unawaited(fetchAccounts('1'));
                                  showResult(
                                      ok,
                                      ok
                                          ? (d['msg']?.toString() ??
                                              'Cuenta creada exitosamente')
                                          : friendlyError(d['msg'] ??
                                              'No se pudo guardar la cuenta'));
                                } catch (e) {
                                  if (ctx.mounted) setS(() => saving = false);
                                  showResult(false, friendlyError(e));
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
              movsList = await fetchAccountMovements(codigo, codigoUsuario);
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
                                style: const TextStyle(
                                    color: homeNavy, fontSize: 14),
                                decoration: InputDecoration(
                                  prefixText: '#',
                                  prefixStyle: const TextStyle(
                                      color: homeAccent,
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
                                    final picked =
                                        await showDialog<Map<String, dynamic>>(
                                      context: ctx,
                                      builder: (dCtx) => SimpleDialog(
                                        backgroundColor: Colors.white,
                                        title: const Text('Seleccionar Tipo',
                                            style: TextStyle(
                                                color: homeNavy,
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
                                                          color: homeNavy,
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
                                builder: (dCtx) => SimpleDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('Estado',
                                      style: TextStyle(
                                          color: homeNavy,
                                          fontWeight: FontWeight.w700)),
                                  children: [
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(dCtx, '1'),
                                      child: const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Activa',
                                              style: TextStyle(
                                                  color: homeNavy,
                                                  fontSize: 14))),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(dCtx, '0'),
                                      child: const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Inactiva',
                                              style: TextStyle(
                                                  color: homeNavy,
                                                  fontSize: 14))),
                                    ),
                                  ],
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
                                  builder: (c2) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text('¿Desactivar cuenta?',
                                        style: TextStyle(color: homeNavy)),
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
                                      ok =
                                          jsonDecode(r.body)['success'] == true;
                                    } catch (_) {}
                                    showDialog(
                                      context: screenContext,
                                      builder: (_) => buildResultDialog(
                                          ok
                                              ? 'Cuenta desactivada'
                                              : 'No se pudo desactivar',
                                          ok),
                                    );
                                    if (ok) unawaited(fetchAccounts('1'));
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
                                  showResult(
                                      false, 'Ingrese el nombre de la cuenta');
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
                                  bool ok = false;
                                  String msg = 'No se pudo guardar';
                                  try {
                                    final j = jsonDecode(r.body.trim());
                                    ok = j['success'] == true;
                                    msg = (j['msg'] ?? msg).toString();
                                  } catch (_) {}
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  showResult(
                                      ok,
                                      ok
                                          ? 'Cambios guardados exitosamente'
                                          : friendlyError(msg));
                                  if (ok) unawaited(fetchAccounts('1'));
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
                              child:
                                  CircularProgressIndicator(color: homeAccent),
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
                                                color: homeNavy))),
                                    Expanded(
                                        flex: 1,
                                        child: Text('Tipo',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: homeNavy))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('Valor',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: homeNavy))),
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
                                      final valor = numberValue(
                                          m['valor'] ?? m['monto'] ?? 0);
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
                                                          color: homeNavy))),
                                              Expanded(
                                                  flex: 1,
                                                  child: Text(tipo,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(
                                                              0xFF8899BB)))),
                                              Expanded(
                                                  flex: 2,
                                                  child: Text(formatCop(valor),
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

  double accountBalance(Map<String, dynamic> cuenta) => numberValue(
      cuenta['saldo_actual'] ?? cuenta['saldo'] ?? cuenta['balance'] ?? 0);

  Widget _cuentaRowReal(Map<String, dynamic> c) {
    final nombre = (c['nombre'] ?? 'Cuenta').toString();
    final tipo = (c['tipo_nombre'] ?? '').toString();
    final saldo = accountBalance(c);
    final estado = c['estado']?.toString() == '1';
    final hexColor = (c['color'] ?? '#4361EE').toString();
    final color = parseHexColor(hexColor);

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
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: homeNavy)),
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
          Text(formatCop(saldo),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: saldo >= 0 ? homeNavy : const Color(0xFFDC2626))),
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

  Widget buildMovementItem(Map<String, dynamic> m, {bool divider = false}) {
    final desc = (m['descripcion'] ?? 'Movimiento').toString();
    final cuentaNom = (m['cuenta_nombre'] ?? '').toString();
    final hexColor = (m['cuenta_color'] ?? '#4361EE').toString();
    final color = parseHexColor(hexColor);
    final tipo = (m['tipo_movimiento'] ?? '2').toString();
    // 2=Gasto, 3=Ingreso/Transferencia, 1=otro
    final isIngreso = tipo == '3' || tipo == '1';
    final valor = numberValue(m['valor'] ?? 0);
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
                        color: homeNavy)),
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
                '${isIngreso ? '+' : '-'}${formatCop(valor)}',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
    final ctx = screenContext;
    final desc = (m['descripcion'] ?? 'este movimiento').toString();
    // PK field is 'codigo' as returned by listar_movimientos_cuenta.php
    final cod = (m['codigo'] ?? m['codigo_movimiento'] ?? m['id'] ?? '')
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
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
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
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
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
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFFDC2626).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Center(
                      child: Text('Eliminar',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
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
      await repository.post('/ajax/actualizar_registro.php', {
        'tabla': 'tbl_cuentas_movimientos',
        'filtro': 'codigo=$cod',
        'modo': 'eliminar',
      });
      if (isMounted) {
        refresh(() {
          movements.removeWhere((x) =>
              (x['codigo'] ?? x['codigo_movimiento'] ?? x['id'] ?? '')
                  .toString()
                  .trim() ==
              cod);
        });
      }
    } catch (e) {
      debugPrint('[SAF] eliminar movimiento: $e');
    }
  }
}
