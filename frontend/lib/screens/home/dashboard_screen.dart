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
    final recent = movements.take(5).toList();
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
                title: 'Resumen del mes',
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
                            value: formatCop(ingresos),
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
                            value: formatCop(egresos),
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
                            value: formatCop(balance),
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
                onAction: () => refresh(() => selectedIndex = 3),
                gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              const SizedBox(height: 14),
              if (loadingData)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: homeAccent),
                ))
              else if (recent.isEmpty)
                buildEmptyActivity()
              else
                AnimatedBuilder(
                  animation: shimmer,
                  builder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFF2F5FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: homeAccent.withValues(alpha: 0.14 + 0.06 * shimmer.value),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: homeAccent.withValues(
                              alpha: 0.07 + 0.05 * shimmer.value),
                          blurRadius: 28 + 8 * shimmer.value,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: recent.asMap().entries.map((e) {
                        final i = e.key;
                        final interval = Interval(
                          (i * 0.10).clamp(0.0, 0.45),
                          (i * 0.10 + 0.65).clamp(0.5, 1.0),
                          curve: Curves.easeOutCubic,
                        );
                        return TweenAnimationBuilder<double>(
                          key: ValueKey('mov_$i'),
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 750),
                          curve: interval,
                          builder: (_, t, child) => Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(20 * (1 - t), 0),
                              child: child,
                            ),
                          ),
                          child: buildMovementItem(e.value,
                              divider: i < recent.length - 1),
                        );
                      }).toList(),
                    ),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEF0F8)),
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
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8899BB),
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
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF8899BB),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  String _currentMonthLabel() {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
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
        isPositive ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5);

    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, child) {
        return Container(
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
                color:
                    homeAccent.withValues(alpha: 0.38 + 0.18 * shimmer.value),
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
                      ? Text(
                          formatCop(saldo),
                          key: const ValueKey('v'),
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
              GestureDetector(
                onTap: () => refresh(() => balanceVisible = !balanceVisible),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
              _balanceMini(
                Icons.savings_rounded,
                'Ahorros',
                formatCop(savers.fold(
                    0.0,
                    (s, a) =>
                        s +
                        numberValue(a['total_ahorrado'] ?? a['monto'] ?? 0))),
                const Color(0xFFA78BFA),
              ),
              _balanceDivider(),
              _balanceMini(
                Icons.credit_score_rounded,
                'Créditos',
                creditStatistics.length.toString(),
                const Color(0xFF34D399),
              ),
              _balanceDivider(),
              _balanceMini(
                Icons.people_alt_rounded,
                'Ahorradores',
                savers.length.toString(),
                const Color(0xFF60A5FA),
              ),
            ],
          ),
        ],
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
          [Color iconColor = Colors.white]) =>
      Expanded(
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: iconColor.withValues(alpha: 0.25), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 9.5)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
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
                style: const TextStyle(
                  color: homeNavy,
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
                color: color.withValues(
                    alpha: 0.44 + 0.16 * shimmer.value),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
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
          child: child,
        ),
      ),
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          width: 154,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(color, Colors.white, 0.72)!,
                Color.lerp(color, Colors.white, 0.42)!,
                Color.lerp(color, Colors.white, 0.18)!,
              ],
              stops: const [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.28), width: 1.2),
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
              Positioned(right: -16, bottom: -20,
                child: Container(width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      color.withValues(alpha: 0.22),
                      Colors.transparent,
                    ]),
                  ))),
              Positioned(right: -8, top: -8,
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.10),
                  ))),
              // Shimmer sweep
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset((shimmer.value * 2 - 1) * 200, 0),
                  child: Transform.rotate(angle: 0.42,
                    child: Container(width: 36,
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
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
                      child: Icon(accountIcon(tipo), color: Colors.white, size: 17),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: saldo >= 0
                            ? color.withValues(alpha: 0.12)
                            : const Color(0xFFDC2626).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: saldo >= 0
                              ? color.withValues(alpha: 0.30)
                              : const Color(0xFFDC2626).withValues(alpha: 0.28),
                          width: 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            color: saldo >= 0 ? color : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          saldo >= 0 ? 'Activa' : 'Revisar',
                          style: TextStyle(
                            color: saldo >= 0 ? color : const Color(0xFFDC2626),
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
                          color: cDark)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(formatCop(saldo),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: saldo >= 0 ? homeNavy : const Color(0xFFDC2626))),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget buildEmptyActivity() => Container(
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
                  color: homeAccent, size: 26),
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

  Widget _skel(double w, double h, {double r = 10}) => AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) {
          final base = Color.lerp(
              const Color(0xFFDDE3EE), const Color(0xFFEEF1F8), shimmer.value)!;
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
          AnimatedBuilder(
            animation: shimmer,
            builder: (_, __) {
              final c = Color.lerp(const Color(0xFFCED7EE),
                  const Color(0xFFDDE5F5), shimmer.value)!;
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
