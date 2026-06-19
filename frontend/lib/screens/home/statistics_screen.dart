import '../../controllers/home_data_controller.dart';
import 'home_dependencies.dart';

extension HomeStatisticsScreen<T extends StatefulWidget> on HomeController<T> {
  Widget buildStatisticsScreen() {
    const navy = Color(0xFF0D1B4B);
    final cols = statisticsTabs[statisticsSubTab].$3;

    // Filtro independiente por cada columna (como la web)
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text('Estadísticas',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
          ),
          const SizedBox(height: 14),

          // ── Grid de sub-pestañas (2 columnas) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(statisticsTabs.length, (i) {
                final activo = i == statisticsSubTab;
                return GestureDetector(
                  onTap: () {
                    if (i == statisticsSubTab) return;
                    refresh(() {
                      statisticsSubTab = i;
                      statisticsFilters.clear();
                      statisticsPage = 0;
                    });
                    fetchStatistics();
                  },
                  child: Container(
                    width: (MediaQuery.of(screenContext).size.width - 48) / 2,
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
                            statisticsTabs[i].$1,
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

          // ── Filtros por columna ──
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
                        : (MediaQuery.of(screenContext).size.width - 50) / 2,
                    child: _estFiltroInput(c),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Tabla / Tarjetas ─────────────────────────────────
          if (statisticsLoading)
            const Padding(
              padding: EdgeInsets.all(50),
              child: Center(child: CircularProgressIndicator(color: navy)),
            )
          else if (filtrados.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  statisticsData.isEmpty
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
    final hint =
        esCliente ? 'Buscar cliente' : 'Filtrar ${col.$1.toLowerCase()}';
    return TextField(
      // El key incluye la pestaña: al cambiar de sub-pestaña el campo se
      // recrea vacío (sin necesidad de un controller que haya que liberar).
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
    final totalPaginas = (rows.length / statisticsPageSize).ceil();
    final pagina = statisticsPage.clamp(0, totalPaginas - 1);
    final inicio = pagina * statisticsPageSize;
    final fin = (inicio + statisticsPageSize).clamp(0, rows.length);
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
    final metricas = cols.skip(1).toList();

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
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: rank <= 3
                  ? Text(
                      rank == 1
                          ? '🥇'
                          : rank == 2
                              ? '🥈'
                              : '🥉',
                      style: const TextStyle(fontSize: 16))
                  : Text('$rank',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: navy)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(cliente,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: navy)),
            ),
          ]),
          const SizedBox(height: 12),
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
                              color: Color(0xFF4361EE))),
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
    int desde =
        (pagina - 2).clamp(0, (totalPaginas - 5).clamp(0, totalPaginas));
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
                ? () => refresh(() => statisticsPage = pagina - 1)
                : null),
        if (desde > 0) ...[
          chip('1', onTap: () => refresh(() => statisticsPage = 0)),
          if (desde > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: TextStyle(color: Color(0xFF8899BB))),
            ),
        ],
        for (final p in numeros)
          chip('${p + 1}',
              activo: p == pagina,
              onTap:
                  p == pagina ? null : () => refresh(() => statisticsPage = p)),
        if (hasta < totalPaginas) ...[
          if (hasta < totalPaginas - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: TextStyle(color: Color(0xFF8899BB))),
            ),
          chip('$totalPaginas',
              onTap: () => refresh(() => statisticsPage = totalPaginas - 1)),
        ],
        chip('Sig ›',
            onTap: pagina < totalPaginas - 1
                ? () => refresh(() => statisticsPage = pagina + 1)
                : null),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BOTTOM NAV — Dark premium style
  // ══════════════════════════════════════════════════════════════
}
