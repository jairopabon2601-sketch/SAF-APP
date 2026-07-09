import '../../controllers/home_actions.dart';
import '../../widgets/home/home_app_bar.dart';
import 'home_dependencies.dart';
import 'movements_screen.dart';

extension HomeDashboardScreen<T extends StatefulWidget> on HomeController<T> {
  Widget buildDashboard(String greeting, String firstName) {
    if (loadingData || !serverTotalsLoaded) return _dashboardSkeleton();

    final ingresos = totalIncome;
    final egresos = totalExpenses;
    final balance = ingresos - egresos;
    // Mismo ORDER BY que la pantalla Movimientos / la web: fecha DESC, código ASC.
    String movDate(Map<String, dynamic> m) {
      final v = (m['fecha'] ?? '').toString();
      return v.length >= 10 ? v.substring(0, 10) : v;
    }

    int? movCode(Map<String, dynamic> m) => int.tryParse((m['codigo'] ??
            m['codigo_movimiento'] ??
            m['codigo_cuenta_movimiento'] ??
            m['id'] ??
            '')
        .toString());
    final recent = ([...movements]..sort((a, b) {
            final cmpFecha = movDate(b).compareTo(movDate(a));
            if (cmpFecha != 0) return cmpFecha;
            final codeA = movCode(a);
            final codeB = movCode(b);
            if (codeA != null && codeB != null && codeA != codeB) {
              return codeB.compareTo(codeA);
            }
            return 0;
          }))
        .take(5)
        .toList();
    final total = ingresos + egresos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Balance card ──────────────────────────────────────
        _buildBalanceCard(greeting, firstName),
        const SizedBox(height: 24),

        // ── Summary ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardSectionHeader(
                icon: Icons.insights_rounded,
                title: 'Resumen general',
                subtitle: 'Indicadores financieros consolidados',
                gradient: const [Color(0xFF10B981), Color(0xFF059669)],
              ),
              const SizedBox(height: 14),
              _buildFinancialHealthBar(ingresos, egresos),
              const SizedBox(height: 14),
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
                            value: balanceVisible
                                ? formatCop(ingresos)
                                : '• • • • • •',
                            color: const Color(0xFF00B86B),
                            ratioValue: total > 0 ? ingresos / total : null,
                            index: 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            icon: Icons.trending_down_rounded,
                            label: 'Total gastos',
                            value: balanceVisible
                                ? formatCop(egresos)
                                : '• • • • • •',
                            color: const Color(0xFFDC003A),
                            ratioValue: total > 0 ? egresos / total : null,
                            index: 1,
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
                            value: balanceVisible
                                ? formatCop(balance)
                                : '• • • • • •',
                            color: const Color(0xFF3A5FE5),
                            badge: '${accounts.length} cuentas',
                            valueColor: balance < 0
                                ? const Color(0xFFFFB3B3)
                                : const Color(0xFF7FFFCC),
                            index: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            icon: Icons.groups_rounded,
                            label: 'Ahorradores',
                            value: savers.length.toString(),
                            color: const Color(0xFF8B3CF7),
                            badge: 'activos',
                            index: 3,
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
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _dashboardSectionHeader(
              icon: Icons.account_balance_rounded,
              title: 'Mis cuentas',
              subtitle: '${accounts.length} fuentes registradas',
              action: 'Ver todas',
              onAction: () => refresh(() => selectedIndex = 3),
              gradient: const [Color(0xFF4361EE), Color(0xFF00D2FF)],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _cuentaChip(accounts[i], index: i),
            ),
          ),
        ],

        // ── Recent activity ───────────────────────────────────
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardSectionHeader(
                icon: Icons.receipt_long_rounded,
                title: 'Actividad reciente',
                subtitle: recent.isEmpty
                    ? '${recent.length} movimientos más recientes'
                    : '${formatDayLabel(movDate(recent.first))} · ${recent.length} movimientos',
                action: 'Ver todos',
                onAction: () => refresh(() => selectedIndex = 3),
                gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              const SizedBox(height: 10),
              if (loadingData)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: homeAccent),
                ))
              else if (recent.isEmpty)
                buildEmptyActivity()
              else
                Builder(builder: (_) {
                  // Agrupado por día, igual que la pestaña Movimientos:
                  // banner con fecha + neto, luego las cards de ese día.
                  final rows = <Widget>[];
                  String? fechaActual;
                  var grupo = <Map<String, dynamic>>[];
                  var i = 0;
                  void flush() {
                    if (grupo.isEmpty) return;
                    rows.add(buildDayGroupHeader(fechaActual!, grupo));
                    for (final m in grupo) {
                      rows.add(Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: buildAnimatedMovementCard(m, i++),
                      ));
                    }
                    grupo = [];
                  }

                  for (final m in recent) {
                    final f = movDate(m);
                    if (f != fechaActual) {
                      flush();
                      fechaActual = f;
                    }
                    grupo.add(m);
                  }
                  flush();
                  return Column(children: rows);
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DASHBOARD ASESOR (perfil 1)
  // ══════════════════════════════════════════════════════════════
  Widget buildAsesorDashboard(String greeting, String firstName) {
    if (loadingData || !menuOptionsLoaded) return _dashboardSkeleton();

    final lista = filteredSavers;
    final total = lista.length;
    final totalAhorrado =
        lista.fold(0.0, (s, a) => s + numberValue(a['total_ahorrado'] ?? 0));

    final hoy = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);

    final enMoraLista = lista.where((a) {
      final cuotas = a['ahorros'];
      if (cuotas is! List) return false;
      return cuotas.whereType<Map>().any((m) {
        final pagado = (m['estado_pago'] ?? '')
            .toString()
            .toLowerCase()
            .contains('pagado');
        if (pagado) return false;
        final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
        if (fc == null) return false;
        return !DateTime(fc.year, fc.month, fc.day).isAfter(hoyDate);
      });
    }).toList();

    final alDiaLista = lista.where((a) => !enMoraLista.contains(a)).toList();
    final enMoraCount = enMoraLista.length;
    final alDiaCount = alDiaLista.length;

    // Cuotas pagadas recientes
    final recentActivity = <Map<String, dynamic>>[];
    for (final saver in lista) {
      final nombre = (saver['ahorrador'] ?? '').toString();
      final cuotas = saver['ahorros'];
      if (cuotas is! List) continue;
      for (final c in cuotas.whereType<Map>()) {
        final fp = (c['fecha_pago'] ?? '').toString();
        if (fp.isEmpty || fp == 'null') continue;
        recentActivity.add({
          'nombre': nombre,
          'fecha_pago': fp,
          'valor_pagado': c['valor_pagado'] ?? c['valor'] ?? 0,
          'mes': c['nombre_mes'] ?? c['mes'] ?? '',
        });
      }
    }
    recentActivity.sort((a, b) =>
        b['fecha_pago'].toString().compareTo(a['fecha_pago'].toString()));
    final recent = recentActivity.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero card ───────────────────────────────────────────
        _buildAsesorBalanceCard(
            greeting, firstName, totalAhorrado, total, enMoraCount, alDiaCount),
        const SizedBox(height: 24),

        // ── Resumen: summary cards ───────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardSectionHeader(
                icon: Icons.bar_chart_rounded,
                title: 'Estado del portafolio',
                subtitle: '$total ahorradores a tu cargo',
                gradient: const [Color(0xFFA78BFA), Color(0xFF4361EE)],
              ),
              const SizedBox(height: 14),
              _buildMoraHealthBar(enMoraCount, alDiaCount, total),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.warning_amber_rounded,
                        label: 'Requieren atención',
                        value: enMoraCount.toString(),
                        color: const Color(0xFFEF4444),
                        ratioValue: total > 0 ? enMoraCount / total : null,
                        index: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.check_circle_rounded,
                        label: 'Al día',
                        value: alDiaCount.toString(),
                        color: const Color(0xFF059669),
                        ratioValue: total > 0 ? alDiaCount / total : null,
                        index: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── En mora ─────────────────────────────────────────────
        if (enMoraLista.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dashboardSectionHeader(
                  icon: Icons.warning_amber_rounded,
                  title: 'Requieren atención',
                  subtitle: '${enMoraLista.length} ahorradores en mora',
                  gradient: const [Color(0xFFEF4444), Color(0xFFF97316)],
                ),
                const SizedBox(height: 10),
                ...enMoraLista.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child:
                          _asesorSaverCard(e.value, isMora: true, index: e.key),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],

        // ── Al día ──────────────────────────────────────────────
        if (alDiaLista.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dashboardSectionHeader(
                  icon: Icons.check_circle_rounded,
                  title: 'Al día',
                  subtitle: '$alDiaCount ahorradores al corriente',
                  gradient: const [Color(0xFF059669), Color(0xFF34D399)],
                ),
                const SizedBox(height: 10),
                ...alDiaLista.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _asesorSaverCard(e.value,
                          isMora: false, index: e.key),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],

        // ── Actividad reciente ───────────────────────────────────
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dashboardSectionHeader(
                  icon: Icons.receipt_long_rounded,
                  title: 'Actividad reciente',
                  subtitle: 'Últimos pagos de cuotas registrados',
                  gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                const SizedBox(height: 10),
                ...recent.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _asesorActivityCard(e.value, e.key),
                    )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Hero card del asesor ────────────────────────────────────────────────────
  Widget _buildAsesorBalanceCard(String greeting, String name,
      double totalAhorrado, int total, int enMora, int alDia) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, child) => Container(
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF060E35),
              Color(0xFF0D1B6E),
              Color(0xFF1435A8),
              Color(0xFF0077BB),
            ],
            stops: [0.0, 0.38, 0.72, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: homeAccent.withValues(alpha: 0.38 + 0.18 * shimmer.value),
              blurRadius: 28 + 14 * shimmer.value,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFF0099CC)
                  .withValues(alpha: 0.20 + 0.10 * shimmer.value),
              blurRadius: 55,
              spreadRadius: -6,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned(
                top: -28,
                right: -28,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: -36,
                right: 30,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF00C6FF).withValues(alpha: 0.12),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset((shimmer.value * 2 - 1) * 340, 0),
                  child: Transform.rotate(
                    angle: 0.45,
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.055),
                          Colors.white.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: child!,
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12.5,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                SafPulsingStatusDot(),
                SizedBox(width: 6),
                Text('Activo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 22),
          Text('Total ahorrado',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(formatCop(totalAhorrado),
              style: TextStyle(
                  color: totalAhorrado < 0
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFBFD4FF),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                        color: totalAhorrado < 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF4361EE),
                        blurRadius: 16),
                  ])),
          const SizedBox(height: 20),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.18),
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _balanceMini(Icons.savings_rounded, 'Total ahorrado',
                formatCop(totalAhorrado), const Color(0xFFA78BFA)),
            _balanceDivider(),
            _balanceMini(Icons.people_alt_rounded, 'Ahorradores',
                total.toString(), const Color(0xFF60A5FA)),
            _balanceDivider(),
            _balanceMini(Icons.warning_amber_rounded, 'En mora',
                enMora.toString(), const Color(0xFFFBBF24)),
          ]),
        ],
      ),
    );
  }

  // ── Barra de salud mora/al-día ──────────────────────────────────────────────
  Widget _buildMoraHealthBar(int enMora, int alDia, int total) {
    final ratio = total > 0 ? (alDia / total).clamp(0.0, 1.0) : 1.0;
    final healthy = alDia >= enMora;
    final statusColor =
        healthy ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final statusLabel = healthy ? 'Estado: Saludable' : 'Estado: Atención';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: ratio),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, animRatio, __) => Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lineCol),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: statusColor.withValues(alpha: 0.55),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
              const Spacer(),
              Text('${(ratio * 100).toStringAsFixed(0)}% al día',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textSoft)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(children: [
                Container(
                    height: 7,
                    color: const Color(0xFFDC2626).withValues(alpha: 0.18)),
                FractionallySizedBox(
                  widthFactor: animRatio,
                  child: Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF34D399)]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _healthLegend(const Color(0xFF059669), 'Al día'),
                _healthLegend(const Color(0xFFDC2626), 'En mora'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta de ahorrador ────────────────────────────────────────────────────
  Widget _asesorSaverCard(Map<String, dynamic> a,
      {required bool isMora, int index = 0}) {
    final nombre = (a['ahorrador'] ?? '').toString();
    final monto = numberValue(a['total_ahorrado'] ?? 0);
    final initials = nombre.isNotEmpty
        ? nombre
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0] : '')
            .join()
            .toUpperCase()
        : '?';

    final accent = isMora ? const Color(0xFFEF4444) : const Color(0xFF059669);
    final cardGradient = isDarkTheme
        ? [
            Color.lerp(cardBg, accent, isMora ? 0.12 : 0.10)!,
            const Color(0xFF111832),
          ]
        : [
            isMora ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
            Colors.white,
          ];
    final borderColor = isDarkTheme
        ? accent.withValues(alpha: isMora ? 0.38 : 0.30)
        : (isMora ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0));
    final avatarGrad = isMora
        ? [const Color(0xFFFF6B6B), const Color(0xFFEF4444)]
        : [const Color(0xFF34D399), const Color(0xFF059669)];

    // cuotas vencidas
    final cuotas = a['ahorros'];
    int vencidas = 0;
    if (isMora && cuotas is List) {
      final hoy = DateTime.now().toUtc().subtract(const Duration(hours: 5));
      final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);
      vencidas = cuotas.whereType<Map>().where((m) {
        final pagado = (m['estado_pago'] ?? '')
            .toString()
            .toLowerCase()
            .contains('pagado');
        if (pagado) return false;
        final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
        if (fc == null) return false;
        return !DateTime(fc.year, fc.month, fc.day).isAfter(hoyDate);
      }).length;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + index * 55),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(30 * (1 - t), 0),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cardGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDarkTheme
                  ? Colors.black.withValues(alpha: 0.30)
                  : accent.withValues(alpha: 0.12),
              blurRadius: isDarkTheme ? 18 : 14,
              offset: const Offset(0, 5),
            ),
            if (isDarkTheme)
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra lateral de acento
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: avatarGrad,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    bottomLeft: Radius.circular(17),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(children: [
                    // Avatar con gradiente
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: avatarGrad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.38),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 4)
                            ],
                          )),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: textMain,
                                  letterSpacing: -0.2)),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMora
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_rounded,
                                  size: 11,
                                  color: accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMora
                                      ? (vencidas > 0
                                          ? '$vencidas cuota${vencidas > 1 ? 's' : ''} vencida${vencidas > 1 ? 's' : ''}'
                                          : 'En mora')
                                      : 'Al día',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Monto
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(formatCop(monto),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: textMain,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('ahorrado',
                            style: TextStyle(fontSize: 10, color: textSoft)),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tarjeta de actividad reciente ───────────────────────────────────────────
  Widget _asesorActivityCard(Map<String, dynamic> activity, int index) {
    final nombre = (activity['nombre'] ?? '').toString();
    final fecha = (activity['fecha_pago'] ?? '').toString();
    final mes = (activity['mes'] ?? '').toString();
    final valor = numberValue(activity['valor_pagado'] ?? 0);
    final initials = nombre.isNotEmpty
        ? nombre
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0] : '')
            .join()
            .toUpperCase()
        : '?';
    final subtitle = mes.isNotEmpty ? mes : fecha;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Interval(
        (index * 0.1).clamp(0.0, 0.5),
        (index * 0.1 + 0.7).clamp(0.4, 1.0),
        curve: Curves.easeOutCubic,
      ),
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - t)),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkTheme
                ? [
                    Color.lerp(cardBg, homeAccent, 0.12)!,
                    const Color(0xFF111832),
                  ]
                : const [Color(0xFFF5F3FF), Colors.white],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDarkTheme
                  ? homeAccent.withValues(alpha: 0.32)
                  : const Color(0xFFE0E7FF),
              width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDarkTheme
                  ? Colors.black.withValues(alpha: 0.30)
                  : homeAccent.withValues(alpha: 0.09),
              blurRadius: isDarkTheme ? 18 : 14,
              offset: const Offset(0, 5),
            ),
            if (isDarkTheme)
              BoxShadow(
                color: homeAccent.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFA78BFA), Color(0xFF4361EE)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(17),
                    bottomLeft: Radius.circular(17),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA78BFA), Color(0xFF4361EE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: homeAccent.withValues(alpha: 0.38),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 4)
                            ],
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: textMain,
                                  letterSpacing: -0.2)),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: homeAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.savings_rounded,
                                    size: 11, color: homeAccent),
                                const SizedBox(width: 4),
                                Text(subtitle,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: homeAccent,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(formatCop(valor),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF059669),
                                letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('pagado',
                            style: TextStyle(fontSize: 10, color: textSoft)),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DASHBOARD CRÉDITOS (perfil 5)
  // ══════════════════════════════════════════════════════════════
  Widget buildCreditsDashboard(String greeting, String firstName) {
    if (loadingData || !menuOptionsLoaded || !creditsDataLoaded) {
      return _dashboardSkeleton();
    }

    final totalPagado = creditsPaidTotal;
    final totalPendiente = creditsPendingTotal;
    final total = totalPagado + totalPendiente;
    final ratio = total > 0 ? (totalPagado / total).clamp(0.0, 1.0) : 0.0;
    final activeCount = credits.length;
    final pendingCount = pendingRequests
        .where((p) =>
            (int.tryParse(p['codigo_estado']?.toString() ?? '0') ?? 0) != 3)
        .length;

    // Últimos créditos (5)
    final recentCredits = credits.take(5).toList();

    // Últimos movimientos (5) ordenados por fecha desc
    String movDate(Map m) {
      final v = (m['fecha'] ?? '').toString();
      return v.length >= 10 ? v.substring(0, 10) : v;
    }

    final recentMovements = ([...movements]
          ..sort((a, b) => movDate(b).compareTo(movDate(a))))
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero card ─────────────────────────────────────────
        _buildCreditsHeroCard(greeting, firstName, totalPagado, totalPendiente,
            activeCount, pendingCount, ratio),
        const SizedBox(height: 24),

        // ── Resumen financiero ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardSectionHeader(
                icon: Icons.credit_score_rounded,
                title: 'Resumen de créditos',
                subtitle: 'Indicadores de cartera consolidados',
                gradient: const [Color(0xFF10B981), Color(0xFF059669)],
              ),
              const SizedBox(height: 14),
              // Barra de recuperación
              _buildRecoveryBar(ratio, totalPagado, totalPendiente, total),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Total recuperado',
                        value: formatCop(totalPagado),
                        color: const Color(0xFF00B86B),
                        ratioValue: total > 0 ? totalPagado / total : null,
                        index: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.account_balance_rounded,
                        label: 'Total pendiente',
                        value: formatCop(totalPendiente),
                        color: const Color(0xFFF59E0B),
                        ratioValue: total > 0 ? totalPendiente / total : null,
                        index: 1,
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
                        icon: Icons.credit_card_rounded,
                        label: 'Créditos activos',
                        value: activeCount.toString(),
                        color: const Color(0xFF4361EE),
                        index: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.pending_actions_rounded,
                        label: 'Solicitudes pendientes',
                        value: pendingCount.toString(),
                        color: const Color(0xFFEF4444),
                        index: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Créditos recientes ─────────────────────────────────
        if (recentCredits.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dashboardSectionHeader(
                  icon: Icons.receipt_long_rounded,
                  title: 'Créditos activos',
                  subtitle: '${credits.length} créditos en cartera',
                  action: 'Ver todos',
                  onAction: () => refresh(() => selectedIndex = 1),
                  gradient: const [Color(0xFF4361EE), Color(0xFF00D2FF)],
                ),
                const SizedBox(height: 12),
                ...recentCredits.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _creditDashCard(e.value, e.key),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Movimientos recientes ──────────────────────────────
        if (recentMovements.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dashboardSectionHeader(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Movimientos recientes',
                  subtitle: '${recentMovements.length} más recientes',
                  action: 'Ver todos',
                  onAction: () => refresh(() => selectedIndex =
                      allowedScreenIndices.indexOf(
                          allowedScreenIndices.lastWhere((i) => i == 3,
                              orElse: () => allowedScreenIndices.last))),
                  gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: recentMovements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _creditsMovementCard(recentMovements[i], i),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Hero card créditos ──────────────────────────────────────────────────────
  Widget _buildCreditsHeroCard(
    String greeting,
    String name,
    double totalPagado,
    double totalPendiente,
    int activos,
    int pendientes,
    double ratio,
  ) {
    final pct = (ratio * 100).toStringAsFixed(0);
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, child) => Container(
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B4B),
              Color(0xFF1A237E),
              Color(0xFF283593),
              Color(0xFF4361EE),
            ],
            stops: [0.0, 0.30, 0.65, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4361EE)
                  .withValues(alpha: 0.38 + 0.18 * shimmer.value),
              blurRadius: 28 + 14 * shimmer.value,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFF1A237E)
                  .withValues(alpha: 0.20 + 0.10 * shimmer.value),
              blurRadius: 55,
              spreadRadius: -6,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(children: [
            Positioned(
              top: -28,
              right: -28,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -36,
              right: 30,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF7C83FF).withValues(alpha: 0.20),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset((shimmer.value * 2 - 1) * 340, 0),
                child: Transform.rotate(
                  angle: 0.45,
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.055),
                        Colors.white.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: child!,
            ),
          ]),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12.5,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                SafPulsingStatusDot(),
                SizedBox(width: 6),
                Text('Activo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 22),
          Text('Cartera pendiente',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(formatCop(totalPendiente),
              style: const TextStyle(
                  color: Color(0xFFBFD4FF),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(color: Color(0xFF4361EE), blurRadius: 20),
                  ])),
          const SizedBox(height: 8),
          // Barra de recuperación inline
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: ratio),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(
                        height: 5, color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 5,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0xFF7C83FF), Color(0xFFBFD4FF)]),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(
                    '$pct% recuperado de ${formatCop(totalPendiente + totalPagado)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.18),
                Colors.transparent,
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _balanceMini(Icons.credit_card_rounded, 'Activos',
                activos.toString(), const Color(0xFF6EE7B7)),
            _balanceDivider(),
            _balanceMini(Icons.payments_rounded, 'Recuperado',
                formatCop(totalPagado), const Color(0xFFA78BFA)),
            _balanceDivider(),
            _balanceMini(Icons.pending_actions_rounded, 'Solicitudes',
                pendientes.toString(), const Color(0xFFFBBF24)),
          ]),
        ],
      ),
    );
  }

  // ── Barra de recuperación ───────────────────────────────────────────────────
  Widget _buildRecoveryBar(
      double ratio, double pagado, double pendiente, double total) {
    final healthy = ratio >= 0.7;
    final statusColor =
        healthy ? const Color(0xFF059669) : const Color(0xFFF59E0B);
    final pct = (ratio * 100).toStringAsFixed(0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: ratio),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, animRatio, __) => Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lineCol),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: statusColor.withValues(alpha: 0.55),
                      blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Text('Recuperación: $pct%',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
            const Spacer(),
            Text(formatCop(total),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textSoft)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(children: [
              Container(
                  height: 7,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.20)),
              FractionallySizedBox(
                widthFactor: animRatio,
                child: Container(
                  height: 7,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF34D399)]),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _healthLegend(const Color(0xFF059669), 'Recuperado'),
            _healthLegend(const Color(0xFFF59E0B), 'Pendiente'),
          ]),
        ]),
      ),
    );
  }

  // ── Tarjeta de crédito para el dashboard ────────────────────────────────────
  Widget _creditDashCard(Map<String, dynamic> c, int index) {
    final cliente = (c['cliente'] ?? c['deudor'] ?? '').toString();
    final pendiente = numberValue(c['saldo_pendiente'] ?? 0);
    final pagado = numberValue(c['total_pagado'] ?? 0);
    final totalPagar = numberValue(c['total_pagar'] ?? 0);
    final valorPrestamo = numberValue(c['valor_prestamo'] ?? 0);
    final proxFecha =
        (c['proxima_fecha'] ?? c['proxima_cuota'] ?? '').toString();
    final numCuotas = (c['num_cuotas'] ?? '').toString();
    final tipo = (c['tipo'] ?? '').toString();
    final estado = (c['estado'] ?? 'Activo').toString();
    final activo = estado.toLowerCase().contains('activ');

    bool vencido = false;
    if (activo && proxFecha.isNotEmpty && proxFecha != 'null') {
      try {
        vencido = DateTime.parse(proxFecha).isBefore(DateTime.now());
      } catch (_) {}
    }

    final initials = cliente
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    final progress = totalPagar > 0
        ? (pagado / totalPagar).clamp(0.0, 1.0)
        : (pendiente > 0 ? 0.0 : 1.0);

    // Color según estado
    final List<Color> grad = !activo
        ? [const Color(0xFF059669), const Color(0xFF34D399)]
        : vencido
            ? [const Color(0xFFDC2626), const Color(0xFFF87171)]
            : [
                [const Color(0xFF4361EE), const Color(0xFF7C83FF)],
                [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
                [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
                [const Color(0xFF059669), const Color(0xFF34D399)],
                [const Color(0xFFD97706), const Color(0xFFFBBF24)],
              ][index % 5];

    final statusColor = !activo
        ? const Color(0xFF059669)
        : vencido
            ? const Color(0xFFDC2626)
            : const Color(0xFF4361EE);
    final statusBg = statusColor.withValues(alpha: isDarkTheme ? 0.18 : 0.10);
    final statusLabel = !activo
        ? 'Pagado'
        : vencido
            ? 'Vencido'
            : 'Activo';
    final statusIcon = !activo
        ? Icons.check_circle_rounded
        : vencido
            ? Icons.warning_rounded
            : Icons.credit_card_rounded;

    final proxStr = proxFecha.isNotEmpty && proxFecha != 'null'
        ? proxFecha.substring(0, proxFecha.length.clamp(0, 10))
        : '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 420 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, 22 * (1 - t)),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: grad[0].withValues(alpha: 0.18), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: grad[0].withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Barra lateral con gradiente
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila superior: avatar + nombre + estado
                      Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: grad,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: grad[0].withValues(alpha: 0.40),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(color: Colors.black26, blurRadius: 4)
                                  ])),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cliente,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: textMain,
                                      letterSpacing: -0.2)),
                              const SizedBox(height: 3),
                              Row(children: [
                                if (tipo.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: grad[0].withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(tipo,
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            color: grad[0],
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (numCuotas.isNotEmpty &&
                                    numCuotas != '0') ...[
                                  Icon(Icons.repeat_rounded,
                                      size: 10, color: textSoft),
                                  const SizedBox(width: 3),
                                  Text('$numCuotas cuotas',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: textSoft,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        // Badge de estado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(statusIcon, size: 10, color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: statusColor,
                                    fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ]),

                      const SizedBox(height: 11),
                      // Barra de progreso
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: progress),
                        duration: Duration(milliseconds: 700 + index * 80),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(children: [
                                Container(
                                    height: 5,
                                    color: grad[0].withValues(alpha: 0.12)),
                                FractionallySizedBox(
                                  widthFactor: v,
                                  child: Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: grad),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 5),
                          ],
                        ),
                      ),

                      // Fila inferior: monto + próxima cuota
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatCop(pendiente),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                      color: pendiente > 0 && vencido
                                          ? const Color(0xFFDC2626)
                                          : textMain,
                                      letterSpacing: -0.5)),
                              Text('saldo pendiente',
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      color: textSoft,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                          if (proxStr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: vencido
                                    ? (isDarkTheme
                                        ? const Color(0xFF4A1620)
                                        : const Color(0xFFFEE2E2))
                                    : (isDarkTheme
                                        ? inputFill
                                        : const Color(0xFFF0F2FA)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: vencido
                                      ? const Color(0xFFDC2626).withValues(
                                          alpha: isDarkTheme ? 0.35 : 0.12)
                                      : lineCol,
                                ),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_month_rounded,
                                        size: 11,
                                        color: vencido
                                            ? (isDarkTheme
                                                ? const Color(0xFFFCA5A5)
                                                : const Color(0xFFDC2626))
                                            : textSoft),
                                    const SizedBox(width: 4),
                                    Text(proxStr,
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: vencido
                                                ? (isDarkTheme
                                                    ? const Color(0xFFFCA5A5)
                                                    : const Color(0xFFDC2626))
                                                : (isDarkTheme
                                                    ? textMain
                                                    : const Color(
                                                        0xFF5A6A8A)))),
                                  ]),
                            ),
                          if (valorPrestamo > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCop(valorPrestamo),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                        color: textSoft,
                                        letterSpacing: -0.3)),
                                Text('valor crédito',
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        color: textSoft,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                        ],
                      ),
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

  // ── Tarjeta de movimiento premium para el dashboard de créditos ─────────────
  Widget _creditsMovementCard(Map<String, dynamic> m, int index) {
    final desc = (m['descripcion'] ?? 'Movimiento').toString();
    final cuenta = (m['cuenta_nombre'] ?? '').toString();
    final hexColor = (m['cuenta_color'] ?? '#4361EE').toString();
    final accentColor = parseHexColor(hexColor);
    final isIngreso = movementIsIncome(m);
    final valor = numberValue(m['valor'] ?? 0);
    final rawFecha = (m['fecha'] ?? '').toString();
    final fecha = rawFecha.length >= 10 ? rawFecha.substring(0, 10) : rawFecha;

    final incomeGrad = [const Color(0xFF059669), const Color(0xFF34D399)];
    final expenseGrad = [const Color(0xFFDC2626), const Color(0xFFF87171)];
    final barGrad = isIngreso ? incomeGrad : expenseGrad;
    final amtColor =
        isIngreso ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final bgTint = isIngreso
        ? const Color(0xFF059669).withValues(alpha: 0.04)
        : const Color(0xFFDC2626).withValues(alpha: 0.04);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, 18 * (1 - t)),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: lineCol, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: barGrad,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    bottomLeft: Radius.circular(17),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: bgTint,
                  padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: barGrad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: barGrad[0].withValues(alpha: 0.32),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isIngreso
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(desc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textMain,
                                  letterSpacing: -0.2)),
                          const SizedBox(height: 4),
                          Row(children: [
                            if (cuenta.isNotEmpty) ...[
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Flexible(
                                child: Text(cuenta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: textSoft,
                                        fontWeight: FontWeight.w500)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (fecha.isNotEmpty)
                              Text(fecha,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFB0BACC),
                                      fontWeight: FontWeight.w500)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIngreso ? '+' : '-'} ${formatCop(valor)}',
                          style: TextStyle(
                            color: amtColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: amtColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isIngreso ? 'Ingreso' : 'Egreso',
                            style: TextStyle(
                                fontSize: 9.5,
                                color: amtColor,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FINANCIAL HEALTH BAR
  // ══════════════════════════════════════════════════════════════
  Widget _buildFinancialHealthBar(double ingresos, double egresos) {
    final total = ingresos + egresos;
    final ratio = total > 0 ? (ingresos / total).clamp(0.0, 1.0) : 0.5;
    final healthy = ingresos >= egresos;
    final statusColor =
        healthy ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final statusLabel = healthy ? 'Salud: Positiva' : 'Salud: Déficit';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: ratio),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, animRatio, __) => Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lineCol),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: statusColor.withValues(alpha: 0.55),
                          blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(ratio * 100).toStringAsFixed(0)}% ingresos',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Container(
                    height: 7,
                    color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                  ),
                  FractionallySizedBox(
                    widthFactor: animRatio,
                    child: Container(
                      height: 7,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF34D399)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _healthLegend(const Color(0xFF059669), 'Ingresos'),
                _healthLegend(const Color(0xFFDC2626), 'Gastos'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthLegend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: textSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  String _currentMonthLabel() {
    const months = [
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
      'Diciembre',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  // ══════════════════════════════════════════════════════════════
  //  BALANCE CARD
  // ══════════════════════════════════════════════════════════════
  Widget _buildBalanceCard(String greeting, String name) {
    final saldo = totalBalance;
    final isPositive = saldo >= 0;
    final balanceColor =
        isPositive ? const Color(0xFFBFD4FF) : const Color(0xFFFCA5A5);
    final glowColor = isPositive ? homeAccent : const Color(0xFFDC2626);
    final gradColors = isPositive
        ? const [
            Color(0xFF060E35),
            Color(0xFF0D1B6E),
            Color(0xFF1435A8),
            Color(0xFF0077BB),
          ]
        : const [
            Color(0xFF3D0000),
            Color(0xFF7B1111),
            Color(0xFFB91C1C),
            Color(0xFFDC2626),
          ];
    final orbColor =
        isPositive ? const Color(0xFF00C6FF) : const Color(0xFFFF8080);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, entryT, cardChild) => Opacity(
        opacity: entryT.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - entryT)),
          child: RepaintBoundary(child: cardChild),
        ),
      ),
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, child) {
          return Container(
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradColors,
                stops: const [0.0, 0.38, 0.72, 1.0],
              ),
              // En oscuro la card se funde con el fondo: borde + glow más fuertes
              border: isDarkTheme
                  ? Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.55),
                      width: 1.4)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(
                      alpha:
                          (isDarkTheme ? 0.55 : 0.38) + 0.18 * shimmer.value),
                  blurRadius: 28 + 14 * shimmer.value,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color:
                      glowColor.withValues(alpha: 0.20 + 0.10 * shimmer.value),
                  blurRadius: 55,
                  spreadRadius: -6,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned(
                    top: -28,
                    right: -28,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -36,
                    right: 30,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          orbColor.withValues(alpha: 0.12),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: -30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          const Color(0xFF6C63FF).withValues(alpha: 0.10),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset((shimmer.value * 2 - 1) * 340, 0),
                      child: Transform.rotate(
                        angle: 0.45,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.055),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    child: child!,
                  ),
                ],
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SafPulsingStatusDot(),
                      SizedBox(width: 6),
                      Text(
                        'Activo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Total de Saldos',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14), width: 1),
                  ),
                  child: Text(
                    _currentMonthLabel(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0.2), end: Offset.zero)
                              .animate(anim),
                          child: child,
                        )),
                    child: balanceVisible
                        ? TweenAnimationBuilder<double>(
                            key: const ValueKey('v'),
                            tween: Tween(begin: 0.0, end: saldo),
                            duration: const Duration(milliseconds: 750),
                            curve: Curves.easeOutCubic,
                            builder: (_, animatedSaldo, __) => Text(
                              formatCop(animatedSaldo),
                              style: TextStyle(
                                color: balanceColor,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                shadows: [
                                  Shadow(
                                    color: balanceColor.withValues(alpha: 0.45),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const Text(
                            '• • • • • •',
                            key: ValueKey('h'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        refresh(() => balanceVisible = !balanceVisible),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(balanceVisible),
                        tween: Tween(begin: 0.5, end: 1.0),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.elasticOut,
                        builder: (_, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Icon(
                          balanceVisible
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: Colors.white.withValues(alpha: 0.75),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Ahorros, créditos y cuentas: sin repetir "Ahorradores",
                // que ya aparece como card propia en el resumen de abajo.
                _balanceMini(
                  Icons.savings_rounded,
                  'Ahorros',
                  balanceVisible
                      ? formatCop(savers.fold(
                          0.0,
                          (s, a) =>
                              s +
                              numberValue(
                                  a['total_ahorrado'] ?? a['monto'] ?? 0)))
                      : '• • • •',
                  const Color(0xFFA78BFA),
                  0,
                  () => refresh(() => selectedIndex = 2),
                ),
                const SizedBox(width: 10),
                _balanceMini(
                  Icons.credit_score_rounded,
                  'Créditos',
                  creditsTotal.toString(),
                  const Color(0xFF34D399),
                  1,
                  () => refresh(() => selectedIndex = 1),
                ),
                const SizedBox(width: 10),
                _balanceMini(
                  Icons.account_balance_rounded,
                  'Cuentas',
                  accounts.length.toString(),
                  const Color(0xFF60A5FA),
                  2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceDivider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.22),
              Colors.transparent,
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _balanceMini(IconData icon, String label, String value,
          [Color iconColor = Colors.white,
          int index = 0,
          VoidCallback? onTap]) =>
      Expanded(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('mini_${label}_$value'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Interval(
            (index * 0.12).clamp(0.0, 0.4),
            (index * 0.12 + 0.6).clamp(0.5, 1.0),
            curve: Curves.easeOutBack,
          ),
          builder: (_, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
                scale: 0.85 + 0.15 * t, child: RepaintBoundary(child: child)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: iconColor.withValues(alpha: 0.18),
              highlightColor: iconColor.withValues(alpha: 0.08),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      iconColor.withValues(alpha: 0.14),
                      iconColor.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: iconColor.withValues(alpha: 0.22), width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            iconColor.withValues(alpha: 0.85),
                            iconColor.withValues(alpha: 0.55),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 15),
                    ),
                    const SizedBox(height: 7),
                    Text(label,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
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
    final grad = gradient ?? [homeAccent, homeCyan];
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
                style: TextStyle(
                  color: textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: textSoft,
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
                gradient: const LinearGradient(
                  colors: [homeAccent, homeCyan],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: homeAccent.withValues(alpha: 0.28),
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

  // ══════════════════════════════════════════════════════════════
  //  SUMMARY CARD — rich gradient + shimmer sweep + stagger
  // ══════════════════════════════════════════════════════════════
  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? badge,
    Color? valueColor,
    double? ratioValue,
    int index = 0,
  }) {
    // 4-stop gradient: tint → base → shade → deep
    final cA = Color.lerp(color, Colors.white, 0.20)!;
    final cB = color;
    final cC = Color.lerp(color, Colors.black, 0.22)!;
    final cD = Color.lerp(color, Colors.black, 0.52)!;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1100),
      curve: Interval(
        (index * 0.09).clamp(0.0, 0.4),
        (index * 0.09 + 0.75).clamp(0.5, 1.0),
        curve: Curves.easeOutBack,
      ),
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - t)),
        child: Transform.scale(
          scale: 0.86 + 0.14 * t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
      ),
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, innerChild) => Container(
          width: double.infinity,
          height: ratioValue != null ? 150 : 138,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cA, cB, cC, cD],
              stops: const [0.0, 0.30, 0.65, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.44 + 0.16 * shimmer.value),
                blurRadius: 22 + 10 * shimmer.value,
                offset: const Offset(0, 9),
              ),
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 48,
                spreadRadius: -6,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(children: [
            // ── Radial glow — top-right ───────────────────────
            Positioned(
              right: -38,
              top: -38,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            // ── Inner ring ────────────────────────────────────
            Positioned(
              right: -12,
              top: -12,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // ── Bottom-left accent orb ─────────────────────────
            Positioned(
              left: -22,
              bottom: -22,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // ── Shimmer sweep ──────────────────────────────────
            Positioned.fill(
              child: Transform.translate(
                offset: Offset((shimmer.value * 2 - 1) * 200, 0),
                child: Transform.rotate(
                  angle: 0.40,
                  child: Container(
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Content ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: innerChild!,
            ),
          ]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1,
                      ),
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
                color: Colors.white.withValues(alpha: 0.80),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            if (ratioValue != null) ...[
              const SizedBox(height: 9),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: ratioValue),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                          height: 4,
                          color: Colors.white.withValues(alpha: 0.18)),
                      FractionallySizedBox(
                        widthFactor: v.clamp(0.0, 1.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.50),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _cuentaPalette = [
    (Color(0xFF4361EE), Color(0xFF93C5FD)),
    (Color(0xFF059669), Color(0xFF6EE7B7)),
    (Color(0xFF4361EE), Color(0xFFC4B5FD)),
    (Color(0xFFF59E0B), Color(0xFFFDE68A)),
    (Color(0xFFDC2626), Color(0xFFFCA5A5)),
    (Color(0xFF0891B2), Color(0xFF67E8F9)),
    (Color(0xFFDB2777), Color(0xFFF9A8D4)),
    (Color(0xFF65A30D), Color(0xFFBEF264)),
  ];

  Widget _cuentaChip(Map<String, dynamic> c, {int index = 0}) {
    final nombre = (c['nombre'] ?? c['name'] ?? 'Cuenta').toString();
    final tipo = (c['tipo'] ?? c['type'] ?? '').toString().toLowerCase();
    final saldo = accountBalance(c);
    final hexColor = (c['color'] ?? '').toString();
    final color = hexColor.isNotEmpty
        ? parseHexColor(hexColor)
        : _cuentaPalette[index % _cuentaPalette.length].$1;
    final cLight = Color.lerp(color, Colors.white, 0.48)!;
    final cDark = Color.lerp(color, Colors.black, 0.22)!;
    // En light el texto es blanco en todas las tarjetas (estandarizado como
    // dark); los tonos muy claros (amarillo, cian) se profundizan para que
    // el blanco contraste igual sin variar el color del texto.
    final base = (!isDarkTheme && color.computeLuminance() > 0.45)
        ? Color.lerp(color, Colors.black, 0.32)!
        : color;

    final entryInterval = Interval(
      (index * 0.10).clamp(0.0, 0.45),
      (index * 0.10 + 0.65).clamp(0.5, 1.0),
      curve: Curves.easeOutBack,
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey('chip_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: entryInterval,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: RepaintBoundary(child: child),
        ),
      ),
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          width: 154,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkTheme
                  ? [
                      Color.lerp(color, Colors.black, 0.42)!,
                      Color.lerp(color, Colors.black, 0.60)!,
                      Color.lerp(color, Colors.black, 0.74)!,
                    ]
                  : [
                      Color.lerp(base, Colors.white, 0.12)!,
                      base,
                      Color.lerp(base, Colors.black, 0.22)!,
                    ],
              stops: const [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: color.withValues(alpha: 0.28), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22 + 0.10 * shimmer.value),
                blurRadius: 18 + 6 * shimmer.value,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(children: [
              // Decorative orb
              Positioned(
                  right: -16,
                  bottom: -20,
                  child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          color.withValues(alpha: 0.22),
                          Colors.transparent,
                        ]),
                      ))),
              Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.10),
                      ))),
              // Shimmer sweep
              Positioned.fill(
                child: Transform.translate(
                    offset: Offset((shimmer.value * 2 - 1) * 200, 0),
                    child: Transform.rotate(
                        angle: 0.42,
                        child: Container(
                            width: 36,
                            decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0),
                            ]))))),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cLight, color, cDark],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.42),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(accountIcon(tipo),
                              color: Colors.white, size: 17),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: saldo >= 0
                                ? (isDarkTheme
                                    ? color.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.20))
                                : const Color(0xFFDC2626).withValues(
                                    alpha: isDarkTheme ? 0.10 : 0.30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: saldo >= 0
                                  ? (isDarkTheme
                                      ? color.withValues(alpha: 0.30)
                                      : Colors.white.withValues(alpha: 0.45))
                                  : (isDarkTheme
                                      ? const Color(0xFFDC2626)
                                          .withValues(alpha: 0.28)
                                      : const Color(0xFFFFB4B4)
                                          .withValues(alpha: 0.60)),
                              width: 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: saldo >= 0
                                    ? (isDarkTheme ? color : Colors.white)
                                    : (isDarkTheme
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFFFB4B4)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              saldo >= 0 ? 'Activa' : 'Revisar',
                              style: TextStyle(
                                color: saldo >= 0
                                    ? (isDarkTheme
                                        ? Color.lerp(color, Colors.white, 0.55)!
                                        : Colors.white)
                                    : (isDarkTheme
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFFFD9D9)),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]),
                        ),
                      ]),
                      const Spacer(),
                      Text(nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDarkTheme
                                  ? Color.lerp(color, Colors.white, 0.62)!
                                  : Colors.white.withValues(alpha: 0.92))),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                            balanceVisible ? formatCop(saldo) : '• • • •',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: saldo >= 0
                                    ? Colors.white
                                    : (isDarkTheme
                                        ? const Color(0xFFF87171)
                                        : const Color(0xFFFFD9D9)))),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget buildEmptyActivity({
    String title = 'Sin movimientos',
    String subtitle = 'Los movimientos apareceran aqui',
    IconData icon = Icons.receipt_long_rounded,
    Color accent = homeAccent,
    String? badge,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lineCol),
          boxShadow: [
            BoxShadow(
                color: homeNavy.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.16),
                    accent.withValues(alpha: 0.07),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: accent.withValues(alpha: 0.10)),
              ),
              child: Icon(icon, color: accent, size: 27),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textSoft.withValues(alpha: 0.8), fontSize: 12)),
            if (badge != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _skel(double w, double h, {double r = 10}) => skelBox(w, h, r: r);

  Widget buildPendingSkeleton() => IgnorePointer(
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
                      color: lineCol.withValues(alpha: 0.65),
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
                        color: lineCol.withValues(alpha: 0.55),
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
          AnimatedBuilder(
            animation: shimmer,
            builder: (_, __) {
              final c = isDarkTheme
                  ? Color.lerp(const Color(0xFF1B2348), const Color(0xFF232C58),
                      shimmer.value)!
                  : Color.lerp(const Color(0xFFCED7EE), const Color(0xFFDDE5F5),
                      shimmer.value)!;
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _skel(130, 18, r: 6),
              const SizedBox(height: 14),
              _skel(double.infinity, 70, r: 16),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _skel(double.infinity, 138, r: 22)),
                const SizedBox(width: 12),
                Expanded(child: _skel(double.infinity, 138, r: 22)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _skel(double.infinity, 138, r: 22)),
                const SizedBox(width: 12),
                Expanded(child: _skel(double.infinity, 138, r: 22)),
              ]),
              const SizedBox(height: 26),
              _skel(160, 18, r: 6),
              const SizedBox(height: 14),
              _skel(double.infinity, 68, r: 14),
              const SizedBox(height: 10),
              _skel(double.infinity, 68, r: 14),
              const SizedBox(height: 10),
              _skel(double.infinity, 68, r: 14),
            ]),
          ),
        ],
      );
}
