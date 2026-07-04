import '../../controllers/home_data_controller.dart';
import 'home_dependencies.dart';

extension HomeStatisticsScreen<T extends StatefulWidget> on HomeController<T> {
  Widget buildStatisticsScreen() {
    final cols = statisticsTabs[statisticsSubTab].$3;
    final tabName = statisticsTabs[statisticsSubTab].$1;

    final filtrados = statisticsData.where((r) {
      for (final c in cols) {
        final f = (statisticsFilters[c.$2] ?? '').trim().toLowerCase();
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
          // ── Premium header ─────────────────────────────────
          AnimatedBuilder(
            animation: shimmer,
            builder: (_, __) {
              final g = shimmer.value;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                          .withValues(alpha: 0.40 + g * 0.15),
                      blurRadius: 20 + g * 8,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Stack(children: [
                  Positioned(
                    right: -25, top: -25,
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          const Color(0xFF818CF8).withValues(alpha: 0.28),
                          Colors.transparent,
                        ]),
                      ))),
                  Positioned(
                    left: -15, bottom: -15,
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                      ))),
                  // Shimmer sweep
                  Positioned.fill(
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      child: Transform.translate(
                        offset: Offset((g * 2 - 1) * 200, 0),
                        child: Transform.rotate(
                          angle: 0.4,
                          child: Container(
                            width: 30,
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
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.08),
                          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estadísticas',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF67E8F9)
                                        .withValues(alpha: 0.40)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.auto_graph_rounded,
                                    size: 10, color: Color(0xFF67E8F9)),
                                const SizedBox(width: 4),
                                Text(tabName,
                                    style: const TextStyle(
                                        color: Color(0xFF67E8F9),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      if (filtrados.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20)),
                          ),
                          child: Text('${filtrados.length} reg.',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ),
                ]),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Grid de sub-pestañas ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(statisticsTabs.length, (i) {
                final activo = i == statisticsSubTab;
                return TweenAnimationBuilder<double>(
                  key: ValueKey('stab_$i'),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + i * 40),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.translate(
                        offset: Offset(0, 12 * (1 - v.clamp(0.0, 1.0))),
                        child: child),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (i == statisticsSubTab) return;
                      refresh(() {
                        statisticsSubTab = i;
                        statisticsFilters.clear();
                        statisticsPage = 0;
                      });
                      fetchStatistics();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width:
                          (MediaQuery.of(screenContext).size.width - 40) / 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        gradient: activo
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF0F0A3C),
                                  Color(0xFF1E1265),
                                  Color(0xFF3730A3),
                                  Color(0xFF4F46E5),
                                ],
                                stops: [0.0, 0.3, 0.65, 1.0],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: activo ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: activo
                              ? Colors.transparent
                              : const Color(0xFFE0E7FF),
                          width: 1.2,
                        ),
                        boxShadow: activo
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF3730A3)
                                      .withValues(alpha: 0.40),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              statisticsTabs[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: activo
                                    ? Colors.white
                                    : textMid,
                                fontWeight: activo
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: activo
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.chevron_right_rounded,
                                size: 14,
                                color: activo
                                    ? Colors.white
                                    : const Color(0xFF4F46E5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // ── Filtros ───────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E7FF)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.filter_list_rounded,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text('Filtros',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textMain)),
                if (statisticsFilters.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${statisticsFilters.length} activo',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              Builder(builder: (_) {
                // Agrupamos en filas de 2
                final rows = <List<(String, String, bool)>>[];
                for (var i = 0; i < cols.length; i += 2) {
                  rows.add(cols.sublist(i, (i + 2).clamp(0, cols.length)));
                }
                return Column(
                  children: [
                    for (var ri = 0; ri < rows.length; ri++) ...[
                      if (ri > 0) const SizedBox(height: 10),
                      if (rows[ri].length == 1)
                        _estFiltroInput(rows[ri][0])
                      else
                        Row(children: [
                          Expanded(child: _estFiltroInput(rows[ri][0])),
                          const SizedBox(width: 10),
                          Expanded(child: _estFiltroInput(rows[ri][1])),
                        ]),
                    ],
                  ],
                );
              }),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Tabla / Tarjetas ─────────────────────────────
          if (statisticsLoading)
            _estLoadingSkeleton()
          else if (filtrados.isEmpty)
            _estEmpty()
          else
            _estListaPaginada(cols, filtrados),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _estEmpty() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E7FF)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 28, color: Color(0xFF818CF8)),
            ),
            const SizedBox(height: 14),
            Text('Sin resultados',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textMain)),
            const SizedBox(height: 6),
            Text('Ajusta los filtros para ver datos',
                style: TextStyle(fontSize: 12, color: textSoft)),
          ]),
        ),
      );

  Widget _estLoadingSkeleton() {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) {
        final skC = Color.lerp(
            const Color(0xFFE3E8F2), const Color(0xFFF2F5FA), shimmer.value)!;
        Widget box(double w, double h, {double r = 8}) => Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                color: skC, borderRadius: BorderRadius.circular(r)));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: List.generate(4, (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                box(36, 36, r: 10),
                const SizedBox(width: 10),
                box(160, 14),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  box(60, 10),
                  const SizedBox(height: 6),
                  box(40, 16),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  box(70, 10),
                  const SizedBox(height: 6),
                  box(50, 16),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  box(55, 10),
                  const SizedBox(height: 6),
                  box(35, 16),
                ])),
              ]),
            ]),
          ))),
        );
      },
    );
  }

  Widget _estFiltroInput((String, String, bool) col) {
    final esCliente = col.$2 == 'cliente';
    final hint = esCliente ? 'Buscar cliente' : 'Filtrar ${col.$1.toLowerCase()}';
    return TextField(
      key: ValueKey('estfiltro_${statisticsSubTab}_${col.$2}'),
      keyboardType: col.$3 ? TextInputType.number : TextInputType.text,
      onChanged: (v) {
        filterDebounce?.cancel();
        filterDebounce = Timer(const Duration(milliseconds: 300), () {
          if (!isMounted) return;
          refresh(() {
            if (v.isEmpty) {
              statisticsFilters.remove(col.$2);
            } else {
              statisticsFilters[col.$2] = v;
            }
            statisticsPage = 0;
          });
        });
      },
      style: TextStyle(
          fontSize: 13, color: textMain, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 12, color: Color(0xFFB0BCCF)),
        prefixIcon: Icon(
          esCliente ? Icons.search_rounded : Icons.filter_alt_rounded,
          color: const Color(0xFF818CF8),
          size: 17,
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: inputFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
        ),
      ),
    );
  }

  Widget _estListaPaginada(
      List<(String, String, bool)> cols, List<Map<String, dynamic>> rows) {
    final totalPaginas = (rows.length / statisticsPageSize).ceil();
    final pagina = statisticsPage.clamp(0, totalPaginas - 1);
    final inicio = pagina * statisticsPageSize;
    final fin = (inicio + statisticsPageSize).clamp(0, rows.length);
    final visibles = rows.sublist(inicio, fin);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(
            visibles.length,
            (i) {
              final delay = (i * 0.07).clamp(0.0, 0.42);
              final end = (i * 0.07 + 0.60).clamp(0.5, 1.0);
              return TweenAnimationBuilder<double>(
                key: ValueKey('stat_${inicio + i}'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Interval(delay, end, curve: Curves.easeOutBack),
                builder: (_, v, child) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - v.clamp(0.0, 1.0))),
                    child: child,
                  ),
                ),
                child: _estCard(cols, visibles[i], inicio + i + 1),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Mostrando ${inicio + 1}–$fin de ${rows.length} registros',
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _estPaginacion(pagina, totalPaginas),
    ]);
  }

  Widget _estCard(
      List<(String, String, bool)> cols, Map<String, dynamic> row, int rank) {
    final cliente = (row[cols.first.$2] ?? '').toString().trim();
    final metricas = cols.skip(1).toList();

    // Rank colors
    final List<Color> rankGrad = rank == 1
        ? [const Color(0xFFCA8A04), const Color(0xFFF59E0B), const Color(0xFFFCD34D)]
        : rank == 2
            ? [const Color(0xFF4B5563), const Color(0xFF9CA3AF), const Color(0xFFD1D5DB)]
            : rank == 3
                ? [const Color(0xFF92400E), const Color(0xFFB45309), const Color(0xFFF59E0B)]
                : [const Color(0xFF1E1265), const Color(0xFF3730A3), const Color(0xFF4F46E5)];

    final accentColor = rank == 1
        ? const Color(0xFFF59E0B)
        : rank == 2
            ? const Color(0xFF9CA3AF)
            : rank == 3
                ? const Color(0xFFB45309)
                : const Color(0xFF4F46E5);

    final metricColors = [
      const Color(0xFF4F46E5),
      const Color(0xFF059669),
      const Color(0xFFDC2626),
      const Color(0xFF0EA5E9),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.09),
            blurRadius: 14,
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
          // Left rank accent bar
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: rankGrad,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            )),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank + name row
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: rankGrad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: rank <= 3
                          ? Text(
                              rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                              style: const TextStyle(fontSize: 17))
                          : Text('$rank',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textMain,
                                letterSpacing: -0.2)),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rank <= 3
                                ? rank == 1
                                    ? '# 1 — Top ranking'
                                    : '# $rank'
                                : '# $rank',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: accentColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // Metrics row
                Row(
                  children: List.generate(metricas.length, (mi) {
                    final c = metricas[mi];
                    final mColor =
                        metricColors[mi % metricColors.length];
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: mi < metricas.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: mColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: mColor.withValues(alpha: 0.16)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: mColor.withValues(alpha: 0.70),
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text((row[c.$2] ?? '—').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: mColor,
                                    letterSpacing: -0.3)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _estPaginacion(int pagina, int totalPaginas) {
    if (totalPaginas <= 1) return const SizedBox.shrink();

    final List<int> numeros = [];
    int desde = (pagina - 2).clamp(0, (totalPaginas - 5).clamp(0, totalPaginas));
    int hasta = (desde + 5).clamp(0, totalPaginas);
    for (var p = desde; p < hasta; p++) {
      numeros.add(p);
    }

    Widget pageChip(String label,
        {VoidCallback? onTap, bool activo = false}) {
      final enabled = onTap != null;
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            gradient: activo
                ? const LinearGradient(
                    colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: activo ? null : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: activo
                    ? Colors.transparent
                    : enabled
                        ? const Color(0xFFE0E7FF)
                        : lineCol,
                width: 1.2),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                  color: activo
                      ? Colors.white
                      : enabled
                          ? textMid
                          : const Color(0xFFD1D5DB))),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        pageChip('‹',
            onTap: pagina > 0
                ? () => refresh(() => statisticsPage = pagina - 1)
                : null),
        if (desde > 0) ...[
          pageChip('1',
              onTap: () => refresh(() => statisticsPage = 0)),
          if (desde > 1)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…',
                  style: TextStyle(
                      color: textSoft,
                      fontWeight: FontWeight.w700)),
            ),
        ],
        for (final p in numeros)
          pageChip('${p + 1}',
              activo: p == pagina,
              onTap: p == pagina
                  ? null
                  : () => refresh(() => statisticsPage = p)),
        if (hasta < totalPaginas) ...[
          if (hasta < totalPaginas - 1)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…',
                  style: TextStyle(
                      color: textSoft,
                      fontWeight: FontWeight.w700)),
            ),
          pageChip('$totalPaginas',
              onTap: () =>
                  refresh(() => statisticsPage = totalPaginas - 1)),
        ],
        pageChip('›',
            onTap: pagina < totalPaginas - 1
                ? () => refresh(() => statisticsPage = pagina + 1)
                : null),
      ]),
    );
  }
}
