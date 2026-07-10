import '../screens/home/home_dependencies.dart';
import 'home_actions.dart';

extension HomeDataController<T extends StatefulWidget> on HomeController<T> {
  Future<void> fetchMenuOptions() async {
    // Asesor (perfil 1): ve Inicio y Ahorradores
    if (isAsesor) {
      if (isMounted) {
        refresh(() {
          allowedScreenIndices = [0, 2];
          selectedIndex = 0;
          menuOptionsLoaded = true;
        });
      }
      return;
    }
    // Admin siempre ve todos los tabs
    if (isAdmin) {
      if (isMounted) {
        refresh(() {
          allowedScreenIndices = [0, 1, 2, 3];
          menuOptionsLoaded = true;
        });
      }
      return;
    }
    try {
      final r = await repository
          .post('/ajax/cargar_opciones.php', {})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1 && d['opciones'] is List) {
          final opciones = d['opciones'] as List;
          final allowed = <int>[0]; // Inicio siempre visible
          for (final op in opciones.whereType<Map>()) {
            final n = (op['nombre'] ?? '').toString().toLowerCase()
                .replaceAll('é', 'e').replaceAll('á', 'a')
                .replaceAll('ó', 'o').replaceAll('í', 'i')
                .replaceAll('ú', 'u');
            if ((n.contains('credito') || n.contains('prestamo')) && !allowed.contains(1)) {
              allowed.add(1);
            }
            if (n.contains('ahorro') && !allowed.contains(2)) allowed.add(2);
            if ((n.contains('gasto') || n.contains('movimiento')) && !allowed.contains(3)) {
              allowed.add(3);
            }
          }
          allowed.sort();
          if (isMounted) {
            refresh(() {
              allowedScreenIndices = allowed;
              menuOptionsLoaded = true;
              if (selectedIndex >= allowed.length) selectedIndex = 0;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] menuOptions: $e');
    }
    // Fallback: si la red falla no dejamos el skeleton colgado
    if (isMounted && !menuOptionsLoaded) {
      refresh(() => menuOptionsLoaded = true);
    }
  }

  Future<void> loadData() async {
    await repository.init();
    final u = repository.user;
    final codigoUsuario = u?['codigo_usuario']?.toString() ?? '';
    final anio = DateTime.now().year.toString();

    // Determinar rol y origen del usuario
    final codigoPerfil = u?['codigo_perfil']?.toString() ?? '';
    final origenValue = u?['codigo_origen']?.toString() ?? '';
    if (isMounted) {
      refresh(() {
        isAdmin = (codigoPerfil == '6');
        isAsesor = (codigoPerfil == '1');
        isCreditsProfile = (codigoPerfil == '5');
        codigoOrigen = origenValue;
      });
    }

    // Cargar opciones de menú según perfil (no bloquea el resto)
    unawaited(fetchMenuOptions());

    // Tema sincronizado con la web: la preferencia guardada en el servidor
    // (por usuario) manda sobre la copia local del dispositivo.
    unawaited(syncThemeFromServer());

    // Pendientes en background desde el arranque, independiente del bloque
    // principal (que tiene timeout y puede abortar): si fuera parte de él,
    // un servidor lento dejaría la tarjeta de créditos en "0 pendientes"
    // hasta que el usuario tocara la pestaña.
    unawaited(fetchPending());

    // Show cached data immediately so the screen isn't blank.
    // Local reads run in parallel — they're independent SharedPreferences
    // lookups with no reason to wait on each other one by one.
    final cached = await Future.wait([
      repository.loadLocalData('cuentas'),
      repository.loadLocalData('movimientos'),
      repository.loadLocalData('ahorradores'),
      repository.loadLocalData('creditos'),
      repository.loadLocalData('creditos_lista'),
      repository.loadLocalData('totales'),
      repository.loadLocalData('pendientes'),
    ]);
    final cachedCuentas = cached[0];
    final cachedMovs = cached[1];
    final cachedAhorradores = cached[2];
    final cachedCreditos = cached[3];
    final cachedCreditosLista = cached[4];
    final cachedTotales = cached[5];
    final cachedPendientes = cached[6];

    if (cachedCuentas != null) {
      accounts = cachedCuentas;
      invalidateComputedCache();
    }
    if (cachedMovs != null) {
      movements = cachedMovs;
      invalidateComputedCache();
    }
    if (cachedAhorradores != null) savers = cachedAhorradores;
    if (cachedPendientes != null) {
      pendingRequests = cachedPendientes;
      pendingLoaded = true;
    }
    if (cachedCreditos != null) creditStatistics = cachedCreditos;
    if (cachedCreditosLista != null) credits = cachedCreditosLista;
    if (cachedTotales != null && cachedTotales.isNotEmpty) {
      serverExpenses = numberValue(cachedTotales.first['gastos']);
      serverIncome = numberValue(cachedTotales.first['ingresos']);
      serverTotalsLoaded = true;
    }

    final hasCachedData = cachedCuentas != null;
    if (hasCachedData && isMounted) refresh(() => loadingData = false);

    // Movimientos aparte, sin esperar: una cuenta con mucho historial puede
    // tener decenas de páginas (15s cada una, en serie) y por sí sola agotar
    // el timeout de 30s de abajo — eso abortaba el bloque completo antes de
    // llegar a fetchRates/fetchSources/fetchAdvisors, dejando esos datos sin
    // cargar en toda la sesión. La tab de Movimientos y "Actividad reciente"
    // ya condicionan su propio skeleton a que `movements` llegue, así que no
    // hace falta bloquear el resto del arranque por esto.
    // Pequeño retraso: en frío se disparan 5-6 peticiones a la vez (cuentas,
    // ahorros, créditos, totales, movimientos) contra un hosting compartido
    // que a veces rechaza/corta conexiones simultáneas — esta es la más
    // pesada (JOIN paginado), así que arranca un instante después para no
    // competir por el mismo cupo de conexiones justo al arranque.
    unawaited(Future.delayed(const Duration(milliseconds: 400), () {
      if (isMounted) return _fetchMovimientosTodasCuentas(codigoUsuario);
    }));

    // Fetch fresh data from network. fetchAccounts corre junto al resto:
    // nada aquí depende realmente de que las cuentas terminen primero
    // (el endpoint global de movimientos no las necesita), así que
    // serializarlo solo agregaba una ida y vuelta de red innecesaria.
    // Todo con timeout y finally: si el servidor se cuelga o algo lanza,
    // el skeleton igual se retira y se muestra lo que haya (cache o vacío).
    try {
      await Future.wait([
        fetchAccounts(codigoUsuario),
        fetchSavers(anio),
        fetchCredits(codigoUsuario),
        _fetchTotalesResumen(codigoUsuario),
      ]).timeout(const Duration(seconds: 30));
      // Con credits ya cargada, construir deudores al instante
      tryBuildDebtorsFromLocal();
      // Tasas y fuentes en paralelo; deudores via API en background (no bloquea)
      unawaited(fetchDebtors());
      await Future.wait([fetchRates(), fetchSources(), fetchAdvisors()])
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[SAF] loadData: $e');
    } finally {
      // El dashboard condiciona su skeleton a serverTotalsLoaded; si el
      // endpoint de totales falló (visto tras login sin caché local), sin
      // este fallback la pantalla queda en placeholders para siempre. Con
      // los movimientos ya cargados, totalIncome/totalExpenses calculan la
      // suma local — mismas cifras que la web — en lugar de mostrar ceros.
      final localIncome = totalIncome;
      final localExpenses = totalExpenses;
      final usedFallback = !serverTotalsLoaded;
      if (isMounted) {
        refresh(() {
          if (usedFallback) {
            serverIncome = localIncome;
            serverExpenses = localExpenses;
            serverTotalsLoaded = true;
            // Movimientos corre unawaited y puede seguir vacío aquí — esta
            // suma es solo un placeholder hasta que _fetchMovimientosTodasCuentas
            // termine y la recalcule con los datos reales.
            serverTotalsIsFallback = true;
          }
          loadingData = false;
        });
      }
      if (usedFallback) {
        // El servidor falló las 2 veces que ya lo intentó _fetchTotalesResumen
        // (típico justo tras un resume en frío, cuando la red aún se está
        // reestableciendo). Reintenta una vez más pasado un momento para que
        // el dashboard termine mostrando el total real del servidor, no solo
        // la suma local aproximada.
        unawaited(Future.delayed(const Duration(seconds: 4), () async {
          if (!isMounted) return;
          await _fetchTotalesResumen(codigoUsuario);
        }));
      }
    }
  }

  Future<void> fetchAccounts(String filtro) async {
    try {
      final r = await repository
          .cachedPost('/ajax/listar_cuentas_gasto.php', {'filtro': filtro})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        List<dynamic>? list;
        if (d is List) {
          list = d;
        } else if (d is Map) {
          for (final k in ['cuentas', 'datos', 'data', 'resultado_datos']) {
            if (d[k] is List) {
              list = d[k] as List;
              break;
            }
          }
        }
        if (list != null) {
          accounts = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          invalidateComputedCache();
          unawaited(repository.saveLocalData('cuentas', accounts));
        }
      }
    } catch (e) {
      debugPrint('[SAF] cuentas: $e');
    }
  }

  Future<void> _fetchMovimientosTodasCuentas(String usuario,
      {String? desde, String? hasta, int intentoTotal = 0}) async {
    final dStr = desde ?? '';
    final hStr = hasta ?? '';
    // La página 1 reporta el total de páginas; la clausura lo captura.
    var totalPaginasDetectadas = 1;

    // Página individual del endpoint global; null si falla o no es válida.
    Future<List<Map<String, dynamic>>?> fetchPagina(int pagina) async {
      final r = await repository.post('/ajax/listar_movimientos_usuario.php', {
        'usuario': usuario,
        'desde': dStr,
        'hasta': hStr,
        'pagina': pagina.toString(),
      }).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final d = decodeJsonMap(r.body);
      if (d['resultado'] != 1 && d['resultado'] != '1') return null;
      final raw = d['movimientos'];
      if (raw is! List) return null;
      if (pagina == 1) {
        totalPaginasDetectadas =
            int.tryParse(d['total_paginas']?.toString() ?? '1') ?? 1;
      }
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Use global endpoint: single JOIN query, globally sorted by fecha DESC,
    // codigo DESC. Hasta 2 intentos: la BD del hosting a veces bota la
    // conexión y el endpoint falla de forma transitoria.
    //
    // La página 1 se pide sola (trae total_paginas) y el resto en lotes
    // paralelos: con historiales grandes (1600+ movimientos = 33 páginas de
    // 50) pedirlas en serie tardaba ~1s por página, ~31s por recarga — la
    // causa de que la lista "nunca" se refrescara rápido tras crear o
    // eliminar un movimiento.
    for (var intento = 0; intento < 2; intento++) {
      try {
        final primera = await fetchPagina(1);
        if (primera != null) {
          // Tope de seguridad: un total_paginas mal reportado no debe
          // disparar cientos de peticiones.
          final totalPaginas = totalPaginasDetectadas.clamp(1, 100);
          final paginas = <int, List<Map<String, dynamic>>>{1: primera};

          // Mostrar la página 1 de inmediato (~1-2s) en vez de esperar a
          // que las hasta 32 páginas restantes terminen — antes la lista
          // se quedaba invisible los ~8-12s completos aunque el usuario
          // solo fuera a mirar los movimientos más recientes.
          movements = List<Map<String, dynamic>>.from(primera);
          invalidateComputedCache();
          movementsSettled = true;
          if (isMounted) refresh(() {});

          var falloAlguna = false;
          const lote = 6;
          for (var desde = 2;
              desde <= totalPaginas && !falloAlguna;
              desde += lote) {
            final hastaLote =
                (desde + lote - 1).clamp(desde, totalPaginas);
            final resultados = await Future.wait([
              for (var p = desde; p <= hastaLote; p++)
                fetchPagina(p).catchError((_) => null),
            ]);
            for (var j = 0; j < resultados.length; j++) {
              final res = resultados[j];
              if (res == null) {
                falloAlguna = true;
              } else {
                paginas[desde + j] = res;
              }
            }
            if (!falloAlguna) {
              // La lista crece con cada lote que llega, en vez de aparecer
              // toda de golpe al final.
              movements = <Map<String, dynamic>>[
                for (var p = 1; p <= hastaLote; p++) ...?paginas[p],
              ];
              invalidateComputedCache();
              if (isMounted) refresh(() {});
            }
          }

          if (!falloAlguna) {
            unawaited(repository.saveLocalData('movimientos', movements));
            // Si loadData() ya había fijado serverIncome/serverExpenses en
            // $0 (porque _fetchTotalesResumen falló justo tras el login, con
            // movements aún vacío), _refreshFallbackTotalsIfNeeded() corrige
            // el valor en memoria — pero sin este refresh() la corrección
            // nunca se pintaba y el balance se quedaba en $0 hasta que algo
            // más disparara un rebuild.
            _refreshFallbackTotalsIfNeeded();
            if (isMounted) refresh(() {});
            return;
          }
          // Si algún lote falló a mitad de camino, cae al fallback por
          // cuenta de abajo — pero el usuario ya vio progreso parcial en
          // vez de una pantalla en blanco durante toda la espera.
        }
      } catch (e) {
        debugPrint('[SAF] listar_movimientos_usuario intento $intento: $e');
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }

    // Fallback: per-account fetch (order may differ from web within same date)
    // fetchAccounts corre en paralelo con esta función, así que las cuentas
    // pueden no estar cargadas todavía; sin ellas este fallback no trae nada.
    if (accounts.isEmpty) await fetchAccounts(usuario);
    final all = <Map<String, dynamic>>[];
    const batchSize = 3;
    for (var i = 0; i < accounts.length; i += batchSize) {
      final batch = accounts.skip(i).take(batchSize);
      await Future.wait(batch.map((cuenta) async {
        final codigo = cuenta['codigo']?.toString() ?? '';
        if (codigo.isEmpty) return;
        try {
          final movimientos = await fetchAccountMovements(codigo, usuario,
              desde: dStr, hasta: hStr);
          for (final m in movimientos) {
            final mov = Map<String, dynamic>.from(m);
            mov['codigo_cuenta'] = codigo;
            mov['cuenta_nombre'] = cuenta['nombre'];
            mov['cuenta_color'] = cuenta['color'];
            all.add(mov);
          }
        } catch (e) {
          debugPrint('[SAF] mov cuenta $codigo: $e');
        }
      }));
    }
    all.sort((a, b) {
      final fechaA = (a['fecha'] ?? '').toString();
      final fechaB = (b['fecha'] ?? '').toString();
      final dA = fechaA.length >= 10 ? fechaA.substring(0, 10) : fechaA;
      final dB = fechaB.length >= 10 ? fechaB.substring(0, 10) : fechaB;
      final cmpFecha = dB.compareTo(dA);
      if (cmpFecha != 0) return cmpFecha;
      final idA = int.tryParse(
              (a['codigo_movimiento'] ?? a['codigo'] ?? a['id'] ?? '0')
                  .toString()) ??
          0;
      final idB = int.tryParse(
              (b['codigo_movimiento'] ?? b['codigo'] ?? b['id'] ?? '0')
                  .toString()) ??
          0;
      return idB.compareTo(idA);
    });
    // Si el fallback tampoco trajo nada (red caída), conservar lo que haya
    // en memoria/caché en lugar de pisar los movimientos con una lista vacía.
    if (all.isEmpty && movements.isNotEmpty) {
      movementsSettled = true;
      if (isMounted) refresh(() {});
      return;
    }
    if (all.isEmpty && accounts.isNotEmpty && intentoTotal < 3) {
      // Ni el endpoint global (2 intentos) ni el fallback por cuenta trajeron
      // nada, y sí hay cuentas — con hosting compartido esto suele ser una
      // saturación transitoria justo al arranque (5-6 peticiones a la vez),
      // no que de verdad no haya movimientos. Reintenta con backoff creciente
      // en vez de resignarse a "Sin movimientos" para toda la sesión.
      await Future.delayed(Duration(seconds: 3 * (intentoTotal + 1)));
      if (!isMounted) {
        movementsSettled = true;
        return;
      }
      return _fetchMovimientosTodasCuentas(usuario,
          desde: desde, hasta: hasta, intentoTotal: intentoTotal + 1);
    }
    movements = all;
    invalidateComputedCache();
    unawaited(repository.saveLocalData('movimientos', movements));
    _refreshFallbackTotalsIfNeeded();
    movementsSettled = true;
    if (isMounted) refresh(() {});
  }

  /// Refresco liviano tras registrar/editar un movimiento, transferir entre
  /// cuentas o ajustar un saldo — antes esos flujos llamaban a loadData()
  /// completo (cuentas + ahorros + créditos + totales + movimientos + tasas
  /// + fuentes + asesores + deudores), por lo que guardar UN movimiento
  /// siempre se sentía lento sin importar qué tan rápido respondiera el
  /// servidor para ese movimiento puntual. Esto solo refresca lo que en
  /// verdad cambió: el saldo de las cuentas, la lista de movimientos y los
  /// totales de ingresos/gastos.
  Future<void> refreshAfterMovementChange() async {
    final codigoUsuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (codigoUsuario.isEmpty) return;
    await Future.wait([
      fetchAccounts(codigoUsuario),
      _fetchMovimientosTodasCuentas(codigoUsuario),
      _fetchTotalesResumen(codigoUsuario),
    ]);
    if (isMounted) refresh(() {});
  }

  /// Inserta un movimiento en memoria apenas el servidor confirma el
  /// guardado, sin esperar la recarga de red (que sigue corriendo en
  /// segundo plano vía refreshAfterMovementChange para reconciliar):
  /// misma sensación instantánea que la web, que repinta con lo que ya
  /// tiene. Actualiza también saldo de la cuenta y totales locales.
  void applyLocalMovement({
    required String codigoCuenta,
    required String tipoMovimiento, // '2'=gasto, '3'/'1'=ingreso
    required double valor,
    required String fecha,
    required String descripcion,
  }) {
    final cuenta = accounts.firstWhere(
      (c) => (c['codigo'] ?? c['codigo_cuenta'] ?? '').toString() ==
          codigoCuenta,
      orElse: () => <String, dynamic>{},
    );
    final esIngreso = tipoMovimiento != '2';
    final ahoraBogota =
        DateTime.now().toUtc().subtract(const Duration(hours: 5));
    String dos(int n) => n.toString().padLeft(2, '0');
    // Código provisional: numérico y enorme para que ordene de primero
    // dentro de su fecha (la lista ordena fecha DESC, codigo DESC) y no
    // colisione con códigos reales; el refresh de red lo reemplaza.
    final mov = <String, dynamic>{
      'codigo': DateTime.now().millisecondsSinceEpoch.toString(),
      'fecha': fecha,
      'tipo_movimiento': tipoMovimiento,
      'valor': valor,
      'descripcion': descripcion,
      'codigo_cuenta': codigoCuenta,
      'cuenta_nombre': cuenta['nombre'],
      'cuenta_color': cuenta['color'],
      'fecha_registro': '${ahoraBogota.year}-${dos(ahoraBogota.month)}-'
          '${dos(ahoraBogota.day)} ${dos(ahoraBogota.hour)}:'
          '${dos(ahoraBogota.minute)}:${dos(ahoraBogota.second)}',
    };
    refresh(() {
      movements.insert(0, mov);
      if (cuenta.isNotEmpty) {
        final saldo = numberValue(cuenta['saldo_actual'] ?? 0);
        cuenta['saldo_actual'] = esIngreso ? saldo + valor : saldo - valor;
      }
      if (esIngreso) {
        serverIncome += valor;
      } else {
        serverExpenses += valor;
      }
      invalidateComputedCache();
    });
    // Igual que al eliminar: sin persistir, un hot restart mostraría por un
    // instante la caché vieja (sin este movimiento) antes de que la red
    // reconciliara.
    unawaited(repository.saveLocalData('movimientos', movements));
  }

  // Si loadData() tuvo que estimar serverIncome/serverExpenses con la suma
  // local (porque el endpoint de totales falló) antes de que `movements`
  // hubiera llegado, aquí ya está la lista real — recalcula para que el
  // dashboard deje de mostrar $0 apenas los movimientos terminen de cargar.
  void _refreshFallbackTotalsIfNeeded() {
    if (!serverTotalsIsFallback) return;
    // OJO: no usar los getters totalIncome/totalExpenses acá — cuando
    // serverTotalsLoaded ya es true (como en este punto), esos getters
    // devuelven serverIncome/serverExpenses tal cual, sin recalcular nada.
    // Asignar "serverIncome = totalIncome" era un círculo que nunca
    // corregía el valor real; hay que sumar `movements` directamente.
    serverIncome = movements
        .where(movementIsIncome)
        .fold<double>(0.0, (s, m) => s + numberValue(m['valor'] ?? 0));
    serverExpenses = movements
        .where((m) => !movementIsIncome(m))
        .fold<double>(0.0, (s, m) => s + numberValue(m['valor'] ?? 0));
  }

  Future<List<Map<String, dynamic>>> fetchAccountMovements(
      String codigoCuenta, String usuario,
      {String? desde, String? hasta}) async {
    final resultado = <Map<String, dynamic>>[];
    var pagina = 1;
    var totalPaginas = 1;

    do {
      final body = <String, dynamic>{
        'codigo_cuenta': codigoCuenta,
        'pagina': pagina.toString(),
        'usuario': usuario,
      };
      if (desde != null) body['desde'] = desde;
      if (hasta != null) body['hasta'] = hasta;

      final r = await repository
          .post('/ajax/listar_movimientos_cuenta.php', body)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) break;

      final d = decodeJsonMap(r.body);
      final raw = d['movimientos'] ?? d['datos'] ?? d['data'];
      if (raw is! List || raw.isEmpty) break;

      resultado.addAll(
          raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      totalPaginas = int.tryParse(d['total_paginas']?.toString() ?? '1') ?? 1;
      pagina++;
    } while (pagina <= totalPaginas && pagina <= 100);

    return resultado;
  }

  Future<void> loadSelectedAccountMovements() async {
    final selectedName = accountFilter;
    if (selectedName.isEmpty) {
      refresh(() {
        selectedAccountMovements = [];
        selectedAccountMovementsName = '';
        selectedAccountMovementsLoading = false;
      });
      return;
    }

    final account = accounts.firstWhere(
      (item) => (item['nombre'] ?? '').toString() == selectedName,
      orElse: () => <String, dynamic>{},
    );
    final accountCode =
        (account['codigo'] ?? account['codigo_cuenta'] ?? '').toString();
    final userCode = (repository.user?['codigo_usuario'] ?? '').toString();
    if (accountCode.isEmpty || userCode.isEmpty) return;

    refresh(() {
      selectedAccountMovements = [];
      selectedAccountMovementsName = selectedName;
      selectedAccountMovementsLoading = true;
    });

    try {
      final rows = await fetchAccountMovements(
        accountCode,
        userCode,
        desde: filterFrom != null ? _dateFmt(filterFrom!) : null,
        hasta: filterTo != null ? _dateFmt(filterTo!) : null,
      );
      final enriched = rows.map((row) {
        return <String, dynamic>{
          ...row,
          'codigo_cuenta': accountCode,
          'cuenta_nombre': selectedName,
          'cuenta_color': account['color'],
        };
      }).toList();
      if (!isMounted || accountFilter != selectedName) return;
      refresh(() {
        selectedAccountMovements = enriched;
        selectedAccountMovementsName = selectedName;
        selectedAccountMovementsLoading = false;
        movementsPage = 1;
      });
    } catch (error) {
      debugPrint('[SAF] movimientos cuenta $accountCode: $error');
      if (!isMounted || accountFilter != selectedName) return;
      refresh(() => selectedAccountMovementsLoading = false);
    }
  }

  String _dateFmt(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }

  Future<void> onDateFilterChanged() async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    if (isMounted) refresh(() => movementsPage = 1);
    final desde = filterFrom;
    final hasta = filterTo;
    await _fetchMovimientosTodasCuentas(
      usuario,
      desde: desde != null ? _dateFmt(desde) : null,
      hasta: hasta != null ? _dateFmt(hasta) : null,
    );
    if (isMounted) refresh(() {});
    unawaited(fetchFilteredTotals());
  }

  Future<void> fetchFilteredTotals() async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    String pad2(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
    // Igual que la web: solo condiciona por fecha si el usuario eligió fechas
    String filtro = 'm.usuario="$usuario"';
    if (filterFrom != null && filterTo != null) {
      filtro += ' and m.fecha between "${fmt(filterFrom!)}" and "${fmt(filterTo!)}"';
    } else if (filterFrom != null) {
      filtro += ' and m.fecha >= "${fmt(filterFrom!)}"';
    } else if (filterTo != null) {
      filtro += ' and m.fecha <= "${fmt(filterTo!)}"';
    }
    if (movementTypeFilter.isNotEmpty) {
      // tipo '1' (loan transfers) is also Ingreso, same as '3'
      filtro += movementTypeFilter == '3'
          ? ' and m.tipo_movimiento in (1,3)'
          : ' and m.tipo_movimiento=$movementTypeFilter';
    }
    if (accountFilter.isNotEmpty) {
      final cuenta = accounts.firstWhere(
          (c) => (c['nombre'] ?? '') == accountFilter,
          orElse: () => {});
      final cod = (cuenta['codigo'] ?? '').toString();
      if (cod.isNotEmpty) filtro += ' and m.codigo_cuenta="$cod"';
    }
    try {
      final r = await repository
          .post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_gastos_ingresos',
        'filtro': filtro,
        'agrupacion': '',
      })
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          double g = 0.0, ing = 0.0;
          for (final k in row.keys) {
            final kl = k.toString().toLowerCase();
            if (kl.contains('gasto')) g = numberValue(row[k]);
            if (kl.contains('ingreso')) ing = numberValue(row[k]);
          }
          if (isMounted) {
            refresh(() {
              filteredExpenses = g;
              filteredIncome = ing;
              filteredTotalsLoaded = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotalesFiltrados: $e');
    }
  }

  Future<void> _fetchTotalesResumen(String usuario) async {
    // Sin rango de fechas: totales históricos, igual que la web.
    // Para acotar por período están los filtros de fecha de Movimientos.
    final filtro = 'm.usuario="$usuario"';
    // Hasta 2 intentos: la BD del hosting a veces bota la conexión justo
    // tras el login (sin caché local todavía) y este endpoint es el único
    // que el dashboard espera para retirar el skeleton.
    for (var intento = 0; intento < 2; intento++) {
      try {
        final r = await repository.post('/ajax/listado_json_campos.php', {
          'codigo_consulta': 'json_total_gastos_ingresos',
          'filtro': filtro,
          'agrupacion': '',
          // La consulta guardada también usa <<usuario>> (c.usuario, el
          // dueño de la cuenta) además de <<filtro>>. Sin este campo, el
          // backend cae a $_SESSION['codigo_usuario'] — una sesión PHP
          // aparte del token de la app, que expira sola en el servidor.
          // Si eso pasaba justo cuando esta petición corría (típicamente
          // tras estar un rato en segundo plano), <<usuario>> quedaba en 0
          // y la consulta no encontraba nada: total_gastos/ingresos = 0
          // aunque sí hubiera movimientos.
          'usuario': usuario,
        }).timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          final d = decodeJsonMap(r.body);
          if (d['resultado'] == 1 &&
              d['datos'] is List &&
              (d['datos'] as List).isNotEmpty) {
            final row =
                Map<String, dynamic>.from((d['datos'] as List).first as Map);
            double g = 0.0, ing = 0.0;
            for (final k in row.keys) {
              final kl = k.toString().toLowerCase();
              if (kl.contains('gasto')) g = numberValue(row[k]);
              if (kl.contains('ingreso')) ing = numberValue(row[k]);
            }
            if (isMounted) {
              refresh(() {
                serverExpenses = g;
                serverIncome = ing;
                serverTotalsLoaded = true;
                serverTotalsIsFallback = false;
                invalidateComputedCache();
              });
            }
            unawaited(repository.saveLocalData('totales', [
              {'gastos': g, 'ingresos': ing},
            ]));
            return;
          }
        }
      } catch (e) {
        debugPrint('[SAF] fetchTotales intento $intento: $e');
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  Future<void> _fetchTotalesCreditos({
    String asesorCodigo = '',
    String estado = '',
  }) async {
    final condiciones = <String>[];
    final asesorNum = int.tryParse(asesorCodigo);
    final estadoNum = int.tryParse(estado);
    if (asesorNum != null && asesorNum > 0) {
      condiciones.add('d.codigo_asesor=$asesorNum');
    }
    if (estadoNum != null && estadoNum > 0) {
      condiciones.add('c.codigo_estado=$estadoNum');
    }

    try {
      final r = await repository
          .post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_creditos_valores',
        'filtro': condiciones.join(' AND '),
        'agrupacion': '',
      })
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          // Los valores vienen formateados: "$388,207,190" o "$388.207.190"
          double parseFmt(dynamic v) {
            final s = v.toString().replaceAll(RegExp(r'[^\d]'), '');
            return double.tryParse(s) ?? 0.0;
          }

          final pagado = parseFmt(row['pagado'] ?? row['total_pagado'] ?? 0);
          final pendiente =
              parseFmt(row['pendiente'] ?? row['total_pendiente'] ?? 0);
          if (isMounted) {
            refresh(() {
              creditsPaidTotal = pagado;
              creditsPendingTotal = pendiente;
              creditsDataLoaded = true;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotalesCreditos: $e');
    }
    // Fallback: marcar como cargado aunque no haya datos, para no quedar en skeleton
    if (isMounted) refresh(() => creditsDataLoaded = true);
  }

  Future<void> fetchSavers([String? anio, String? asesor]) async {
    try {
      final previousSavers = List<Map<String, dynamic>>.from(savers);
      final now =
          DateTime.now().toUtc().subtract(const Duration(hours: 5));
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final r = await repository
          .cachedPost('/ajax/listado_ahorros.php', {
        'anio_ahorro': anio ?? savingsYearFilter,
        // La pantalla filtra por sigla localmente. Para no reemplazar la
        // colección completa con un solo asesor, las recargas normales traen
        // todos los registros del año.
        'filtro_asesor': isAsesor
            ? codigoOrigen
            : (asesor == null ? '0' : creditAdvisorCode(asesor)),
      })
          .timeout(const Duration(seconds: 10));
      final loadedSavers = <Map<String, dynamic>>[];
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['ahorradores'];
        if (list is List) {
          loadedSavers.addAll(list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList());
        }
      }

      // listado_ahorros.php solo incluye personas con un ahorro asociado.
      // Fusionamos el catálogo para mostrar también los recién registrados.
      final catalogResponse = await repository
          .cachedPost('/ajax/listado_select.php', {
        'tabla': 'tbl_ahorradores',
        'valor': 'codigo',
        'etiqueta':
            'concat(nombres,CHAR(124),apellidos,CHAR(124),codigo_asesor)',
        'filtro': '1',
        'campos_orden': 'nombres,apellidos',
      })
          .timeout(const Duration(seconds: 10));
      if (catalogResponse.statusCode == 200) {
        final rawCatalog = jsonDecode(catalogResponse.body);
        if (rawCatalog is List) {
          for (final raw in rawCatalog.whereType<Map>()) {
            final item = Map<String, dynamic>.from(raw);
            final codigo = (item['codigo'] ??
                    (item.values.isNotEmpty ? item.values.first : ''))
                .toString()
                .trim();
            final encoded =
                (item.values.isNotEmpty ? item.values.last : '').toString();
            final parts = encoded.split('|');
            final nombre = parts.take(2).join(' ').trim().toUpperCase();
            final codigoAsesor =
                parts.length > 2 ? parts[2].trim() : '';
            Map<String, dynamic>? previous;
            for (final saver in previousSavers) {
              if ((saver['codigo_ahorrador'] ?? '').toString() == codigo ||
                  (saver['ahorrador'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase() ==
                      nombre) {
                previous = saver;
                break;
              }
            }
            final loadedIndex = loadedSavers.indexWhere((saver) =>
                (saver['codigo_ahorrador'] ?? '').toString() == codigo ||
                (saver['ahorrador'] ?? '')
                        .toString()
                        .trim()
                        .toUpperCase() ==
                    nombre);
            if (loadedIndex >= 0) {
              loadedSavers[loadedIndex]['codigo_ahorrador'] = codigo;
              loadedSavers[loadedIndex]['codigo_asesor'] = codigoAsesor;
              if ((loadedSavers[loadedIndex]['asesor'] ?? '')
                  .toString()
                  .trim()
                  .isEmpty) {
                loadedSavers[loadedIndex]['asesor'] =
                    creditAdvisorInitials(codigoAsesor);
              }
            } else if (nombre.isNotEmpty) {
              final previousDate = (previous?['Fecha_ingreso'] ??
                      previous?['fecha_ingreso'] ??
                      '')
                  .toString();
              final parsedPreviousDate = DateTime.tryParse(previousDate);
              final validPreviousDate = parsedPreviousDate != null &&
                  !DateTime(
                    parsedPreviousDate.year,
                    parsedPreviousDate.month,
                    parsedPreviousDate.day,
                  ).isAfter(DateTime(now.year, now.month, now.day));
              loadedSavers.add({
                'codigo_ahorrador': codigo,
                'ahorrador': nombre,
                'asesor': creditAdvisorInitials(codigoAsesor),
                'total_ahorrado': 0,
                'Valor_pactado': 0,
                'neto_pagar': 0,
                'Fecha_ingreso': validPreviousDate ? previousDate : today,
                'ahorros': <dynamic>[],
                'sin_ahorro': true,
              });
            }
          }
        }
      }

      savers = loadedSavers;
      cachedFilteredSavers = null;
      unawaited(repository.saveLocalData('ahorradores', savers));
    } catch (e) {
      debugPrint('[SAF] ahorradores: $e');
    }
  }

  Future<void> reloadSavers() async {
    refresh(() => loadingData = true);
    await fetchSavers();
    refresh(() => loadingData = false);
  }

  Future<void> fetchCredits(String filtro, {bool soloListado = false}) async {
    final estadoSeleccionado = creditStatusFilter;
    // "Atrasados" no es un codigo_estado del servidor: es un crédito Activo
    // (estado=1) cuya proxima_fecha ya venció. Se pide la lista completa de
    // activos y se filtra/pagina acá mismo — si se paginara primero en el
    // servidor, cada página traería una mezcla de al día/atrasados y el
    // conteo total mostrado no correspondería a los atrasados reales.
    final isAtrasadosFilter = estadoSeleccionado == 'atrasado';
    // No-admin: siempre filtra por su propio codigo_origen (ID de asesor)
    final asesorCodigo = isAdmin
        ? creditAdvisorCode(creditAdvisorFilter)
        : codigoOrigen;

    // Lista de créditos — endpoint dedicado con JSON + paginación
    double? atrasadosPagado;
    double? atrasadosPendiente;
    try {
      final r = await repository
          .post('/ajax/get_creditos_lista.php', {
        'estado': isAtrasadosFilter ? '1' : estadoSeleccionado,
        // La web conserva la sigla (JP, VB, etc.), mientras este endpoint
        // dedicado filtra por codigo_asesor numérico.
        'asesor': asesorCodigo,
        'pagina': isAtrasadosFilter ? '1' : creditsPage.toString(),
        'por_pagina': isAtrasadosFilter ? '1000' : creditsPageSize.toString(),
        if (creditsBuscar.isNotEmpty) 'buscar': creditsBuscar,
      })
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['datos'] is List) {
          var lista = (decoded['datos'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (isAtrasadosFilter) {
            lista = lista.where(isCreditoVencido).toList();
            creditsTotal = lista.length;
            // "Total Pagado/Pendiente" se calculan aquí sobre el listado ya
            // filtrado (no solo la página visible) — el endpoint oficial de
            // totales no entiende "atrasado" (ver más abajo) y devolvería
            // las cifras de todos los créditos, no solo los vencidos.
            atrasadosPagado = lista.fold<double>(
                0, (sum, c) => sum + numberValue(c['total_pagado'] ?? 0));
            atrasadosPendiente = lista.fold<double>(
                0, (sum, c) => sum + numberValue(c['saldo_pendiente'] ?? 0));
            final start = (creditsPage - 1) * creditsPageSize;
            credits = start < lista.length
                ? lista.sublist(
                    start, (start + creditsPageSize).clamp(0, lista.length))
                : <Map<String, dynamic>>[];
          } else {
            creditsTotal =
                int.tryParse(decoded['total']?.toString() ?? '0') ?? 0;
            credits = lista;
          }
          unawaited(repository.saveLocalData('creditos_lista', credits));
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos lista: $e');
    }

    if (isAtrasadosFilter) {
      // El endpoint oficial de totales (abajo) filtra por codigo_estado
      // numérico — "atrasado" no es un estado del servidor, así que ese
      // filtro se ignoraría y traería el total de TODOS los créditos.
      if (isMounted) {
        refresh(() {
          creditsPaidTotal = atrasadosPagado ?? 0;
          creditsPendingTotal = atrasadosPendiente ?? 0;
          creditsDataLoaded = true;
        });
      }
    } else if (!soloListado) {
      // La cabecera de la web usa json_total_creditos_valores. El cálculo
      // incluido en get_creditos_lista.php puede diferir por ajustes de
      // cuotas, por lo que nunca debe sobrescribir estos totales oficiales.
      await _fetchTotalesCreditos(
        asesorCodigo: asesorCodigo,
        estado: estadoSeleccionado,
      );
    }

    // Al cambiar de página los totales y la estadística por fuente no
    // cambian (dependen del filtro, no de la página) — pedirlos de nuevo en
    // cada clic de paginación solo suma dos round-trips de red que retrasan
    // la actualización del listado sin aportar nada nuevo.
    if (soloListado) return;

    // Estadística por fuente — endpoint dedicado con campos fijos
    try {
      final r = await repository
          .cachedPost('/ajax/get_estadistica_fuente.php', {},
              ttl: const Duration(minutes: 10))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && decoded.isNotEmpty) {
          creditStatistics = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          unawaited(repository.saveLocalData('creditos', creditStatistics));
          return;
        }
      }
    } catch (e) {
      debugPrint('[SAF] estadistica fuente: $e');
    }

    // Fallback 1: calcular desde credits ya cargada
    final local = _buildEstadisticaFromLocal();
    if (local.isNotEmpty) {
      creditStatistics = local;
      return;
    }

    // Fallback 2: query original json_total_creditos_valores (campos variables pero nunca vacío)
    try {
      final r = await repository
          .cachedPost('/ajax/listado_json_campos.php',
              {'codigo_consulta': 'json_total_creditos_valores', 'filtro': filtro})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['datos'];
        if (list is List && list.isNotEmpty) {
          final raw = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          creditStatistics = raw;
          unawaited(repository.saveLocalData('creditos', creditStatistics));
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos stat fallback: $e');
    }
  }

  /// Llama get_estadistica_fuente.php con los filtros activos y actualiza creditStatistics.
  Future<void> applyStatisticsFilters() async {
    if (!isMounted) return;
    refresh(() => sourceStatisticsLoading = true);
    String fmt(DateTime? d) => d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      repository.invalidateCache('/ajax/get_estadistica_fuente.php');
      final r = await repository.post('/ajax/get_estadistica_fuente.php', {
        'estado': sourceStatisticsStatus,
        'fecha_desde': fmt(sourceStatisticsFrom),
        'fecha_hasta': fmt(sourceStatisticsTo),
        'fuente': sourceStatisticsAccount,
      }).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && isMounted) {
          refresh(() {
            creditStatistics = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            sourceStatisticsLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[SAF] aplicarFiltros: $e');
    }
    if (isMounted) refresh(() => sourceStatisticsLoading = false);
  }

  /// Agrega credits por fuente para obtener salidas. Entradas = 0 (sin data de pagos).
  List<Map<String, dynamic>> _buildEstadisticaFromLocal() {
    if (credits.isEmpty) return [];
    const fuenteKeys = [
      'fuente',
      'nombre_fuente',
      'cuenta',
      'nombre_cuenta',
      'origen',
      'nombre_origen',
      'nombre',
      'fuente_nombre',
    ];
    const valorKeys = [
      'monto',
      'valor_prestamo',
      'valor_credito',
      'valor',
      'prestado',
      'total'
    ];
    final first = credits.first;
    final allKeys = first.keys.toList();

    final fk =
        fuenteKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    // Intenta campo de valor conocido; si no, usa el primero con valor numérico > 0
    var vk = valorKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    if (vk.isEmpty) {
      vk = allKeys.firstWhere((k) => numberValue(first[k]) > 0,
          orElse: () => '');
    }
    if (vk.isEmpty) return [];

    final mapa = <String, double>{};
    for (final c in credits) {
      final fuente = fk.isNotEmpty
          ? (c[fk] ?? 'Sin fuente').toString().trim()
          : 'Sin fuente';
      mapa[fuente] = (mapa[fuente] ?? 0) + numberValue(c[vk]);
    }
    final result = mapa.entries
        .map((e) =>
            {'fuente': e.key, 'total_salidas': e.value, 'total_entradas': 0.0})
        .toList();
    result.sort((a, b) =>
        (b['total_salidas'] as double).compareTo(a['total_salidas'] as double));
    return result;
  }

  // Carga la estadística de la sub-pestaña activa.
  Future<void> fetchStatistics() async {
    final codigo = statisticsTabs[statisticsSubTab].$2;
    refresh(() {
      statisticsLoading = true;
      statisticsData = [];
    });
    try {
      final r = await repository
          .cachedPost('/ajax/listado_json_campos.php',
              {'codigo_consulta': codigo, 'filtro': '', 'agrupacion': ''},
              ttl: const Duration(minutes: 10))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['datos'] ?? d['resultado_datos'] ?? d['data'];
        if (list is List) {
          statisticsData = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] estadistica: $e');
    } finally {
      if (isMounted) refresh(() => statisticsLoading = false);
    }
  }

  // Construye debtors desde datos ya en memoria (sin red).
  void tryBuildDebtorsFromLocal() {
    if (debtors.isNotEmpty) return;

    // Campos de nombre conocidos, en orden de preferencia
    const nameKeys = [
      'cliente',
      'deudor',
      'etiqueta',
      'nombre_deudor',
      'deudor_nombre',
      'nombre_completo',
      'fullname',
      'nombre',
      'nombres',
    ];
    // Valores que claramente NO son nombres de persona
    final notName = RegExp(
        r'^(activ|pagad|pendient|inactiv|mensual|quincenal|semanal|diario|fijo|variable|\d)',
        caseSensitive: false);

    String extractName(Map<String, dynamic> c) {
      // 1. Campos conocidos
      for (final k in nameKeys) {
        final v = c[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      // 2. Nombres + apellidos concatenados
      final n =
          '${c['nombres'] ?? c['nombre'] ?? ''} ${c['apellidos'] ?? c['apellido'] ?? ''}'
              .trim();
      if (n.isNotEmpty) return n;
      // 3. Escanear todos los strings: buscar el más largo que parezca nombre
      String best = '';
      for (final v in c.values) {
        if (v is! String) continue;
        final s = v.trim();
        if (s.length > best.length &&
            s.contains(' ') &&
            s.length > 5 &&
            !notName.hasMatch(s) &&
            !s.contains('<') &&
            !s.contains('/')) {
          best = s;
        }
      }
      return best;
    }

    for (final source in [credits, savers]) {
      if (source.isEmpty) continue;
      final seen = <String>{};
      final lista = <Map<String, dynamic>>[];
      for (final c in source) {
        final label = extractName(c);
        final id = (c['valor'] ??
                c['codigo_deudor'] ??
                c['id_deudor'] ??
                c['codigo'] ??
                c['id'] ??
                label)
            .toString();
        if (label.isNotEmpty && seen.add(id)) {
          lista.add({'valor': id, 'etiqueta': label});
        }
      }
      if (lista.isNotEmpty) {
        lista.sort((a, b) =>
            a['etiqueta'].toString().compareTo(b['etiqueta'].toString()));
        debtors = lista;
        return;
      }
    }
  }

  Future<void> fetchDebtors() async {
    try {
      final r = await repository
          .cachedPost('/ajax/get_deudores.php', {},
              ttl: const Duration(minutes: 10))
          .timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        List<dynamic>? list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          for (final k in [
            'datos',
            'data',
            'resultado',
            'resultado_datos',
            'items',
            'deudores'
          ]) {
            if (decoded[k] is List) {
              list = decoded[k] as List;
              break;
            }
          }
        }
        if (list != null && list.isNotEmpty) {
          debtors = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          return;
        }
      }
      debugPrint(
          '[SAF] get_deudores.php status=${r.statusCode} body=${r.body.substring(0, r.body.length.clamp(0, 200))}');
    } catch (e) {
      debugPrint('[SAF] deudores fetch: $e');
    }

    // Fallback: extraer desde creditosLista (campo real: 'cliente')
    if (debtors.isEmpty && credits.isNotEmpty) {
      final seen = <String>{};
      final lista = <Map<String, dynamic>>[];
      for (final c in credits) {
        final label = [
              c['cliente'],
              c['nombre_deudor'],
              c['deudor_nombre'],
              c['nombre_completo'],
              c['deudor'],
              c['nombre'],
              c['nombres']
            ]
                .firstWhere((v) => v != null && v.toString().trim().isNotEmpty,
                    orElse: () => null)
                ?.toString()
                .trim() ??
            '';
        final id = (c['codigo_deudor'] ??
                c['id_deudor'] ??
                c['codigo'] ??
                c['id'] ??
                label)
            .toString();
        if (label.isNotEmpty && seen.add(id)) {
          lista.add({'valor': id, 'etiqueta': label});
        }
      }
      if (lista.isNotEmpty) {
        lista.sort((a, b) =>
            a['etiqueta'].toString().compareTo(b['etiqueta'].toString()));
        debtors = lista;
      }
    }
  }

  Future<void> fetchRates() async {
    try {
      final r = await repository
          .cachedPost('/ajax/listado_json_campos.php',
              {'codigo_consulta': 'json_tasas', 'filtro': '', 'agrupacion': ''},
              ttl: const Duration(hours: 1))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['datos'] ?? d['data'] ?? d['tasas'];
        if (list is List) {
          rates = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] tasas: $e');
    }
  }

  Future<void> fetchSources() async {
    try {
      final r = await repository
          .cachedPost('/ajax/listado_json_campos.php',
              {'codigo_consulta': 'json_fuentes', 'filtro': '', 'agrupacion': ''},
              ttl: const Duration(hours: 1))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        List? list;
        try {
          final raw = jsonDecode(r.body);
          if (raw is List) {
            list = raw;
          } else if (raw is Map) {
            final d = Map<String, dynamic>.from(raw);
            list = d['datos'] ?? d['data'] ?? d['fuentes'] ??
                d.values.whereType<List>().firstOrNull;
          }
        } catch (_) {}
        if (list != null && list.isNotEmpty) {
          sources = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] fuentes: $e');
    }
  }

  Future<void> fetchPending() async {
    if (pendingLoading) return;
    if (isMounted) refresh(() => pendingLoading = true);
    Map<String, dynamic>? payload;
    Object? lastError;
    try {
      for (var intento = 1; intento <= 3; intento++) {
        try {
          final r = await repository.post('/ajax/get_pendientes_lista.php', {
            // Pendientes tiene su propio listado. No debe heredar los
            // filtros invisibles de la pestaña Aprobados.
            'asesor': '',
            'estado': '',
            'pagina': pendingPage.toString(),
            'por_pagina': creditsPageSize.toString(),
          }).timeout(const Duration(seconds: 12));
          if (r.statusCode != 200) {
            throw Exception('Servidor respondió ${r.statusCode}');
          }
          final decoded = jsonDecode(r.body);
          if (decoded is! Map || decoded['datos'] is! List) {
            throw const FormatException('Respuesta de pendientes no válida');
          }
          payload = Map<String, dynamic>.from(decoded);
          break;
        } catch (e) {
          lastError = e;
          if (intento < 3) {
            await Future<void>.delayed(Duration(milliseconds: 350 * intento));
          }
        }
      }
      if (payload == null) throw lastError ?? Exception('No hubo respuesta');

      final datos = payload['datos'] as List;
      if (isMounted) {
        refresh(() {
          pendingTotal =
              int.tryParse(payload!['total']?.toString() ?? '0') ?? 0;
          pendingRequests = datos
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          pendingLoaded = true;
          pendingError = null;
        });
        unawaited(repository.saveLocalData('pendientes', pendingRequests));
      }
    } catch (e) {
      debugPrint('[SAF] pendientes lista: $e');
      if (isMounted) {
        refresh(() {
          pendingError =
              'No fue posible cargar las solicitudes. Intenta nuevamente.';
        });
      }
    } finally {
      if (isMounted) refresh(() => pendingLoading = false);
    }
  }

  /// Lee la preferencia de tema del servidor (compartida con SAF-WEB) y la
  /// aplica. Silencioso: si no hay red o el endpoint no existe, se conserva
  /// la copia local (SharedPreferences).
  Future<void> syncThemeFromServer() async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    try {
      final r = await repository.post('/ajax/preferencia_tema.php', {
        'accion': 'get',
        'usuario': usuario,
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final d = decodeJsonMap(r.body);
      if (d['success'] != true) return;
      final dark = d['tema_oscuro'] == 1 || d['tema_oscuro'] == '1';
      if (dark != isDarkTheme) {
        await setThemeDark(dark);
        if (isMounted) refresh(() {});
      }
    } catch (e) {
      debugPrint('[SAF] preferencia tema: $e');
    }
  }

  /// Guarda la preferencia en el servidor para que la web la cargue igual.
  Future<void> saveThemeToServer(bool dark) async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    try {
      await repository.post('/ajax/preferencia_tema.php', {
        'accion': 'set',
        'usuario': usuario,
        'tema_oscuro': dark ? '1' : '0',
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[SAF] guardar tema: $e');
    }
  }

  Future<void> fetchAdvisors() async {
    try {
      final r = await repository
          .cachedPost('/ajax/get_asesores.php', {},
              ttl: const Duration(hours: 1))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && decoded.isNotEmpty) {
          advisors = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          // Invalida el cache del filtro de ahorradores para que el fallback
          // por sigla pueda aplicarse ahora que advisors ya está disponible
          if (isAsesor) cachedFilteredSavers = null;
        }
      }
    } catch (e) {
      debugPrint('[SAF] asesores: $e');
    }
  }
}
